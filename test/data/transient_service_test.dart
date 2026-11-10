import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cruise_assist/data/api.dart';
import 'package:cruise_assist/data/transient_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers.dart';

/// Minimal protobuf encoder used to build a GTFS-realtime FeedMessage
/// exactly as api.data.gov.my serves it.
class Pb {
  final BytesBuilder _b = BytesBuilder();

  void _varint(int value) {
    var v = value;
    while (true) {
      final byte = v & 0x7f;
      v >>= 7;
      if (v == 0) {
        _b.addByte(byte);
        break;
      }
      _b.addByte(byte | 0x80);
    }
  }

  void _tag(int field, int wire) => _varint((field << 3) | wire);

  Pb varint(int field, int value) {
    _tag(field, 0);
    _varint(value);
    return this;
  }

  Pb bytes(int field, List<int> value) {
    _tag(field, 2);
    _varint(value.length);
    _b.add(value);
    return this;
  }

  Pb str(int field, String value) => bytes(field, utf8.encode(value));

  Pb float32(int field, double value) {
    _tag(field, 5);
    final d = ByteData(4)..setFloat32(0, value, Endian.little);
    _b.add(d.buffer.asUint8List());
    return this;
  }

  Uint8List build() => _b.toBytes();
}

/// FeedMessage{ header, entity{ id, vehicle{ trip, position, vehicle } } }
Uint8List buildFeed({
  required String entityId,
  required String tripId,
  required String routeId,
  required double lat,
  required double lng,
  required String vehicleId,
}) {
  final trip = (Pb()..str(1, tripId)..str(5, routeId)).build();
  final position = (Pb()..float32(1, lat)..float32(2, lng)).build();
  final vehicleDesc = (Pb()..str(1, vehicleId)).build();
  final vehicle =
      (Pb()..bytes(1, trip)..bytes(2, position)..bytes(3, vehicleDesc)).build();
  final entity = (Pb()..str(1, entityId)..bytes(4, vehicle)).build();
  final header = (Pb()..str(1, '2.0')).build();
  return (Pb()..bytes(1, header)..bytes(2, entity)).build();
}

void main() {
  test('decodes the live data.gov.my feed bytes', () async {
    // Captured from https://api.data.gov.my/gtfs-realtime/vehicle-position/
    // prasarana?category=rapid-bus-kl
    final bytes = File('test/data/fixtures/gtfs_vehicle_position_sample.pb')
        .readAsBytesSync();
    final client = ApiClient.fake((r) async => http.Response.bytes(bytes, 200));
    final s = TransitService(client: client);
    final r = await s.vehicles('prasarana');
    expect(r.ok, isTrue);
    expect(r.value, isNotEmpty);
    final v = r.value!.first;
    expect(v.route, 'U4500');
    expect(v.id, 'WB3225B');
    expect(v.lat, closeTo(3.0742, 0.001));
    expect(v.lng, closeTo(101.7612, 0.001));
  });

  test('parses a GTFS protobuf feed', () async {
    final body = buildFeed(
      entityId: '0',
      tripId: 'weekday_U4500_U4500001_10',
      routeId: 'U4500',
      lat: 3.139,
      lng: 101.6869,
      vehicleId: 'WB3225B',
    );
    final client = ApiClient.fake((r) async => http.Response.bytes(body, 200));
    final s = TransitService(client: client);
    final r = await s.vehicles('prasarana');
    expect(r.ok, isTrue);
    expect(r.value!.length, 1);
    expect(r.value!.first.route, 'U4500');
    expect(r.value!.first.id, 'WB3225B');
    expect(r.value!.first.lat, closeTo(3.139, 1e-5));
    expect(r.value!.first.lng, closeTo(101.6869, 1e-5));
  });

  test('agency query includes the category for prasarana', () async {
    Uri? seen;
    final client = ApiClient.fake((r) async {
      seen = r.url;
      return http.Response.bytes(buildFeed(
        entityId: '0',
        tripId: 't',
        routeId: 'R1',
        lat: 3.0,
        lng: 101.0,
        vehicleId: 'v',
      ), 200);
    });
    final s = TransitService(client: client);
    await s.vehicles('prasarana');
    expect(seen!.path, '/gtfs-realtime/vehicle-position/prasarana');
    expect(seen!.queryParameters['category'], 'rapid-bus-kl');
  });

  test('ktmb agency path has no category parameter', () async {
    Uri? seen;
    final client = ApiClient.fake((r) async {
      seen = r.url;
      return http.Response.bytes(const [], 200);
    });
    final s = TransitService(client: client);
    await s.vehicles('ktmb');
    expect(seen!.path, '/gtfs-realtime/vehicle-position/ktmb');
    expect(seen!.queryParameters.containsKey('category'), isFalse);
  });

  test('HTTP 500 returns failed', () async {
    final s = TransitService(client: fakeClient('err', status: 500));
    final r = await s.vehicles('ktmb');
    expect(r.ok, isFalse);
    expect(r.message, contains('500'));
  });

  test('malformed protobuf returns failed', () async {
    final client = ApiClient.fake(
        (r) async => http.Response.bytes([0xff, 0xff, 0xff, 0xff, 0x0f], 200));
    final s = TransitService(client: client);
    final r = await s.vehicles('ktmb');
    expect(r.ok, isFalse);
  });

  test('empty body yields an empty list', () async {
    final client = ApiClient.fake((r) async => http.Response.bytes(const [], 200));
    final s = TransitService(client: client);
    final r = await s.vehicles('ktmb');
    expect(r.ok, isTrue);
    expect(r.value, isEmpty);
  });

  test('JSON entity shape is tolerated', () async {
    const payload = '''
    {"entity": [{"vehicle": {"id": "bus-1",
      "trip": {"route_id": "R1", "trip_id": "T1"},
      "position": {"latitude": 3.14, "longitude": 101.69}}}]}
    ''';
    final s = TransitService(client: fakeClient(payload));
    final r = await s.vehicles('ktmb');
    expect(r.ok, isTrue);
    expect(r.value!.single.id, 'bus-1');
    expect(r.value!.single.route, 'R1');
    expect(r.value!.single.lat, 3.14);
  });

  test('empty JSON entity list yields an empty list', () async {
    final s = TransitService(client: fakeClient('{"entity": []}'));
    final r = await s.vehicles('ktmb');
    expect(r.ok, isTrue);
    expect(r.value, isEmpty);
  });

  test('lat/lng filters vehicles but falls back to all when none match',
      () async {
    final body = buildFeed(
      entityId: '0',
      tripId: 't',
      routeId: 'R1',
      lat: 3.139,
      lng: 101.6869,
      vehicleId: 'v',
    );
    final client = ApiClient.fake((r) async => http.Response.bytes(body, 200));
    final s = TransitService(client: client);
    final near = await s.vehicles('ktmb', lat: 3.14, lng: 101.69);
    expect(near.value!.length, 1);
    final far = await s.vehicles('ktmb', lat: 1.5, lng: 110.0);
    expect(far.value!.length, 1);
  });
}
