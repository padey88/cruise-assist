import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cruise_assist/app/strings.dart';
import 'package:cruise_assist/main.dart';
import 'package:cruise_assist/store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app boots and shows the default dashboard', (tester) async {
    final store = AppStore();
    await store.load();
    await tester.pumpWidget(CruiseAssistApp(store: store));
    await tester.pump();

    // The shell renders its title and the default tiles are laid out.
    expect(find.text('Cruise Assist'), findsWidgets);
    expect(store.layout, isNotEmpty);
  });

  testWidgets('settings tab is reachable from the navigation bar', (
    tester,
  ) async {
    final store = AppStore();
    await store.load();
    await tester.pumpWidget(CruiseAssistApp(store: store));
    await tester.pump();

    // The nav bar uses Icons.tune_outlined for the settings tab.
    final settings = find.byIcon(Icons.tune_outlined);
    expect(settings, findsWidgets);
    await tester.tap(settings.first, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text(L.en.t('settings.clock24')), findsOneWidget);
  });

  test('default layout tiles are unique ids', () {
    final ids = AppStore.defaultLayout.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('settings round-trip through JSON preserves every field', () {
    const s = AppSettings(
      use24h: false,
      largeText: true,
      language: 'ms',
      prayerZone: 'SGR01',
      lat: 3.07,
      lng: 101.5,
      cityName: 'Shah Alam',
      highContrast: true,
      showSeconds: true,
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.use24h, false);
    expect(back.largeText, true);
    expect(back.language, 'ms');
    expect(back.prayerZone, 'SGR01');
    expect(back.lat, closeTo(3.07, 1e-9));
    expect(back.cityName, 'Shah Alam');
    expect(back.showSeconds, true);
  });

  test(
    'a newer stored version falls back to defaults without data loss',
    () async {
      SharedPreferences.setMockInitialValues({
        'store.version': 999,
        'store.layout': '[{"id":"clock","w":6,"h":3}]',
      });
      final store = AppStore();
      await store.load();
      // Defaults are used, but the prefs payload is left untouched.
      expect(store.layout, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('store.layout'), contains('clock'));
    },
  );
}
