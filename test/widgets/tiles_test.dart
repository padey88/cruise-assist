import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruise_assist/models/data.dart';
import 'package:cruise_assist/widgets/core_tiles.dart';
import 'package:cruise_assist/widgets/personal_tiles.dart';
import 'package:cruise_assist/widgets/tile_contract.dart';

/// Fixed clock used by every test so nothing depends on the wall clock.
final DateTime fixedNow = DateTime(2026, 11, 10, 14, 32, 5);

TileContext ctxWith({
  Map<String, dynamic> payloads = const {},
  Map<String, dynamic> config = const {},
  void Function(Map<String, dynamic>)? onConfigChanged,
}) =>
    TileContext(
      now: fixedNow,
      surface: Surface.phone,
      config: config,
      payloads: payloads,
      onConfigChanged: onConfigChanged ?? (_) {},
      onRemove: (_) {},
    );

Widget host(Widget child, {Size size = const Size(400, 300)}) => MaterialApp(
      home: Scaffold(body: SizedBox(width: size.width, height: size.height, child: child)),
    );

/// Renders a tile through its renderer so the tile receives a real
/// [BuildContext].
Widget renderTile(TileRenderer tile, TileContext ctx) =>
    Builder(builder: (context) => tile.build(context, ctx));

void main() {
  group('clock formatting', () {
    test('24-hour clock pads the hour', () {
      expect(formatClock(DateTime(2026, 11, 10, 9, 5), use24h: true), '09:05');
    });

    test('24-hour clock shows midnight as 00:00', () {
      expect(formatClock(DateTime(2026, 11, 10, 0, 0), use24h: true), '00:00');
    });

    test('24-hour clock shows 23:59', () {
      expect(formatClock(DateTime(2026, 11, 10, 23, 59), use24h: true), '23:59');
    });

    test('12-hour clock uses 12 for midnight', () {
      expect(formatClock(DateTime(2026, 11, 10, 0, 7), use24h: false), '12:07');
    });

    test('12-hour clock uses 12 for noon', () {
      expect(formatClock(DateTime(2026, 11, 10, 12, 0), use24h: false), '12:00');
    });

    test('12-hour clock uses 1 in the afternoon', () {
      expect(formatClock(DateTime(2026, 11, 10, 13, 45), use24h: false), '1:45');
    });

    test('seconds are appended only when requested', () {
      expect(formatClock(DateTime(2026, 11, 10, 14, 32, 5), use24h: true), '14:32');
      expect(
        formatClock(DateTime(2026, 11, 10, 14, 32, 5), use24h: true, seconds: true),
        '14:32:05',
      );
    });

    test('meridiem switches at noon', () {
      expect(clockMeridiem(DateTime(2026, 11, 10, 11, 59)), 'AM');
      expect(clockMeridiem(DateTime(2026, 11, 10, 12, 0)), 'PM');
    });
  });

  group('clock tile', () {
    testWidgets('shows the time and date', (tester) async {
      await tester.pumpWidget(host(renderTile(const ClockTile(), ctxWith())));
      await tester.pump();
      expect(find.textContaining('14:32'), findsOneWidget);
    });

    testWidgets('renders in 12-hour mode', (tester) async {
      await tester.pumpWidget(host(renderTile(const ClockTile(), ctxWith(config: const {'use24h': false}))));
      await tester.pump();
      expect(find.textContaining('2:32'), findsOneWidget);
      expect(find.text('PM'), findsOneWidget);
    });
  });

  group('weather tile', () {
    testWidgets('shows a labelled placeholder when the payload is missing',
        (tester) async {
      await tester.pumpWidget(host(renderTile(const WeatherTile(), ctxWith())));
      await tester.pump();
      expect(find.text('Weather unavailable'), findsOneWidget);
    });

    testWidgets('renders temperature, humidity and wind', (tester) async {
      final weather = WeatherNow(
        tempC: 31.4,
        feelsC: 34.2,
        humidity: 78,
        windKph: 12.5,
        weatherCode: 2,
        observedAt: fixedNow,
      );
      await tester.pumpWidget(host(
        renderTile(const WeatherTile(), ctxWith(payloads: {'weather': weather}))));
      await tester.pump();
      expect(find.text('31°C'), findsOneWidget);
      expect(find.textContaining('Feels 34°'), findsOneWidget);
      expect(find.textContaining('78% humidity'), findsOneWidget);
      expect(find.textContaining('Wind 13 km/h'), findsOneWidget);
    });

    testWidgets('renders a cached JSON payload', (tester) async {
      final json = WeatherNow(
        tempC: 27,
        feelsC: 29,
        humidity: 60,
        windKph: 8,
        weatherCode: 0,
        observedAt: fixedNow,
      ).toJson();
      await tester.pumpWidget(host(
        renderTile(const WeatherTile(), ctxWith(payloads: {'weather': json}))));
      await tester.pump();
      expect(find.text('27°C'), findsOneWidget);
    });
  });

  group('forecast tile', () {
    testWidgets('shows a placeholder without data', (tester) async {
      await tester.pumpWidget(host(renderTile(const ForecastTile(), ctxWith())));
      await tester.pump();
      expect(find.text('Forecast unavailable'), findsOneWidget);
    });

    testWidgets('renders a 7-day strip with min and max', (tester) async {
      final days = [
        for (var i = 0; i < 7; i++)
          DayForecast(
            day: fixedNow.add(Duration(days: i)),
            code: 1,
            minC: 24.0 + i.toDouble(),
            maxC: 32.0 + i.toDouble(),
          ),
      ];
      await tester.pumpWidget(host(
        renderTile(
          const ForecastTile(),
          ctxWith(payloads: {'forecast': days}),
        ),
        size: const Size(800, 400),
      ));
      await tester.pump();
      expect(find.text('24°'), findsOneWidget);
      expect(find.text('32°'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('fuel tile', () {
    testWidgets('shows a placeholder without data', (tester) async {
      await tester.pumpWidget(host(renderTile(const FuelTile(), ctxWith())));
      await tester.pump();
      expect(find.text('Fuel prices unavailable'), findsOneWidget);
    });

    testWidgets('renders RON95, RON97 and diesel with the effective date',
        (tester) async {
      final fuel = FuelPrices(
        ron95: 2.05,
        ron97: 2.15,
        diesel: 1.85,
        effectiveFrom: DateTime(2026, 11, 5),
      );
      await tester.pumpWidget(host(
        renderTile(const FuelTile(), ctxWith(payloads: {'fuel': fuel}))));
      await tester.pump();
      expect(find.text('RM 2.05'), findsOneWidget);
      expect(find.text('RM 2.15'), findsOneWidget);
      expect(find.text('RM 1.85'), findsOneWidget);
      expect(find.text('Effective 5 Nov 2026'), findsOneWidget);
    });
  });

  group('prayer tile', () {
    testWidgets('shows a placeholder without data', (tester) async {
      await tester.pumpWidget(host(renderTile(const PrayerTile(), ctxWith())));
      await tester.pump();
      expect(find.text('Prayer times unavailable'), findsOneWidget);
    });

    testWidgets('shows the next prayer and a countdown', (tester) async {
      final day = PrayerDay(
        date: DateTime(2026, 11, 10),
        zone: 'WLY01',
        times: [
          PrayerTime('Fajr', DateTime(2026, 11, 10, 5, 42)),
          PrayerTime('Dhuhr', DateTime(2026, 11, 10, 13, 10)),
          PrayerTime('Asr', DateTime(2026, 11, 10, 16, 25)),
          PrayerTime('Maghrib', DateTime(2026, 11, 10, 18, 55)),
          PrayerTime('Isha', DateTime(2026, 11, 10, 20, 10)),
        ],
      );
      await tester.pumpWidget(host(
        renderTile(
          const PrayerTile(),
          ctxWith(payloads: {'prayer': day}),
        ),
        size: const Size(500, 320),
      ));
      await tester.pump();
      // 'Asr' and its time appear twice by design: once in the NEXT header,
      // once in the full schedule list. The countdown is the unique element.
      expect(find.text('Asr'), findsWidgets);
      expect(find.text('16:25'), findsWidgets);
      // now = 14:32:05, Asr = 16:25 -> 1h 52m 55s. countdown() truncates
      // minutes rather than rounding, so 52 is correct, not 53.
      expect(find.text('1 h 52 min'), findsOneWidget);
    });
  });

  group('checklist tile', () {
    testWidgets('shows an empty state', (tester) async {
      await tester.pumpWidget(host(renderTile(const ChecklistTile(), ctxWith())));
      await tester.pump();
      expect(find.text('Nothing on the list'), findsOneWidget);
    });

    testWidgets('toggling an item mutates the item list', (tester) async {
      Map<String, dynamic>? written;
      final items = [
        const ChecklistItem(id: 'a', text: 'Tyres'),
        const ChecklistItem(id: 'b', text: 'Wipers', done: true),
      ];
      await tester.pumpWidget(host(
        renderTile(
          const ChecklistTile(),
          ctxWith(
            payloads: {'checklist': items},
            onConfigChanged: (next) => written = next,
          ),
        ),
        size: const Size(500, 400),
      ));
      await tester.pump();

      expect(find.text('Tyres'), findsOneWidget);
      // 'b' is already done in the fixture, so the tally starts at 1/2.
      expect(find.text('1/2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('checklist-a')));
      await tester.pump();

      expect(written, isNotNull);
      final updated = ChecklistItem.fromJson(
          (written!['items'] as List).first.cast<String, dynamic>());
      expect(updated.id, 'a');
      expect(updated.done, isTrue);
      expect(updated.text, 'Tyres');
    });

    testWidgets('a second tap clears the done flag', (tester) async {
      Map<String, dynamic>? written;
      final items = [const ChecklistItem(id: 'a', text: 'Tyres', done: true)];
      await tester.pumpWidget(host(
        renderTile(
          const ChecklistTile(),
          ctxWith(
            payloads: {'checklist': items},
            onConfigChanged: (next) => written = next,
          ),
        ),
        size: const Size(500, 400),
      ));
      await tester.pump();

      await tester.tap(find.byKey(const Key('checklist-a')));
      await tester.pump();

      final updated = ChecklistItem.fromJson(
          (written!['items'] as List).first.cast<String, dynamic>());
      expect(updated.done, isFalse);
    });
  });

  group('notes tile', () {
    testWidgets('shows an empty state', (tester) async {
      await tester.pumpWidget(host(renderTile(const NotesTile(), ctxWith())));
      await tester.pump();
      expect(find.text('No notes yet'), findsOneWidget);
    });

    testWidgets('renders stored notes', (tester) async {
      final notes = [
        Note(id: 'n1', text: 'Call workshop', updatedAt: fixedNow),
      ];
      await tester.pumpWidget(host(
        renderTile(const NotesTile(), ctxWith(payloads: {'notes': notes}))));
      await tester.pump();
      expect(find.text('Call workshop'), findsOneWidget);
    });
  });

  group('shortcuts tile', () {
    testWidgets('shows an empty state', (tester) async {
      await tester.pumpWidget(host(renderTile(const ShortcutsTile(), ctxWith())));
      await tester.pump();
      expect(find.text('No shortcuts configured'), findsOneWidget);
    });

    testWidgets('renders shortcut rows', (tester) async {
      final shortcuts = [
        const Shortcut(id: 's1', label: 'Maps', uri: 'geo:0,0'),
        const Shortcut(id: 's2', label: 'Music', package: 'com.spotify.music'),
      ];
      await tester.pumpWidget(host(
        renderTile(const ShortcutsTile(), ctxWith(payloads: {'shortcuts': shortcuts}))));
      await tester.pump();
      expect(find.text('Maps'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
    });
  });
}
