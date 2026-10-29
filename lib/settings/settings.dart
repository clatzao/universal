import 'package:flutter/foundation.dart';

import '../core/json_store.dart';
import '../reminders/holidays.dart';
import '../reminders/recurrence.dart';

/// Configurações do app (arquivo settings.json).
class Settings {
  String? cityName;
  double? lat;
  double? lon;
  bool useGps;

  List<LocalHoliday> localHolidays;
  bool countCarnival;
  bool countCorpusChristi;

  bool factNotify;
  HM factTime;

  List<String> keywords;
  bool keywordAlerts;
  Set<String> disabledSources;

  bool autoUpdate;
  DateTime? lastUpdateCheck;

  int nextNid;

  Settings({
    this.cityName,
    this.lat,
    this.lon,
    this.useGps = false,
    this.localHolidays = const [],
    this.countCarnival = false,
    this.countCorpusChristi = false,
    this.factNotify = true,
    this.factTime = const HM(9, 0),
    this.keywords = const [],
    this.keywordAlerts = true,
    this.disabledSources = const {},
    this.autoUpdate = true,
    this.lastUpdateCheck,
    this.nextNid = 10,
  });

  HolidayCalendar get calendar =>
      HolidayCalendar(countCarnival: countCarnival, countCorpusChristi: countCorpusChristi, local: localHolidays);

  bool get hasLocation => lat != null && lon != null;

  Map<String, dynamic> toJson() => {
        'cityName': cityName,
        'lat': lat,
        'lon': lon,
        'useGps': useGps,
        'localHolidays': localHolidays.map((e) => e.toJson()).toList(),
        'countCarnival': countCarnival,
        'countCorpusChristi': countCorpusChristi,
        'factNotify': factNotify,
        'factTime': factTime.format(),
        'keywords': keywords,
        'keywordAlerts': keywordAlerts,
        'disabledSources': disabledSources.toList(),
        'autoUpdate': autoUpdate,
        'lastUpdateCheck': lastUpdateCheck?.toIso8601String(),
        'nextNid': nextNid,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        cityName: j['cityName'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        useGps: (j['useGps'] as bool?) ?? false,
        localHolidays: ((j['localHolidays'] as List?) ?? const [])
            .map((e) => LocalHoliday.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        countCarnival: (j['countCarnival'] as bool?) ?? false,
        countCorpusChristi: (j['countCorpusChristi'] as bool?) ?? false,
        factNotify: (j['factNotify'] as bool?) ?? true,
        factTime: j['factTime'] == null ? const HM(9, 0) : HM.parse(j['factTime'] as String),
        keywords: ((j['keywords'] as List?) ?? const []).cast<String>().toList(),
        keywordAlerts: (j['keywordAlerts'] as bool?) ?? true,
        disabledSources: ((j['disabledSources'] as List?) ?? const []).cast<String>().toSet(),
        autoUpdate: (j['autoUpdate'] as bool?) ?? true,
        lastUpdateCheck: j['lastUpdateCheck'] == null ? null : DateTime.parse(j['lastUpdateCheck'] as String),
        nextNid: (j['nextNid'] as int?) ?? 10,
      );

  static Future<Settings> load() async {
    final j = await JsonStore.read('settings');
    return j is Map ? Settings.fromJson(j.cast<String, dynamic>()) : Settings();
  }

  Future<void> save() => JsonStore.write('settings', toJson());
}

class SettingsStore extends ChangeNotifier {
  Settings value = Settings();

  /// Chamado depois de mudanças que afetam o agendamento.
  Future<void> Function()? onReplan;

  Future<void> load() async {
    value = await Settings.load();
    notifyListeners();
  }

  Future<void> update(void Function(Settings s) change, {bool replan = false}) async {
    change(value);
    notifyListeners();
    await value.save();
    if (replan) await onReplan?.call();
  }

  /// Reserva um novo identificador de notificação.
  Future<int> takeNid() async {
    final n = value.nextNid;
    value.nextNid = n + 1;
    await value.save();
    return n;
  }
}
