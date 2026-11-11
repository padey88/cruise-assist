import 'package:flutter/material.dart';

/// Minimal localisation: English + Bahasa Melayu. Deliberately not using
/// generated ARB files — two locales with ~60 keys do not justify the
/// codegen step, and a plain map is easier to audit.
class L {
  final String code;
  const L(this.code);

  static const en = L('en');
  static const ms = L('ms');

  static L of(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ms' ? ms : en;

  String get _k => code;

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'app.name': 'Cruise Assist',
      'tab.dashboard': 'Dashboard',
      'tab.edit': 'Edit',
      'tab.settings': 'Settings',
      'tab.project': 'Car screen',
      'tab.about': 'About',
      'action.add': 'Add widget',
      'action.remove': 'Remove',
      'action.done': 'Done',
      'action.save': 'Save',
      'action.cancel': 'Cancel',
      'action.refresh': 'Refresh',
      'state.loading': 'Loading…',
      'state.offline': 'Offline',
      'state.stale': 'Showing last known data',
      'state.unavailable': 'Unavailable',
      'state.noData': 'No data yet',
      'clock.nextPrayer': 'Next',
      'weather.feels': 'Feels like',
      'weather.humidity': 'Humidity',
      'weather.wind': 'Wind',
      'weather.sunrise': 'Sunrise',
      'weather.sunset': 'Sunset',
      'weather.forecast': '7-day forecast',
      'air.title': 'Air quality',
      'prayer.next': 'Next prayer',
      'prayer.today': "Today's prayers",
      'fuel.title': 'Fuel prices',
      'fuel.effective': 'Effective',
      'fuel.ron95': 'RON 95',
      'fuel.ron97': 'RON 97',
      'fuel.diesel': 'Diesel',
      'fx.title': 'Exchange rates',
      'alerts.title': 'Alerts',
      'alerts.none': 'No warnings right now',
      'checklist.title': 'Checklist',
      'checklist.empty': 'Nothing on the list',
      'checklist.add': 'Add item',
      'notes.title': 'Notes',
      'notes.empty': 'No notes yet',
      'shortcuts.title': 'Shortcuts',
      'shortcuts.empty': 'Add shortcuts in settings',
      'speed.title': 'Speed',
      'transit.title': 'Buses & trains',
      'nearby.title': 'Nearby',
      'ev.title': 'EV charging',
      'radar.title': 'Rain radar',
      'radio.title': 'Radio',
      'music.title': 'Now playing',
      'sports.title': 'Sports',
      'calendar.title': 'Calendar',
      'qibla.title': 'Qibla',
      'hijri.title': 'Hijri date',
      'asma.title': 'Asma ul-Husna',
      'settings.title': 'Settings',
      'settings.clock24': '24-hour clock',
      'settings.seconds': 'Show seconds',
      'settings.largeText': 'Larger text',
      'settings.highContrast': 'High contrast',
      'settings.language': 'Language',
      'settings.zone': 'Prayer zone',
      'settings.city': 'Weather location',
      'settings.useLocation': 'Use my location',
      'settings.dataTitle': 'Data & privacy',
      'settings.dataBody':
          'Cruise Assist has no accounts, no ads and no telemetry. '
          'Weather, prayer times, fuel prices and exchange rates come '
          'directly from public government and open APIs.',
      'car.title': 'Car screen',
      'car.preview': 'Preview',
      'car.usb': 'Connect to head unit',
      'car.state.idle': 'Not connected',
      'car.state.attached': 'Head unit detected',
      'car.state.error': 'Connection error',
      'car.diagnostics': 'USB diagnostics',
      'about.version': 'Version',
      'about.updates': 'Check for updates',
      'about.upToDate': 'You have the latest version',
      'about.updateAvailable': 'Update available',
      'about.download': 'Download update',
      'update.checking': 'Checking for updates…',
      'update.unavailable': 'Update check unavailable',
      'widget.pick': 'Choose widgets',
      'zone.WLY01': 'Kuala Lumpur',
      'zone.SGR01': 'Shah Alam',
      'zone.SGR02': 'Klang',
      'zone.JHR02': 'Johor Bahru',
      'zone.PNG01': 'Penang',
      'zone.PRK01': 'Ipoh',
    },
    'ms': {
      'app.name': 'Cruise Assist',
      'tab.dashboard': 'Papan pemuka',
      'tab.edit': 'Sunting',
      'tab.settings': 'Tetapan',
      'tab.project': 'Skrin kereta',
      'tab.about': 'Perihal',
      'action.add': 'Tambah widget',
      'action.remove': 'Buang',
      'action.done': 'Selesai',
      'action.save': 'Simpan',
      'action.cancel': 'Batal',
      'action.refresh': 'Muat semula',
      'state.loading': 'Memuatkan…',
      'state.offline': 'Luar talian',
      'state.stale': 'Menunjukkan data terakhir',
      'state.unavailable': 'Tidak tersedia',
      'state.noData': 'Tiada data lagi',
      'clock.nextPrayer': 'Seterusnya',
      'weather.feels': 'Terasa',
      'weather.humidity': 'Kelembapan',
      'weather.wind': 'Angin',
      'weather.sunrise': 'Matahari terbit',
      'weather.sunset': 'Matahari terbenam',
      'weather.forecast': 'Ramalan 7 hari',
      'air.title': 'Kualiti udara',
      'prayer.next': 'Solat seterusnya',
      'prayer.today': 'Solat hari ini',
      'fuel.title': 'Harga minyak',
      'fuel.effective': 'Berkuat kuasa',
      'fuel.ron95': 'RON 95',
      'fuel.ron97': 'RON 97',
      'fuel.diesel': 'Diesel',
      'fx.title': 'Kadar tukaran',
      'alerts.title': 'Amaran',
      'alerts.none': 'Tiada amaran sekarang',
      'checklist.title': 'Senarai semak',
      'checklist.empty': 'Tiada apa dalam senarai',
      'checklist.add': 'Tambah item',
      'notes.title': 'Nota',
      'notes.empty': 'Belum ada nota',
      'shortcuts.title': 'Pintasan',
      'shortcuts.empty': 'Tambah pintasan dalam tetapan',
      'speed.title': 'Laju',
      'transit.title': 'Bas & kereta api',
      'nearby.title': 'Berdekatan',
      'ev.title': 'Pengecas EV',
      'radar.title': 'Radar hujan',
      'radio.title': 'Radio',
      'music.title': 'Sedang dimainkan',
      'sports.title': 'Sukan',
      'calendar.title': 'Kalendar',
      'qibla.title': 'Kiblat',
      'hijri.title': 'Tarikh Hijri',
      'asma.title': 'Asma ul-Husna',
      'settings.title': 'Tetapan',
      'settings.clock24': 'Jam 24 jam',
      'settings.seconds': 'Tunjuk saat',
      'settings.largeText': 'Teks lebih besar',
      'settings.highContrast': 'Kontras tinggi',
      'settings.language': 'Bahasa',
      'settings.zone': 'Zon solat',
      'settings.city': 'Lokasi cuaca',
      'settings.useLocation': 'Guna lokasi saya',
      'settings.dataTitle': 'Data & privasi',
      'settings.dataBody':
          'Cruise Assist tiada akaun, tiada iklan dan tiada telemetri. '
          'Cuaca, waktu solat, harga minyak dan kadar tukaran diambil '
          'terus daripada API awam kerajaan dan sumber terbuka.',
      'car.title': 'Skrin kereta',
      'car.preview': 'Pratonton',
      'car.usb': 'Sambung ke unit kepala',
      'car.state.idle': 'Tidak bersambung',
      'car.state.attached': 'Unit kepala dikesan',
      'car.state.error': 'Ralat sambungan',
      'car.diagnostics': 'Diagnostik USB',
      'about.version': 'Versi',
      'about.updates': 'Semak kemas kini',
      'about.upToDate': 'Anda mempunyai versi terkini',
      'about.updateAvailable': 'Kemas kini tersedia',
      'about.download': 'Muat turun kemas kini',
      'update.checking': 'Menyemak kemas kini…',
      'update.unavailable': 'Semakan kemas kini tidak tersedia',
      'widget.pick': 'Pilih widget',
      'zone.WLY01': 'Kuala Lumpur',
      'zone.SGR01': 'Shah Alam',
      'zone.SGR02': 'Klang',
      'zone.JHR02': 'Johor Bahru',
      'zone.PNG01': 'Pulau Pinang',
      'zone.PRK01': 'Ipoh',
    },
  };

  /// Missing keys fall back to the English string, then to the key itself, so
  /// a typo degrades visibly instead of rendering an empty box.
  String t(String key) => _strings[_k]?[key] ?? _strings['en']?[key] ?? key;

  static L ofCode(String code) => code == 'ms' ? ms : en;
}

class LDelegate extends LocalizationsDelegate<L> {
  const LDelegate();
  @override
  bool isSupported(Locale locale) =>
      const ['en', 'ms'].contains(locale.languageCode);
  @override
  Future<L> load(Locale locale) async => L.ofCode(locale.languageCode);
  @override
  bool shouldReload(LDelegate old) => false;
}

extension LContext on BuildContext {
  L get l => L.of(this);
  String t(String key) => L.of(this).t(key);
}
