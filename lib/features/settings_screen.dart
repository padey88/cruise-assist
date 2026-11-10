import 'package:flutter/material.dart';

import '../app/strings.dart';
import '../store.dart';
import '../theme.dart';

/// Prayer zones offered in the settings dropdown.
///
/// The canonical list lives in `PrayerService.zones` once the data layer
/// lands; until then this const list keeps the screen self-contained.
const List<String> prayerZones = [
  'WLY01',
  'SGR01',
  'SGR02',
  'JHR02',
  'PNG01',
  'PRK01',
];

/// Application settings. Every control writes straight through to the store,
/// which persists the change and notifies listeners.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.settings;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _SectionHeader(title: context.t('settings.title')),
            SwitchListTile(
              key: const Key('settings.clock24'),
              title: Text(context.t('settings.clock24')),
              value: s.use24h,
              onChanged: (v) => store.updateSettings(s.copyWith(use24h: v)),
            ),
            SwitchListTile(
              key: const Key('settings.seconds'),
              title: Text(context.t('settings.seconds')),
              value: s.showSeconds,
              onChanged: (v) => store.updateSettings(s.copyWith(showSeconds: v)),
            ),
            SwitchListTile(
              key: const Key('settings.largeText'),
              title: Text(context.t('settings.largeText')),
              value: s.largeText,
              onChanged: (v) => store.updateSettings(s.copyWith(largeText: v)),
            ),
            SwitchListTile(
              key: const Key('settings.highContrast'),
              title: Text(context.t('settings.highContrast')),
              value: s.highContrast,
              onChanged: (v) => store.updateSettings(s.copyWith(highContrast: v)),
            ),
            ListTile(
              key: const Key('settings.language'),
              title: Text(context.t('settings.language')),
              trailing: DropdownButton<String>(
                value: s.language,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'ms', child: Text('Bahasa Melayu')),
                ],
                onChanged: (v) {
                  if (v != null) store.updateSettings(s.copyWith(language: v));
                },
              ),
            ),
            ListTile(
              key: const Key('settings.zone'),
              title: Text(context.t('settings.zone')),
              trailing: DropdownButton<String>(
                value: prayerZones.contains(s.prayerZone)
                    ? s.prayerZone
                    : prayerZones.first,
                underline: const SizedBox.shrink(),
                items: [
                  for (final z in prayerZones)
                    DropdownMenuItem(
                      value: z,
                      child: Text(context.t('zone.$z')),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) store.updateSettings(s.copyWith(prayerZone: v));
                },
              ),
            ),
            const Divider(height: 32),
            _SectionHeader(title: context.t('settings.city')),
            _CityField(store: store),
            const Divider(height: 32),
            _SectionHeader(title: context.t('settings.dataTitle')),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                context.t('settings.dataBody'),
                style: const TextStyle(color: CA.dim, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(title,
            style: const TextStyle(
                color: CA.accent, fontSize: 13, fontWeight: FontWeight.w700)),
      );
}

/// City name plus optional coordinates. The fields commit on submit so the
/// store is not written on every keystroke.
class _CityField extends StatefulWidget {
  final AppStore store;
  const _CityField({required this.store});

  @override
  State<_CityField> createState() => _CityFieldState();
}

class _CityFieldState extends State<_CityField> {
  late final TextEditingController _city;
  late final TextEditingController _lat;
  late final TextEditingController _lng;

  @override
  void initState() {
    super.initState();
    final s = widget.store.settings;
    _city = TextEditingController(text: s.cityName);
    _lat = TextEditingController(text: s.lat?.toString() ?? '');
    _lng = TextEditingController(text: s.lng?.toString() ?? '');
  }

  @override
  void dispose() {
    _city.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  void _commit() {
    final s = widget.store.settings;
    widget.store.updateSettings(s.copyWith(
      cityName: _city.text.trim().isEmpty ? 'Kuala Lumpur' : _city.text.trim(),
      lat: double.tryParse(_lat.text.trim()),
      lng: double.tryParse(_lng.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            key: const Key('settings.cityName'),
            controller: _city,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: context.t('settings.city'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _commit(),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                key: const Key('settings.lat'),
                controller: _lat,
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Latitude', border: OutlineInputBorder(), isDense: true),
                onSubmitted: (_) => _commit(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('settings.lng'),
                controller: _lng,
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Longitude', border: OutlineInputBorder(), isDense: true),
                onSubmitted: (_) => _commit(),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const Key('settings.saveLocation'),
              onPressed: _commit,
              child: Text(context.t('action.save')),
            ),
          ),
        ]),
      );
}
