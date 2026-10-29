import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';

import '../core/format.dart';
import '../info/info_store.dart';
import '../info/quotes.dart';
import '../info/weather.dart';
import '../news/news_store.dart';
import '../notify/notifications.dart';
import '../notify/planner.dart';
import '../reminders/recurrence.dart';
import '../reminders/reminder.dart';
import '../reminders/repo.dart';
import '../settings/settings.dart';

const bgTaskName = 'universal-bg';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Notifications.init(background: true);
      await BackgroundJobs.run();
    } catch (_) {}
    return true;
  });
}

class BackgroundJobs {
  static Future<void> register() async {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      bgTaskName,
      bgTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  /// Condições externas, lugares, alertas de notícias e replanejamento.
  static Future<void> run() async {
    final s = await Settings.load();
    try {
      await checkTriggers(s);
    } catch (_) {}
    try {
      await NewsService.checkKeywordAlerts(s);
    } catch (_) {}
    await Planner.replan();
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  static Future<void> _fire(Reminder r, String body) async {
    r.lastTriggered = DateTime.now();
    await Notifications.show(
      id: r.nid * 100 + 99,
      title: r.title,
      body: body,
      details: Notifications.reminderDetails(r.category, alarm: r.alarm, body: body),
      payload: Payload('r', id: r.id, occurrence: r.lastTriggered, alarm: r.alarm, title: r.title),
    );
  }

  static Future<void> checkTriggers(Settings s) async {
    final list = await Repo.reminders();
    final now = DateTime.now();
    final conds = list.where((r) => r.enabled && r.rec.kind == RecKind.condition).toList();
    final places = list.where((r) => r.enabled && r.rec.kind == RecKind.location).toList();
    if (conds.isEmpty && places.isEmpty) return;
    var changed = false;

    // Condições: no máximo 1 aviso por dia.
    final due = conds.where((r) => r.lastTriggered == null || !_sameDay(r.lastTriggered!, now)).toList();
    if (due.isNotEmpty) {
      Weather? w;
      Quotes? q;
      final needWeather = due.any((r) => r.rec.condition!.index <= ConditionType.tempBelow.index);
      final needQuotes = due.any((r) => r.rec.condition!.index > ConditionType.tempBelow.index);
      if (needWeather) {
        double? lat = s.lat, lon = s.lon;
        if (s.useGps || lat == null) {
          final p = await currentPosition();
          if (p != null) {
            lat = p.latitude;
            lon = p.longitude;
          }
        }
        if (lat != null && lon != null) {
          try {
            w = await Weather.fetch(lat, lon);
          } catch (_) {}
        }
      }
      if (needQuotes) {
        try {
          q = await Quotes.fetch();
        } catch (_) {}
      }
      for (final r in due) {
        final c = r.rec.condition!;
        final t = r.rec.threshold;
        String? body;
        switch (c) {
          case ConditionType.rainToday:
            if (w != null && w.rainToday >= t) body = 'Chance de chuva hoje: ${w.rainToday}%';
          case ConditionType.rainTomorrow:
            if (w != null && w.rainTomorrow >= t) body = 'Chance de chuva amanhã: ${w.rainTomorrow}%';
          case ConditionType.tempAbove:
            if (w != null && w.temp > t) body = 'Temperatura agora: ${w.temp.toStringAsFixed(0)} °C';
          case ConditionType.tempBelow:
            if (w != null && w.temp < t) body = 'Temperatura agora: ${w.temp.toStringAsFixed(0)} °C';
          case ConditionType.usdAbove:
            if (q?.usd != null && q!.usd! > t) body = 'Dólar: ${money(q.usd!)}';
          case ConditionType.usdBelow:
            if (q?.usd != null && q!.usd! < t) body = 'Dólar: ${money(q.usd!)}';
          case ConditionType.eurAbove:
            if (q?.eur != null && q!.eur! > t) body = 'Euro: ${money(q.eur!)}';
          case ConditionType.eurBelow:
            if (q?.eur != null && q!.eur! < t) body = 'Euro: ${money(q.eur!)}';
          case ConditionType.btcAbove:
            if (q?.btc != null && q!.btc! > t) body = 'Bitcoin: ${money(q.btc!)}';
          case ConditionType.btcBelow:
            if (q?.btc != null && q!.btc! < t) body = 'Bitcoin: ${money(q.btc!)}';
        }
        if (body != null) {
          await _fire(r, body);
          changed = true;
        }
      }
    }

    // Lugares: exige permissão "permitir o tempo todo".
    if (places.isNotEmpty) {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final p = await currentPosition();
        if (p != null) {
          for (final r in places) {
            if (r.rec.lat == null || r.rec.lon == null) continue;
            final d = Geolocator.distanceBetween(p.latitude, p.longitude, r.rec.lat!, r.rec.lon!);
            final inside = d <= r.rec.radiusM;
            final before = r.inside;
            r.inside = inside;
            changed = true;
            if (before != null && before != inside && inside == r.rec.onEnter) {
              await _fire(r, '${r.rec.onEnter ? 'Você chegou' : 'Você saiu'}: ${r.rec.placeName ?? 'local'}');
            }
          }
        }
      }
    }

    if (changed) await Repo.saveReminders(list);
  }
}
