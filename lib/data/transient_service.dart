import 'dart:convert';
import 'dart:typed_data';

import '../models/data.dart';
import '../models/result.dart';
import 'api.dart';
import 'cache.dart';
import 'support.dart';

/// GTFS-realtime vehicle positions from data.gov.my.
///
/// The feed is a binary protobuf `FeedMessage` (not JSON), so this service
/// carries a minimal protobuf reader for the fields we need:
/// FeedMessage.entity(2) -> FeedEntity.vehicle(4) -> VehiclePosition
///   trip(1).route_id(5) / trip_id(1), position(2).latitude(1)/longitude(2),
///   vehicle(3).id(1), timestamp(7).
class TransitService {
  final ApiClient _api;
  final DiskCache _cache;

  TransitService({ApiClient? client, DiskCache? cache})
      : _api = client ?? ApiClient(),
        _cache = cache ?? DiskCache();

  /// Known agency paths. `prasarana` needs a category; the value after the
  /// colon overrides it (e.g. `prasarana:rapid-bus-penang`).
  static const Map<String, String> agencies = {
    'ktmb': 'ktmb',
    'prasarana': 'prasarana?category=rapid-bus-kl',
    'rapid-bus-kl': 'prasarana?category=rapid-bus-kl',
    'rapid-bus-penang': 'prasarana?category=rapid-bus-penang',
    'rapid-bus-mrtfeeder': 'prasarana?category=rapid-bus-mrtfeeder',
  };

  Future<Fetch<List<TransitVehicle>>> vehicles(String agency,
      {double? lat, double? lng}) {
    final key = 'transit.$agency';
    return cachedRead<List<TransitVehicle>>(
      cache: _cache,
      key: key,
      ttl: const Duration(seconds: 45),
      encode: (v) => {'vehicles': v.map((e) => e.toJson()).toList()},
      decode: (j) => arr(j['vehicles'])
          .map((e) => TransitVehicle.fromJson(obj(e)))
          .toList(growable: false),
      remote: () async {
        final path = agencies[agency.toLowerCase()] ?? agency;
        final parts = path.split('?');
        final query = parts.length > 1
            ? Uri.splitQueryString(parts[1])
            : const <String, String>{};
        final uri = Uri.https('api.data.gov.my',
            '/gtfs-realtime/vehicle-position/${parts[0]}', query);
        final res = await _api.get(uri, headers: {'Accept': '*/*'});
        if (res.statusCode != 200) {
          throw ApiException('Transit $agency: HTTP ${res.statusCode}');
        }
        final body = res.bodyBytes;
        if (body.isEmpty) return <TransitVehicle>[];
        // A JSON body means the feed changed format; parse defensively.
        final firstNonSpace = body.firstWhere((b) => b != 0x20 && b != 0x0a && b != 0x0d && b != 0x09,
            orElse: () => 0);
        if (firstNonSpace == 0x7b || firstNonSpace == 0x5b) {
          return _parseJsonFeed(body);
        }
        final all = _parseFeed(body);
        if (all.isEmpty && body.length > 8) {
          throw ApiException('Transit: malformed GTFS feed');
        }
        if (lat == null || lng == null) return all;
        final nearby = all
            .where((v) => haversineM(lat, lng, v.lat, v.lng) <= 60000)
            .toList(growable: false);
        return nearby.isEmpty ? all : nearby;
      },
    );
  }

  List<TransitVehicle> _parseJsonFeed(List<int> body) {
    final decoded = jsonDecode(utf8.decode(body));
    final list = decoded is List
        ? decoded
        : (decoded is Map && decoded['entity'] is List)
            ? decoded['entity'] as List
            : const <dynamic>[];
    final out = <TransitVehicle>[];
    for (final e in list) {
      final j = obj(e);
      final v = obj(j['vehicle']);
      final pos = obj(v['position']);
      final lat = dbl(pos['latitude']);
      final lng = dbl(pos['longitude']);
      if (lat == null || lng == null) continue;
      out.add(TransitVehicle(
        id: text(v['id']) ?? text(obj(v['trip'])['trip_id']) ?? 'unknown',
        route: text(obj(v['trip'])['route_id']) ?? '',
        lat: lat,
        lng: lng,
      ));
    }
    return out;
  }

  /// Minimal protobuf wire-format reader for GTFS-realtime.
  List<TransitVehicle> _parseFeed(List<int> body) {
    final bytes = List<int>.from(body);
    final out = <TransitVehicle>[];
    try {
      for (final field in _fields(bytes)) {
        if (field.number == 2 && field.wireType == 2) {
          final entity = _fields(field.bytes);
          for (final ef in entity) {
            if (ef.number != 4 || ef.wireType != 2) continue;
            final vehicle = _fields(ef.bytes);
            double? lat;
            double? lng;
            String route = '';
            String tripId = '';
            String id = '';
            for (final vf in vehicle) {
              if (vf.wireType != 2) continue;
              if (vf.number == 1) {
                // TripDescriptor
                final trip = _fields(vf.bytes);
                for (final tf in trip) {
                  if (tf.wireType != 2) continue;
                  if (tf.number == 5) {
                    route = utf8.decode(tf.bytes);
                  } else if (tf.number == 1) {
                    tripId = utf8.decode(tf.bytes);
                  }
                }
              } else if (vf.number == 2) {
                // Position
                final pos = _fields(vf.bytes);
                for (final pf in pos) {
                  if (pf.number == 1 && pf.wireType == 5) {
                    lat = _float32(pf.bytes);
                  } else if (pf.number == 2 && pf.wireType == 5) {
                    lng = _float32(pf.bytes);
                  }
                }
              } else if (vf.number == 3 || vf.number == 8) {
                // VehicleDescriptor (field 3 in some feeds, 8 in the
                // data.gov.my feed).
                final vd = _fields(vf.bytes);
                for (final df in vd) {
                  if (df.number == 1 && df.wireType == 2) {
                    id = utf8.decode(df.bytes);
                  }
                }
              }
            }
            if (lat == null || lng == null) continue;
            out.add(TransitVehicle(
              id: id.isEmpty ? tripId : id,
              route: route,
              lat: lat,
              lng: lng,
            ));
          }
        }
      }
    } catch (e) {
      if (out.isEmpty) throw ApiException('Transit: malformed GTFS feed ($e)');
    }
    return out;
  }

  List<_PbField> _fields(List<int> data) {
    final out = <_PbField>[];
    var i = 0;
    while (i < data.length) {
      final tag = _varint(data, i);
      if (tag == null) break;
      i = tag.$2;
      final number = tag.$1 >> 3;
      final wireType = tag.$1 & 7;
      switch (wireType) {
        case 0:
          final v = _varint(data, i);
          if (v == null) return out;
          i = v.$2;
          out.add(_PbField(number, wireType, const <int>[], v.$1));
        case 1:
          if (i + 8 > data.length) return out;
          out.add(_PbField(number, wireType, data.sublist(i, i + 8), null));
          i += 8;
        case 2:
          final len = _varint(data, i);
          if (len == null) return out;
          final start = len.$2;
          final end = start + len.$1;
          if (end > data.length) return out;
          out.add(_PbField(number, wireType, data.sublist(start, end), null));
          i = end;
        case 5:
          if (i + 4 > data.length) return out;
          out.add(_PbField(number, wireType, data.sublist(i, i + 4), null));
          i += 4;
        default:
          // Unsupported wire type (group) — the payload is not GTFS-rt.
          throw FormatException('unsupported wire type $wireType');
      }
    }
    return out;
  }

  (int, int)? _varint(List<int> data, int i) {
    var result = 0;
    var shift = 0;
    var pos = i;
    while (pos < data.length) {
      final byte = data[pos++];
      result |= (byte & 0x7f) << shift;
      if (byte & 0x80 == 0) return (result, pos);
      shift += 7;
      if (shift > 63) return null;
    }
    return null;
  }

  double _float32(List<int> bytes) {
    final b = ByteData(4);
    for (var i = 0; i < 4; i++) {
      b.setUint8(i, bytes[i]);
    }
    return b.getFloat32(0, Endian.little);
  }
}

class _PbField {
  final int number;
  final int wireType;
  final List<int> bytes;
  final int? value;
  _PbField(this.number, this.wireType, this.bytes, this.value);
}
