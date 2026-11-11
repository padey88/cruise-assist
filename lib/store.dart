import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/data.dart';
import 'widgets/tile_contract.dart';

/// One placed tile on the dashboard.
@immutable
class TilePlacement {
  final String id;
  final SizeSpan span;
  final Map<String, dynamic> config;

  const TilePlacement({
    required this.id,
    required this.span,
    this.config = const {},
  });

  TilePlacement copyWith({SizeSpan? span, Map<String, dynamic>? config}) =>
      TilePlacement(
        id: id,
        span: span ?? this.span,
        config: config ?? this.config,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'w': span.w,
    'h': span.h,
    'config': config,
  };

  factory TilePlacement.fromJson(Map<String, dynamic> j) => TilePlacement(
    id: j['id'] as String,
    span: SizeSpan((j['w'] as num).toInt(), (j['h'] as num).toInt()),
    config: (j['config'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
}

/// App-wide persisted settings.
@immutable
class AppSettings {
  final bool use24h;
  final bool largeText;
  final String language; // en | ms
  final String prayerZone;
  final double? lat;
  final double? lng;
  final String cityName;
  final String weatherMode; // auto | manual
  final bool highContrast;
  final bool carMode;
  final bool showSeconds;

  const AppSettings({
    this.use24h = true,
    this.largeText = false,
    this.language = 'en',
    this.prayerZone = 'WLY01',
    this.lat,
    this.lng,
    this.cityName = 'Kuala Lumpur',
    this.weatherMode = 'auto',
    this.highContrast = false,
    this.carMode = false,
    this.showSeconds = false,
  });

  AppSettings copyWith({
    bool? use24h,
    bool? largeText,
    String? language,
    String? prayerZone,
    double? lat,
    double? lng,
    String? cityName,
    String? weatherMode,
    bool? highContrast,
    bool? carMode,
    bool? showSeconds,
  }) => AppSettings(
    use24h: use24h ?? this.use24h,
    largeText: largeText ?? this.largeText,
    language: language ?? this.language,
    prayerZone: prayerZone ?? this.prayerZone,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    cityName: cityName ?? this.cityName,
    weatherMode: weatherMode ?? this.weatherMode,
    highContrast: highContrast ?? this.highContrast,
    carMode: carMode ?? this.carMode,
    showSeconds: showSeconds ?? this.showSeconds,
  );

  Map<String, dynamic> toJson() => {
    'use24h': use24h,
    'largeText': largeText,
    'language': language,
    'prayerZone': prayerZone,
    'lat': lat,
    'lng': lng,
    'cityName': cityName,
    'weatherMode': weatherMode,
    'highContrast': highContrast,
    'carMode': carMode,
    'showSeconds': showSeconds,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    use24h: j['use24h'] as bool? ?? true,
    largeText: j['largeText'] as bool? ?? false,
    language: j['language'] as String? ?? 'en',
    prayerZone: j['prayerZone'] as String? ?? 'WLY01',
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    cityName: j['cityName'] as String? ?? 'Kuala Lumpur',
    weatherMode: j['weatherMode'] as String? ?? 'auto',
    highContrast: j['highContrast'] as bool? ?? false,
    carMode: j['carMode'] as bool? ?? false,
    showSeconds: j['showSeconds'] as bool? ?? false,
  );
}

/// Versioned persistent state. A version bump must include a migration; an
/// unknown/newer version falls back to defaults rather than crashing.
class AppStore extends ChangeNotifier {
  static const _kVersion = 'store.version';
  static const _kSettings = 'store.settings';
  static const _kLayout = 'store.layout';
  static const _kChecklist = 'store.checklist';
  static const _kNotes = 'store.notes';
  static const _kPayloads = 'store.payloads';
  static const _kShortcuts = 'store.shortcuts';
  static const currentVersion = 2;

  late SharedPreferences _prefs;

  AppSettings settings = const AppSettings();
  List<TilePlacement> layout = const [];
  List<ChecklistItem> checklist = const [];
  List<Note> notes = const [];
  List<Shortcut> shortcuts = const [];
  Map<String, dynamic> payloads = const {};

  bool get ready => _loaded;
  bool _loaded = false;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final v = _prefs.getInt(_kVersion) ?? 0;
    if (v > currentVersion) {
      // Written by a newer build: keep defaults, do not delete their data.
      _loaded = true;
      notifyListeners();
      return;
    }
    settings = _decode(_kSettings, AppSettings.fromJson, const AppSettings());
    layout = _decodeList(_kLayout, TilePlacement.fromJson);
    checklist = _decodeList(_kChecklist, ChecklistItem.fromJson);
    notes = _decodeList(_kNotes, Note.fromJson);
    shortcuts = _decodeList(_kShortcuts, Shortcut.fromJson);
    payloads = _decodeMap(_kPayloads);
    if (v < currentVersion) await _migrate(v);
    await _prefs.setInt(_kVersion, currentVersion);
    _loaded = true;
    notifyListeners();
  }

  Future<void> _migrate(int from) async {
    if (from < 1) {
      // v1 stored a bare list of tile ids; give them default spans.
      final raw = _prefs.getStringList('layout.v1');
      if (raw != null && raw.isNotEmpty) {
        layout = raw
            .map((id) => TilePlacement(id: id, span: SizeSpan.one))
            .toList(growable: false);
      }
    }
    if (from < 2 && layout.isEmpty) {
      layout = defaultLayout;
    }
  }

  T _decode<T>(String key, T Function(Map<String, dynamic>) f, T fallback) {
    final raw = _prefs.getString(key);
    if (raw == null) return fallback;
    try {
      final m = jsonDecode(raw);
      if (m is Map<String, dynamic>) return f(m);
    } on FormatException {
      return fallback;
    }
    return fallback;
  }

  List<T> _decodeList<T>(String key, T Function(Map<String, dynamic>) f) {
    final raw = _prefs.getString(key);
    if (raw == null) return const [];
    try {
      final l = jsonDecode(raw);
      if (l is! List) return const [];
      return l.whereType<Map<String, dynamic>>().map(f).toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  Map<String, dynamic> _decodeMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return const {};
    try {
      final m = jsonDecode(raw);
      return m is Map<String, dynamic> ? m : const {};
    } on FormatException {
      return const {};
    }
  }

  Future<void> _put(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));

  static List<TilePlacement> get defaultLayout => const [
    TilePlacement(id: 'clock', span: SizeSpan(6, 3)),
    TilePlacement(id: 'weather', span: SizeSpan(6, 3)),
    TilePlacement(id: 'prayer', span: SizeSpan(4, 3)),
    TilePlacement(id: 'fuel', span: SizeSpan(4, 2)),
    TilePlacement(id: 'forecast', span: SizeSpan(8, 2)),
    TilePlacement(id: 'checklist', span: SizeSpan(4, 3)),
    TilePlacement(id: 'shortcuts', span: SizeSpan(4, 2)),
  ];

  // ---- mutations -------------------------------------------------------

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    notifyListeners();
    await _put(_kSettings, next.toJson());
  }

  Future<void> setLayout(List<TilePlacement> next) async {
    layout = List.unmodifiable(next);
    notifyListeners();
    await _put(_kLayout, next.map((e) => e.toJson()).toList());
  }

  Future<void> moveTile(int from, int to) async {
    if (from < 0 || from >= layout.length) return;
    final next = [...layout];
    final item = next.removeAt(from);
    next.insert(to.clamp(0, next.length), item);
    await setLayout(next);
  }

  Future<void> resizeTile(String id, SizeSpan span) async {
    await setLayout([
      for (final t in layout)
        if (t.id == id) t.copyWith(span: span) else t,
    ]);
  }

  Future<void> removeTile(String id) async {
    await setLayout(layout.where((t) => t.id != id).toList());
  }

  Future<void> addTile(
    String id,
    SizeSpan span, {
    Map<String, dynamic> config = const {},
  }) async {
    if (layout.any((t) => t.id == id)) return;
    await setLayout([
      ...layout,
      TilePlacement(id: id, span: span, config: config),
    ]);
  }

  Future<void> updateTileConfig(String id, Map<String, dynamic> config) async {
    await setLayout([
      for (final t in layout)
        if (t.id == id) t.copyWith(config: config) else t,
    ]);
  }

  Future<void> setChecklist(List<ChecklistItem> next) async {
    checklist = List.unmodifiable(next);
    notifyListeners();
    await _put(_kChecklist, next.map((e) => e.toJson()).toList());
  }

  Future<void> toggleChecklist(String id) async {
    await setChecklist([
      for (final i in checklist)
        if (i.id == id) i.copyWith(done: !i.done) else i,
    ]);
  }

  Future<void> addChecklistItem(ChecklistItem item) async {
    await setChecklist([...checklist, item]);
  }

  Future<void> removeChecklistItem(String id) async {
    await setChecklist(checklist.where((e) => e.id != id).toList());
  }

  Future<void> setNotes(List<Note> next) async {
    notes = List.unmodifiable(next);
    notifyListeners();
    await _put(_kNotes, next.map((e) => e.toJson()).toList());
  }

  Future<void> setShortcuts(List<Shortcut> next) async {
    shortcuts = List.unmodifiable(next);
    notifyListeners();
    await _put(_kShortcuts, next.map((e) => e.toJson()).toList());
  }

  /// Persists the last-good payload for each data key so the dashboard can
  /// paint immediately on next launch, before the network answers.
  Future<void> cachePayload(String key, Object? value) async {
    if (value == null) return;
    final next = {...payloads, key: _encodePayload(value)};
    payloads = Map.unmodifiable(next);
    await _put(_kPayloads, next);
  }

  Object? _encodePayload(Object? v) {
    if (v == null) return null;
    if (v is List) {
      return v.map<Object?>((e) => _encodePayload(e)).toList();
    }
    if (v is Map) {
      return v.map<String, Object?>(
        (k, val) => MapEntry(k.toString(), _encodePayload(val)),
      );
    }
    if (v is DateTime) return v.toIso8601String();
    return v;
  }
}
