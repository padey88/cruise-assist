import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/strings.dart';
import '../models/result.dart';
import '../store.dart';
import '../theme.dart';
import '../update/update_downloader.dart';
import '../update/update_service.dart';

/// About page: version, provenance, data sources, and the in-app updater.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, required this.store});

  final AppStore store;

  static const List<(String, String)> dataSources = [
    ('Open-Meteo — weather & air quality', 'https://open-meteo.com'),
    ('Aladhan / JAKIM — prayer times', 'https://aladhan.com'),
    ('DATA.gov.my — fuel, warnings, transit', 'https://data.gov.my'),
    ('Bank Negara Malaysia — exchange rates', 'https://apikijangportal.bnm.gov.my'),
    ('RainViewer — rain radar', 'https://www.rainviewer.com'),
    ('Open Charge Map — EV charging', 'https://openchargemap.io'),
    ('OpenStreetMap / Overpass — nearby places', 'https://www.openstreetmap.org'),
    ('LRCLIB — lyrics', 'https://lrclib.net'),
    ('Radio Browser — radio stations', 'https://www.radio-browser.info'),
    ('ESPN — sports scores', 'https://site.api.espn.com'),
    ('USGS — earthquakes', 'https://earthquake.usgs.gov'),
  ];

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final UpdateService _service = UpdateService();
  final UpdateDownloader _downloader = UpdateDownloader();

  bool _checking = false;
  Fetch<UpdateCheck>? _check;
  double? _progress;
  String? _status;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: CA.accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.dashboard_customize_outlined,
                color: CA.accent, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t('app.name'),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  const _VersionLine(),
                ]),
          ),
        ]),
        const SizedBox(height: 18),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'Cruise Assist is a clean-room reimplementation of a personal '
              'in-car dashboard. It has no accounts, no ads and no telemetry: '
              'nothing about you is collected or sent anywhere. All data is '
              'fetched directly from public government and open APIs and '
              'stays on this device.',
              style: TextStyle(fontSize: 13, height: 1.45, color: CA.dim),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const _SectionHeader('Updates'),
        _updateSection(context),
        const SizedBox(height: 22),
        const _SectionHeader('Data sources'),
        for (final (name, url) in AboutScreen.dataSources)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(name, style: const TextStyle(fontSize: 14)),
            trailing: const Icon(Icons.open_in_new, size: 16, color: CA.dim),
            onTap: () => _open(context, url),
          ),
        const SizedBox(height: 12),
        const Text(
          'Personal project. Not affiliated with Perodua, Sony, or the '
          'publisher of the application this was inspired by.',
          style: TextStyle(fontSize: 11, color: CA.dim, height: 1.4),
        ),
      ],
    );
  }

  Widget _updateSection(BuildContext context) {
    final check = _check;
    final available = check?.value?.updateAvailable ?? false;

    if (_checking) {
      return Row(children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: CA.accent),
        ),
        const SizedBox(width: 12),
        Text(context.t('update.checking'),
            style: const TextStyle(fontSize: 13, color: CA.dim)),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        OutlinedButton.icon(
          key: const Key('about.checkUpdates'),
          onPressed: _checkForUpdates,
          icon: const Icon(Icons.system_update_alt, size: 18),
          label: Text(context.t('about.updates')),
        ),
        const SizedBox(width: 10),
        if (check != null && check.ok && !available)
          Expanded(
            child: Text(context.t('about.upToDate'),
                style: const TextStyle(fontSize: 12, color: CA.good)),
          ),
      ]),
      if (check != null && check.message != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(check.message!,
              style: const TextStyle(fontSize: 12, color: CA.dim)),
        ),
      if (available && check != null) ...[
        const SizedBox(height: 10),
        Text(
          '${context.t('about.updateAvailable')}: '
          '${check.value!.latestVersion}',
          style: const TextStyle(fontSize: 13, color: CA.accent),
        ),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_status!,
                style: const TextStyle(fontSize: 12, color: CA.dim)),
          ),
        if (_progress != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
              value: _progress,
              color: CA.accent,
              backgroundColor: CA.glass,
            ),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('about.downloadUpdate'),
          onPressed: _progress == null ? () => _download(check.value!) : null,
          icon: const Icon(Icons.download, size: 18),
          label: Text(context.t('about.download')),
        ),
      ],
    ]);
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _checking = true;
      _status = null;
      _progress = null;
    });
    final result = await _service.checkForUpdates();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _check = result;
    });
  }

  Future<void> _download(UpdateCheck check) async {
    final asset = check.release.apk;
    if (asset == null) {
      setState(() => _status = 'This release has no APK attached.');
      return;
    }
    setState(() {
      _progress = 0;
      _status = null;
    });
    final result = await _downloader.downloadToCache(
      asset,
      isMetered: false,
      onProgress: (p) {
        if (!mounted) return;
        setState(() {
          _progress = p.fraction;
        });
      },
    );
    if (!mounted) return;

    final downloaded = result.value;
    if (!result.ok || downloaded == null) {
      setState(() {
        _progress = null;
        _status = result.message ?? 'Download failed';
      });
      return;
    }

    final install = await _downloader.install(downloaded);
    if (!mounted) return;
    setState(() {
      _progress = null;
      _status = install.ok
          ? 'Installer opened — confirm to update.'
          : (install.message ?? 'Could not open the installer');
    });
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // A failed launch must not crash the app.
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }
}

class _VersionLine extends StatelessWidget {
  const _VersionLine();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          final version =
              info == null ? '—' : '${info.version}+${info.buildNumber}';
          return Text('${context.t('about.version')} $version',
              style: const TextStyle(fontSize: 13, color: CA.dim));
        },
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(title,
            style: const TextStyle(
                color: CA.accent, fontSize: 13, fontWeight: FontWeight.w700)),
      );
}
