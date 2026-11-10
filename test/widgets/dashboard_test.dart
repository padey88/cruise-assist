import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruise_assist/features/dashboard.dart';
import 'package:cruise_assist/store.dart';
import 'package:cruise_assist/widgets/registry.dart';
import 'package:cruise_assist/widgets/tile_contract.dart';

/// A tile that is not registered, used to prove the grid skips unknown ids.
void main() {
  group('GridLayout.place', () {
    test('does not overlap tiles on a 12-column car grid', () {
      final tiles = [
        const TilePlacement(id: 'clock', span: SizeSpan(6, 3)),
        const TilePlacement(id: 'weather', span: SizeSpan(6, 3)),
        const TilePlacement(id: 'prayer', span: SizeSpan(4, 3)),
        const TilePlacement(id: 'fuel', span: SizeSpan(4, 2)),
        const TilePlacement(id: 'forecast', span: SizeSpan(8, 2)),
      ];
      final placements = GridLayout.place(tiles, 12);

      expect(placements.length, tiles.length);
      for (var i = 0; i < placements.length; i++) {
        for (var j = i + 1; j < placements.length; j++) {
          expect(placements[i].overlaps(placements[j]), isFalse,
              reason: 'tile $i overlaps tile $j');
        }
      }
    });

    test('does not overlap tiles on an 8-column phone grid', () {
      final tiles = [
        const TilePlacement(id: 'clock', span: SizeSpan(6, 3)),
        const TilePlacement(id: 'weather', span: SizeSpan(6, 3)),
        const TilePlacement(id: 'notes', span: SizeSpan(4, 3)),
        const TilePlacement(id: 'fuel', span: SizeSpan(4, 2)),
        const TilePlacement(id: 'checklist', span: SizeSpan(4, 3)),
        const TilePlacement(id: 'shortcuts', span: SizeSpan(4, 2)),
      ];
      final placements = GridLayout.place(tiles, 8);

      expect(placements.length, tiles.length);
      for (var i = 0; i < placements.length; i++) {
        for (var j = i + 1; j < placements.length; j++) {
          expect(placements[i].overlaps(placements[j]), isFalse);
        }
      }
    });

    test('keeps a tile inside the grid width', () {
      final tiles = [const TilePlacement(id: 'forecast', span: SizeSpan(12, 2))];
      final placements = GridLayout.place(tiles, 8);
      expect(placements.single.columns, 8);
      expect(placements.single.column + placements.single.columns, lessThanOrEqualTo(8));
    });

    test('clamps a tile to its renderer minimum span', () {
      // The clock declares a 2x2 minimum, so a 1x1 request is grown.
      final tiles = [const TilePlacement(id: 'clock', span: SizeSpan(1, 1))];
      final placements = GridLayout.place(tiles, 12);
      final clock = tileById('clock')!;
      expect(placements.single.columns, greaterThanOrEqualTo(clock.minSpan.w));
      expect(placements.single.rows, greaterThanOrEqualTo(clock.minSpan.h));
    });

    test('clamps a tile to its renderer maximum span', () {
      final tiles = [const TilePlacement(id: 'clock', span: SizeSpan(12, 12))];
      final placements = GridLayout.place(tiles, 12);
      final clock = tileById('clock')!;
      expect(placements.single.columns, lessThanOrEqualTo(clock.maxSpan.w));
      expect(placements.single.rows, lessThanOrEqualTo(clock.maxSpan.h));
    });

    test('honours an explicit minimum span map', () {
      final tiles = [const TilePlacement(id: 'notes', span: SizeSpan(1, 1))];
      final placements = GridLayout.place(tiles, 12,
          minSpans: const {'notes': SizeSpan(3, 2)});
      expect(placements.single.columns, 3);
      expect(placements.single.rows, 2);
    });

    test('rowCount reports the used rows', () {
      final tiles = [
        const TilePlacement(id: 'clock', span: SizeSpan(6, 3)),
        const TilePlacement(id: 'weather', span: SizeSpan(6, 3)),
      ];
      final placements = GridLayout.place(tiles, 12);
      expect(GridLayout.rowCount(placements), 3);
      expect(GridLayout.rowCount(const []), 0);
    });

    test('columnsFor matches the surface', () {
      expect(GridLayout.columnsFor(Surface.car), 12);
      expect(GridLayout.columnsFor(Surface.phone), 8);
    });
  });

  group('DashboardGrid', () {
    testWidgets('renders tiles without overflow', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 800,
            child: DashboardGrid(
              tiles: const [
                TilePlacement(id: 'clock', span: SizeSpan(6, 3)),
                TilePlacement(id: 'weather', span: SizeSpan(6, 3)),
                TilePlacement(id: 'fuel', span: SizeSpan(4, 2)),
              ],
              surface: Surface.car,
              payloads: const {},
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Clock'), findsOneWidget);
      expect(find.text('Weather'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the empty state and the add button', (tester) async {
      var added = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DashboardGrid(
            tiles: const [],
            surface: Surface.phone,
            payloads: const {},
            onAdd: () => added = true,
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('No widgets yet'), findsOneWidget);
      await tester.tap(find.text('Add widget'));
      expect(added, isTrue);
    });

    testWidgets('reports a tapped tile id', (tester) async {
      String? tapped;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 800,
            child: DashboardGrid(
              tiles: const [TilePlacement(id: 'clock', span: SizeSpan(6, 3))],
              surface: Surface.car,
              payloads: const {},
              onTileTap: (id) => tapped = id,
            ),
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('Clock'));
      expect(tapped, 'clock');
    });

    testWidgets('removes a tile in edit mode', (tester) async {
      List<TilePlacement>? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 800,
            child: DashboardGrid(
              tiles: const [
                TilePlacement(id: 'clock', span: SizeSpan(6, 3)),
                TilePlacement(id: 'weather', span: SizeSpan(6, 3)),
              ],
              surface: Surface.car,
              payloads: const {},
              editing: true,
              onLayoutChanged: (next) => result = next,
            ),
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.length, 1);
      expect(result!.single.id, isNot('clock'));
    });

    testWidgets('renders unknown tile ids as empty space', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 800,
            child: DashboardGrid(
              tiles: const [TilePlacement(id: 'does-not-exist', span: SizeSpan(4, 2))],
              surface: Surface.car,
              payloads: const {},
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('registry', () {
    test('exposes every documented widget id', () {
      const expected = [
        'clock', 'weather', 'forecast', 'air', 'prayer', 'hijri', 'fuel',
        'fx', 'alerts', 'checklist', 'notes', 'reminder', 'shortcuts', 'speed',
        'transit', 'nearby', 'ev', 'radar', 'radio', 'music', 'ytm', 'sports',
        'football', 'calendar', 'qibla', 'asma', 'vela', 'map', 'nav',
      ];
      for (final id in expected) {
        expect(tileById(id), isNotNull, reason: 'missing tile $id');
      }
    });

    test('tileById returns null for an unknown id', () {
      expect(tileById('nope'), isNull);
    });

    test('allTiles has unique ids', () {
      final ids = allTiles().map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('tilesForSurface filters by surface', () {
      expect(tilesForSurface(Surface.phone), isNotEmpty);
      expect(tilesForSurface(Surface.car), isNotEmpty);
      for (final tile in tilesForSurface(Surface.car)) {
        expect(tile.surfaces.contains(Surface.car), isTrue);
      }
    });
  });
}
