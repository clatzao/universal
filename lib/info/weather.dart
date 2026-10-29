import 'package:flutter/material.dart';

import '../core/net.dart';

class Weather {
  final double temp;
  final int code;
  final double maxToday;
  final double minToday;
  final int rainToday;
  final int rainTomorrow;
  final double maxTomorrow;
  final double minTomorrow;
  final DateTime fetchedAt;

  const Weather({
    required this.temp,
    required this.code,
    required this.maxToday,
    required this.minToday,
    required this.rainToday,
    required this.rainTomorrow,
    required this.maxTomorrow,
    required this.minTomorrow,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
        'temp': temp,
        'code': code,
        'maxToday': maxToday,
        'minToday': minToday,
        'rainToday': rainToday,
        'rainTomorrow': rainTomorrow,
        'maxTomorrow': maxTomorrow,
        'minTomorrow': minTomorrow,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory Weather.fromJson(Map<String, dynamic> j) => Weather(
        temp: (j['temp'] as num).toDouble(),
        code: j['code'] as int,
        maxToday: (j['maxToday'] as num).toDouble(),
        minToday: (j['minToday'] as num).toDouble(),
        rainToday: j['rainToday'] as int,
        rainTomorrow: j['rainTomorrow'] as int,
        maxTomorrow: (j['maxTomorrow'] as num).toDouble(),
        minTomorrow: (j['minTomorrow'] as num).toDouble(),
        fetchedAt: DateTime.parse(j['fetchedAt'] as String),
      );

  String get description => describeCode(code);

  IconData get icon => iconFor(code);

  static Future<Weather> fetch(double lat, double lon) async {
    final j = await Net.json('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,weather_code'
        '&daily=precipitation_probability_max,temperature_2m_max,temperature_2m_min'
        '&timezone=auto&forecast_days=2') as Map<String, dynamic>;
    final cur = j['current'] as Map<String, dynamic>;
    final daily = j['daily'] as Map<String, dynamic>;
    List<num?> d(String k) => (daily[k] as List).cast<num?>();
    final rain = d('precipitation_probability_max');
    final mx = d('temperature_2m_max');
    final mn = d('temperature_2m_min');
    return Weather(
      temp: (cur['temperature_2m'] as num).toDouble(),
      code: (cur['weather_code'] as num).toInt(),
      maxToday: (mx[0] ?? 0).toDouble(),
      minToday: (mn[0] ?? 0).toDouble(),
      rainToday: (rain[0] ?? 0).toInt(),
      rainTomorrow: (rain.length > 1 ? rain[1] ?? 0 : 0).toInt(),
      maxTomorrow: (mx.length > 1 ? mx[1] ?? 0 : 0).toDouble(),
      minTomorrow: (mn.length > 1 ? mn[1] ?? 0 : 0).toDouble(),
      fetchedAt: DateTime.now(),
    );
  }
}

class Place {
  final String name;
  final double lat;
  final double lon;

  const Place(this.name, this.lat, this.lon);
}

Future<List<Place>> searchCity(String q) async {
  final j = await Net.json(
      'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeQueryComponent(q)}&count=10&language=pt&format=json');
  final list = (j is Map ? j['results'] as List? : null) ?? const [];
  return list.map((e) {
    final m = e as Map<String, dynamic>;
    final parts = [m['name'], m['admin1'], m['country']].whereType<String>().toSet().join(', ');
    return Place(parts, (m['latitude'] as num).toDouble(), (m['longitude'] as num).toDouble());
  }).toList();
}

/// Códigos WMO usados pelo Open-Meteo.
String describeCode(int c) {
  if (c == 0) return 'Céu limpo';
  if (c <= 2) return 'Parcialmente nublado';
  if (c == 3) return 'Nublado';
  if (c == 45 || c == 48) return 'Neblina';
  if (c >= 51 && c <= 57) return 'Garoa';
  if (c >= 61 && c <= 67) return 'Chuva';
  if (c >= 71 && c <= 77) return 'Neve';
  if (c >= 80 && c <= 82) return 'Pancadas de chuva';
  if (c >= 95) return 'Tempestade';
  return 'Tempo variável';
}

IconData iconFor(int c) {
  if (c == 0) return Icons.wb_sunny;
  if (c <= 2) return Icons.wb_cloudy_outlined;
  if (c == 3) return Icons.cloud;
  if (c == 45 || c == 48) return Icons.foggy;
  if (c >= 95) return Icons.thunderstorm;
  if (c >= 71 && c <= 77) return Icons.ac_unit;
  if (c >= 51) return Icons.umbrella;
  return Icons.cloud_queue;
}
