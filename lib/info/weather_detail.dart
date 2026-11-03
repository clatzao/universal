import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/net.dart';
import '../core/theme.dart';
import '../settings/settings.dart';
import 'info_store.dart';
import 'weather.dart';

class HourForecast {
  final DateTime time;
  final double temp;
  final int rain;
  final int code;

  const HourForecast(this.time, this.temp, this.rain, this.code);
}

class DayForecast {
  final DateTime date;
  final double max;
  final double min;
  final int rain;
  final int code;
  final DateTime? sunrise;
  final DateTime? sunset;
  final double uv;

  const DayForecast(this.date, this.max, this.min, this.rain, this.code, this.sunrise, this.sunset, this.uv);
}

class WeatherDetail {
  final double temp;
  final double feelsLike;
  final int humidity;
  final double wind;
  final int windDirection;
  final double pressure;
  final double precipitation;
  final double uv;
  final int code;
  final List<HourForecast> hours;
  final List<DayForecast> days;

  const WeatherDetail({
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.wind,
    required this.windDirection,
    required this.pressure,
    required this.precipitation,
    required this.uv,
    required this.code,
    required this.hours,
    required this.days,
  });

  /// [now] limita a previsão por hora às próximas 24 horas.
  factory WeatherDetail.fromJson(Map<String, dynamic> j, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final cur = j['current'] as Map<String, dynamic>;
    final hourly = j['hourly'] as Map<String, dynamic>;
    final daily = j['daily'] as Map<String, dynamic>;
    double n(dynamic v) => (v as num?)?.toDouble() ?? 0;
    final start = DateTime(clock.year, clock.month, clock.day, clock.hour);
    final hours = <HourForecast>[];
    final times = hourly['time'] as List;
    for (var i = 0; i < times.length && hours.length < 24; i++) {
      final t = DateTime.parse(times[i] as String);
      if (t.isBefore(start)) continue;
      hours.add(
        HourForecast(
          t,
          n((hourly['temperature_2m'] as List)[i]),
          n((hourly['precipitation_probability'] as List)[i]).toInt(),
          n((hourly['weather_code'] as List)[i]).toInt(),
        ),
      );
    }
    final dates = daily['time'] as List;
    return WeatherDetail(
      temp: n(cur['temperature_2m']),
      feelsLike: n(cur['apparent_temperature']),
      humidity: n(cur['relative_humidity_2m']).toInt(),
      wind: n(cur['wind_speed_10m']),
      windDirection: n(cur['wind_direction_10m']).toInt(),
      pressure: n(cur['surface_pressure']),
      precipitation: n(cur['precipitation']),
      uv: n(cur['uv_index']),
      code: n(cur['weather_code']).toInt(),
      hours: hours,
      days: [
        for (var i = 0; i < dates.length; i++)
          DayForecast(
            DateTime.parse(dates[i] as String),
            n((daily['temperature_2m_max'] as List)[i]),
            n((daily['temperature_2m_min'] as List)[i]),
            n((daily['precipitation_probability_max'] as List)[i]).toInt(),
            n((daily['weather_code'] as List)[i]).toInt(),
            DateTime.tryParse('${(daily['sunrise'] as List)[i]}'),
            DateTime.tryParse('${(daily['sunset'] as List)[i]}'),
            n((daily['uv_index_max'] as List)[i]),
          ),
      ],
    );
  }

  static Future<WeatherDetail> fetch(double lat, double lon) async {
    final j = await Net.json(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,wind_direction_10m,'
      'surface_pressure,precipitation,uv_index,weather_code'
      '&hourly=temperature_2m,precipitation_probability,weather_code'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset,uv_index_max'
      '&timezone=auto&forecast_days=7',
    );
    return WeatherDetail.fromJson(j as Map<String, dynamic>);
  }
}

String windDirectionLabel(int degrees) {
  const names = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
  return names[(((degrees % 360) + 22.5) ~/ 45) % 8];
}

String uvLabel(double uv) {
  if (uv < 3) return 'baixo';
  if (uv < 6) return 'moderado';
  if (uv < 8) return 'alto';
  if (uv < 11) return 'muito alto';
  return 'extremo';
}

class WeatherDetailPage extends StatefulWidget {
  const WeatherDetailPage({super.key});

  @override
  State<WeatherDetailPage> createState() => _WeatherDetailPageState();
}

class _WeatherDetailPageState extends State<WeatherDetailPage> {
  late Future<WeatherDetail> data = _load();

  Future<WeatherDetail> _load() async {
    final s = context.read<SettingsStore>().value;
    double? lat = s.lat, lon = s.lon;
    if (s.useGps) {
      final p = await currentPosition();
      if (p != null) {
        lat = p.latitude;
        lon = p.longitude;
      }
    }
    if (lat == null || lon == null) throw Exception('Sem cidade definida');
    return WeatherDetail.fetch(lat, lon);
  }

  @override
  Widget build(BuildContext context) {
    final city = context.watch<SettingsStore>().value.cityName;
    return Scaffold(
      appBar: AppBar(title: Text(city ?? 'Clima')),
      body: RefreshIndicator(
        onRefresh: () async {
          final next = _load();
          setState(() => data = next);
          await next;
        },
        child: FutureBuilder<WeatherDetail>(
          future: data,
          builder: (context, snap) {
            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.all(32),
                children: const [
                  Text(
                    'Não foi possível carregar a previsão. Puxe para baixo para tentar de novo.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return _Body(w: snap.data!);
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final WeatherDetail w;

  const _Body({required this.w});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = t.labelSmall?.copyWith(color: AppTheme.textMuted);
    final today = w.days.isNotEmpty ? w.days.first : null;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${w.temp.round()}°',
                      style: t.displayLarge?.copyWith(fontWeight: FontWeight.w200, height: 1, letterSpacing: -3),
                    ),
                    const SizedBox(height: 6),
                    Text(describeCode(w.code), style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Sensação de ${w.feelsLike.round()}°${today == null ? '' : ' · ${today.min.round()}° / ${today.max.round()}°'}',
                      style: t.bodyMedium?.copyWith(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(iconFor(w.code), size: 72, color: AppTheme.text),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
          child: Text('Próximas horas', style: t.titleMedium),
        ),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: w.hours.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final h = w.hours[i];
              return Container(
                width: 66,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.line),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(i == 0 ? 'Agora' : '${two(h.time.hour)}h', style: muted),
                    Icon(iconFor(h.code), size: 22),
                    Text('${h.temp.round()}°', style: t.titleSmall),
                    Text('${h.rain}%', style: muted),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
          child: Text('Agora', style: t.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.3,
            children: [
              _Tile(Icons.water_drop_outlined, 'Umidade', '${w.humidity}%'),
              _Tile(Icons.air, 'Vento', '${w.wind.round()} km/h ${windDirectionLabel(w.windDirection)}'),
              _Tile(Icons.wb_sunny_outlined, 'Índice UV', '${w.uv.round()} · ${uvLabel(w.uv)}'),
              _Tile(Icons.compress, 'Pressão', '${w.pressure.round()} hPa'),
              _Tile(
                Icons.umbrella_outlined,
                'Chuva agora',
                '${w.precipitation.toStringAsFixed(1).replaceAll('.', ',')} mm',
              ),
              if (today?.sunrise != null && today?.sunset != null)
                _Tile(Icons.wb_twilight, 'Sol', '${hm(today!.sunrise!)} – ${hm(today.sunset!)}'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
          child: Text('Próximos 7 dias', style: t.titleMedium),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (var i = 0; i < w.days.length; i++) ...[
                if (i > 0) const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 74,
                        child: Text(i == 0 ? 'Hoje' : (i == 1 ? 'Amanhã' : _weekday(w.days[i].date))),
                      ),
                      Icon(iconFor(w.days[i].code), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${w.days[i].rain}% chuva',
                          style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
                        ),
                      ),
                      Text('${w.days[i].min.round()}°', style: const TextStyle(color: AppTheme.textMuted)),
                      const SizedBox(width: 10),
                      Text('${w.days[i].max.round()}°', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text('Fonte: Open-Meteo.', style: muted),
        ),
      ],
    );
  }

  String _weekday(DateTime d) {
    final s = DateFormat('EEE', 'pt_BR').format(d).replaceAll('.', '');
    return '${s[0].toUpperCase()}${s.substring(1)} ${two(d.day)}';
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Tile(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.labelSmall?.copyWith(color: AppTheme.textMuted)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: t.titleSmall),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
