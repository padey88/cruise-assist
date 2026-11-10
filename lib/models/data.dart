/// Immutable payload models shared between the data layer and the tile layer.
///
/// Every model is JSON-round-trippable via [toJson]/`fromJson` so the store can
/// cache the last good payload and the UI can render it while offline.
library;

class WeatherNow {
  final double tempC;
  final double feelsC;
  final int humidity;
  final double windKph;
  final int weatherCode;
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime observedAt;

  const WeatherNow({
    required this.tempC,
    required this.feelsC,
    required this.humidity,
    required this.windKph,
    required this.weatherCode,
    required this.observedAt,
    this.sunrise,
    this.sunset,
  });

  factory WeatherNow.fromJson(Map<String, dynamic> j) => WeatherNow(
        tempC: (j['tempC'] as num).toDouble(),
        feelsC: (j['feelsC'] as num).toDouble(),
        humidity: (j['humidity'] as num).toInt(),
        windKph: (j['windKph'] as num).toDouble(),
        weatherCode: (j['weatherCode'] as num).toInt(),
        sunrise: _dt(j['sunrise']),
        sunset: _dt(j['sunset']),
        observedAt: _dt(j['observedAt']) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'tempC': tempC,
        'feelsC': feelsC,
        'humidity': humidity,
        'windKph': windKph,
        'weatherCode': weatherCode,
        'sunrise': sunrise?.toIso8601String(),
        'sunset': sunset?.toIso8601String(),
        'observedAt': observedAt.toIso8601String(),
      };
}

class DayForecast {
  final DateTime day;
  final int code;
  final double minC;
  final double maxC;
  final double? rainMm;

  const DayForecast({
    required this.day,
    required this.code,
    required this.minC,
    required this.maxC,
    this.rainMm,
  });

  factory DayForecast.fromJson(Map<String, dynamic> j) => DayForecast(
        day: _dt(j['day'])!,
        code: (j['code'] as num).toInt(),
        minC: (j['minC'] as num).toDouble(),
        maxC: (j['maxC'] as num).toDouble(),
        rainMm: (j['rainMm'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'day': day.toIso8601String(),
        'code': code,
        'minC': minC,
        'maxC': maxC,
        'rainMm': rainMm,
      };
}

class AirQuality {
  final int usAqi;
  final double? pm25;
  final DateTime observedAt;

  const AirQuality({
    required this.usAqi,
    required this.observedAt,
    this.pm25,
  });

  factory AirQuality.fromJson(Map<String, dynamic> j) => AirQuality(
        usAqi: (j['usAqi'] as num).toInt(),
        pm25: (j['pm25'] as num?)?.toDouble(),
        observedAt: _dt(j['observedAt']) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'usAqi': usAqi,
        'pm25': pm25,
        'observedAt': observedAt.toIso8601String(),
      };
}

class PrayerTime {
  final String name;
  final DateTime at;

  const PrayerTime(this.name, this.at);

  factory PrayerTime.fromJson(Map<String, dynamic> j) =>
      PrayerTime(j['name'] as String, _dt(j['at'])!);

  Map<String, dynamic> toJson() => {'name': name, 'at': at.toIso8601String()};
}

class PrayerDay {
  final DateTime date;
  final String zone;
  final List<PrayerTime> times;

  const PrayerDay({required this.date, required this.zone, required this.times});

  factory PrayerDay.fromJson(Map<String, dynamic> j) => PrayerDay(
        date: _dt(j['date'])!,
        zone: j['zone'] as String,
        times: (j['times'] as List)
            .map((e) => PrayerTime.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'zone': zone,
        'times': times.map((e) => e.toJson()).toList(),
      };

  /// The next prayer strictly after [now], rolling to tomorrow's Fajr when the
  /// day's list is exhausted. Returns null only for an empty schedule.
  PrayerTime? next(DateTime now) {
    for (final t in times) {
      if (t.at.isAfter(now)) return t;
    }
    return null;
  }

  PrayerTime? current(DateTime now) {
    PrayerTime? cur;
    for (final t in times) {
      if (!t.at.isAfter(now)) cur = t;
    }
    return cur;
  }
}

class FuelPrices {
  final double? ron95;
  final double? ron97;
  final double? diesel;
  final DateTime effectiveFrom;

  const FuelPrices({
    required this.effectiveFrom,
    this.ron95,
    this.ron97,
    this.diesel,
  });

  factory FuelPrices.fromJson(Map<String, dynamic> j) => FuelPrices(
        ron95: (j['ron95'] as num?)?.toDouble(),
        ron97: (j['ron97'] as num?)?.toDouble(),
        diesel: (j['diesel'] as num?)?.toDouble(),
        effectiveFrom: _dt(j['effectiveFrom'])!,
      );

  Map<String, dynamic> toJson() => {
        'ron95': ron95,
        'ron97': ron97,
        'diesel': diesel,
        'effectiveFrom': effectiveFrom.toIso8601String(),
      };
}

class FxRate {
  final String code;
  final double myr;
  const FxRate(this.code, this.myr);

  factory FxRate.fromJson(Map<String, dynamic> j) =>
      FxRate(j['code'] as String, (j['myr'] as num).toDouble());

  Map<String, dynamic> toJson() => {'code': code, 'myr': myr};
}

class Alert {
  final String title;
  final String? body;
  final String? severity;
  final DateTime? at;
  final String source;

  const Alert({
    required this.title,
    required this.source,
    this.body,
    this.severity,
    this.at,
  });

  factory Alert.fromJson(Map<String, dynamic> j) => Alert(
        title: j['title'] as String,
        body: j['body'] as String?,
        severity: j['severity'] as String?,
        at: _dt(j['at']),
        source: j['source'] as String,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'severity': severity,
        'at': at?.toIso8601String(),
        'source': source,
      };
}

class ChecklistItem {
  final String id;
  final String text;
  final bool done;

  const ChecklistItem({required this.id, required this.text, this.done = false});

  ChecklistItem copyWith({String? text, bool? done}) =>
      ChecklistItem(id: id, text: text ?? this.text, done: done ?? this.done);

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
        id: j['id'] as String,
        text: j['text'] as String,
        done: j['done'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'done': done};
}

class Note {
  final String id;
  final String text;
  final DateTime updatedAt;

  const Note({required this.id, required this.text, required this.updatedAt});

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        text: j['text'] as String,
        updatedAt: _dt(j['updatedAt']) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class TransitVehicle {
  final String id;
  final String route;
  final double lat;
  final double lng;
  const TransitVehicle({
    required this.id,
    required this.route,
    required this.lat,
    required this.lng,
  });

  factory TransitVehicle.fromJson(Map<String, dynamic> j) => TransitVehicle(
        id: j['id'] as String,
        route: j['route'] as String? ?? '',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'route': route, 'lat': lat, 'lng': lng};
}

class Place {
  final String name;
  final String? kind;
  final double lat;
  final double lng;
  final double? distanceM;
  const Place({
    required this.name,
    required this.lat,
    required this.lng,
    this.kind,
    this.distanceM,
  });

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        name: j['name'] as String,
        kind: j['kind'] as String?,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        distanceM: (j['distanceM'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind,
        'lat': lat,
        'lng': lng,
        'distanceM': distanceM,
      };
}

class EvCharger {
  final String name;
  final double lat;
  final double lng;
  final int? maxKw;
  final String? status;
  const EvCharger({
    required this.name,
    required this.lat,
    required this.lng,
    this.maxKw,
    this.status,
  });

  factory EvCharger.fromJson(Map<String, dynamic> j) => EvCharger(
        name: j['name'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        maxKw: (j['maxKw'] as num?)?.toInt(),
        status: j['status'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': lat,
        'lng': lng,
        'maxKw': maxKw,
        'status': status,
      };
}

class LyricsLine {
  final Duration at;
  final String text;
  const LyricsLine(this.at, this.text);

  factory LyricsLine.fromJson(Map<String, dynamic> j) =>
      LyricsLine(Duration(milliseconds: (j['ms'] as num).toInt()), j['text'] as String);

  Map<String, dynamic> toJson() =>
      {'ms': at.inMilliseconds, 'text': text};
}

class Lyrics {
  final String? track;
  final String? artist;
  final bool synced;
  final List<LyricsLine> lines;
  const Lyrics({
    required this.lines,
    this.track,
    this.artist,
    this.synced = false,
  });

  factory Lyrics.fromJson(Map<String, dynamic> j) => Lyrics(
        track: j['track'] as String?,
        artist: j['artist'] as String?,
        synced: j['synced'] as bool? ?? false,
        lines: (j['lines'] as List)
            .map((e) => LyricsLine.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        'track': track,
        'artist': artist,
        'synced': synced,
        'lines': lines.map((e) => e.toJson()).toList(),
      };
}

class RadioStation {
  final String id;
  final String name;
  final String url;
  final String? favicon;
  const RadioStation({
    required this.id,
    required this.name,
    required this.url,
    this.favicon,
  });

  factory RadioStation.fromJson(Map<String, dynamic> j) => RadioStation(
        id: j['id'] as String,
        name: j['name'] as String,
        url: j['url'] as String,
        favicon: j['favicon'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'url': url, 'favicon': favicon};
}

class SportEvent {
  final String league;
  final String home;
  final String away;
  final String? homeScore;
  final String? awayScore;
  final DateTime? kickoff;
  final String status;
  const SportEvent({
    required this.league,
    required this.home,
    required this.away,
    required this.status,
    this.homeScore,
    this.awayScore,
    this.kickoff,
  });

  factory SportEvent.fromJson(Map<String, dynamic> j) => SportEvent(
        league: j['league'] as String,
        home: j['home'] as String,
        away: j['away'] as String,
        homeScore: j['homeScore']?.toString(),
        awayScore: j['awayScore']?.toString(),
        kickoff: _dt(j['kickoff']),
        status: j['status'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'league': league,
        'home': home,
        'away': away,
        'homeScore': homeScore,
        'awayScore': awayScore,
        'kickoff': kickoff?.toIso8601String(),
        'status': status,
      };
}

class Shortcut {
  final String id;
  final String label;
  final String? package;
  final String? uri;
  const Shortcut({required this.id, required this.label, this.package, this.uri});

  factory Shortcut.fromJson(Map<String, dynamic> j) => Shortcut(
        id: j['id'] as String,
        label: j['label'] as String,
        package: j['package'] as String?,
        uri: j['uri'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'label': label, 'package': package, 'uri': uri};
}

DateTime? _dt(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
