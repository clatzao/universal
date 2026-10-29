import 'dart:async';

import '../core/format.dart';
import '../curiosities/facts.dart';
import '../habits/habit.dart';
import '../reminders/recurrence.dart';
import '../reminders/reminder.dart';
import '../reminders/repo.dart';
import '../settings/settings.dart';
import 'notifications.dart';

/// Um alarme a agendar.
class PlannedAlarm {
  final int id;
  final DateTime at;
  final String title;
  final String? body;
  final Payload payload;
  final Reminder? reminder;
  final Habit? habit;

  const PlannedAlarm(this.id, this.at, this.title, this.body, this.payload, {this.reminder, this.habit});
}

/// O Android limita ~500 alarmes por app: agenda só os próximos 14 dias,
/// no máximo 12 por lembrete, com IDs nid*100+slot.
class Planner {
  static const horizonDays = 14;
  static const perItem = 12;
  static const globalMax = 450;

  static Future<void>? _running;

  static Future<void> replan() async {
    // Evita duas execuções simultâneas no mesmo isolate.
    while (_running != null) {
      await _running;
    }
    final c = Completer<void>();
    _running = c.future;
    try {
      await _replan();
    } catch (_) {
    } finally {
      _running = null;
      c.complete();
    }
  }

  static EngineContext contextFor(Reminder r, List<Reminder> all, Settings s) {
    DateTime? chainSrc;
    if (r.rec.kind == RecKind.chain && r.rec.chainFrom != null) {
      chainSrc = all.where((e) => e.id == r.rec.chainFrom).firstOrNull?.lastCompleted;
    }
    return EngineContext(
      holidays: s.calendar,
      createdAt: r.createdAt,
      lastCompleted: r.lastCompleted,
      doneUntil: r.doneUntil,
      chainSourceCompleted: chainSrc,
    );
  }

  /// Calcula os alarmes desejados (função pura, testável).
  static List<PlannedAlarm> compute(List<Reminder> reminders, List<Habit> habits, Settings s, DateTime now) {
    final horizon = now.add(const Duration(days: horizonDays));
    final out = <PlannedAlarm>[];

    for (final r in reminders) {
      if (!r.enabled) continue;
      final items = <PlannedAlarm>[];
      var slot = 0;
      void add(DateTime at, DateTime occ) {
        if (items.length >= perItem || slot >= 100) return;
        items.add(PlannedAlarm(
          r.nid * 100 + slot++,
          at,
          r.title.isEmpty ? 'Lembrete' : r.title,
          r.notes.isEmpty ? describeRecurrence(r.rec) : r.notes,
          Payload('r', id: r.id, occurrence: occ, alarm: r.alarm, title: r.title),
          reminder: r,
        ));
      }

      if (r.snoozeUntil != null && r.snoozeUntil!.isAfter(now)) add(r.snoozeUntil!, r.snoozeUntil!);
      if (r.rec.isTimeBased) {
        final occs = occurrencesBetween(r.rec, now, horizon, contextFor(r, reminders, s), limit: perItem);
        for (var i = 0; i < occs.length; i++) {
          final occ = occs[i];
          add(occ, occ);
          if (r.insistEveryMin > 0 && r.insistMax > 0) {
            final nextOcc = i + 1 < occs.length ? occs[i + 1] : horizon;
            for (var k = 1; k <= r.insistMax; k++) {
              final t = occ.add(Duration(minutes: r.insistEveryMin * k));
              if (!t.isBefore(nextOcc) || t.isAfter(horizon)) break;
              add(t, occ);
            }
          }
        }
        // Insistência de uma ocorrência que já passou e ainda não foi concluída.
        if (r.insistEveryMin > 0 && r.insistMax > 0) {
          final past = occurrencesBetween(
              r.rec, now.subtract(Duration(minutes: r.insistEveryMin * r.insistMax)), now, contextFor(r, reminders, s));
          if (past.isNotEmpty) {
            final occ = past.last;
            for (var k = 1; k <= r.insistMax; k++) {
              final t = occ.add(Duration(minutes: r.insistEveryMin * k));
              if (t.isAfter(now)) add(t, occ);
            }
          }
        }
      }
      out.addAll(items);
    }

    final today = dayOf(now);
    for (final h in habits) {
      final rec = h.recurrence;
      if (rec == null) continue;
      final ctx = EngineContext(createdAt: today, holidays: s.calendar);
      final occs = occurrencesBetween(rec, now, horizon, ctx, limit: 200);
      var slot = 0;
      final metToday = h.metOn(today);
      for (final t in occs) {
        if (slot >= perItem) break;
        // O lembrete do hábito PARA no dia em que a meta for batida.
        if (metToday && dayOf(t) == today) continue;
        out.add(PlannedAlarm(
          h.nid * 100 + slot++,
          t,
          h.name,
          'Hoje: ${h.fmt(h.amountOn(dayOf(t)))} de ${h.fmt(h.goal)} ${h.unit}',
          Payload('h', id: h.id, occurrence: t),
          habit: h,
        ));
      }
    }

    if (s.factNotify) {
      for (var i = 0; i <= horizonDays && i < 100; i++) {
        final day = DateTime(today.year, today.month, today.day + i);
        final at = s.factTime.on(day);
        if (!at.isAfter(now)) continue;
        final f = factOfDay(day);
        out.add(PlannedAlarm(nidFact * 100 + i, at, 'Curiosidade do dia · ${f.category.label}', f.text,
            Payload('f', id: '${f.id}')));
      }
    }

    out.sort((a, b) => a.at.compareTo(b.at));
    return out.length > globalMax ? out.sublist(0, globalMax) : out;
  }

  static Future<void> _replan() async {
    final s = await Settings.load();
    final reminders = await Repo.reminders();
    final habits = await Repo.habits();
    final desired = compute(reminders, habits, s, DateTime.now());
    final ids = desired.map((e) => e.id).toSet();

    final pending = await Notifications.plugin.pendingNotificationRequests();
    const keep = {nidTest, nidNews, nidTrigger};
    for (final p in pending) {
      if (!ids.contains(p.id) && !keep.contains(p.id ~/ 100)) await Notifications.plugin.cancel(id: p.id);
    }
    for (final a in desired) {
      try {
        if (a.reminder != null) {
          final r = a.reminder!;
          await Notifications.schedule(
            id: a.id,
            at: a.at,
            title: a.title,
            body: a.body,
            details: Notifications.reminderDetails(r.category, alarm: r.alarm, body: a.body),
            payload: a.payload,
            alarmClock: r.alarm,
          );
        } else if (a.habit != null) {
          final h = a.habit!;
          final q = h.quick.isEmpty ? 1.0 : h.quick.first;
          await Notifications.schedule(
            id: a.id,
            at: a.at,
            title: a.title,
            body: a.body,
            details: Notifications.habitDetails('+${h.fmt(q)} ${h.unit}'),
            payload: a.payload,
          );
        } else {
          await Notifications.schedule(
            id: a.id,
            at: a.at,
            title: a.title,
            body: a.body,
            details: Notifications.generalDetails(body: a.body),
            payload: a.payload,
          );
        }
      } catch (_) {}
    }
  }
}
