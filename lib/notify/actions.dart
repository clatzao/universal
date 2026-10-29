import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/format.dart';
import '../reminders/recurrence.dart';
import '../reminders/reminder.dart';
import '../reminders/repo.dart';
import 'notifications.dart';
import 'planner.dart';

/// Ações sobre lembretes que funcionam tanto no app quanto em segundo plano
/// (botões da notificação com o app fechado).
class NotificationActions {
  /// O app aberto recarrega os dados quando algo muda por aqui.
  static Future<void> Function()? onChanged;

  static Future<void> handle(NotificationResponse r, {bool background = false}) async {
    final p = Payload.decode(r.payload);
    if (p == null || p.id == null) return;
    switch (r.actionId) {
      case actDone:
        if (p.kind == 'r') await markDone(p.id!, occurrence: p.occurrence);
        break;
      case actSnooze10:
        if (p.kind == 'r') await snooze(p.id!, const Duration(minutes: 10));
        break;
      case actSnooze60:
        if (p.kind == 'r') await snooze(p.id!, const Duration(hours: 1));
        break;
      case actHabitAdd:
        if (p.kind == 'h') await habitQuickAdd(p.id!);
        break;
      default:
        return;
    }
    await onChanged?.call();
  }

  static void _applyDone(Reminder r, DateTime now, DateTime? occurrence) {
    r.lastCompleted = now;
    final until = occurrence != null && occurrence.isAfter(now) ? occurrence : now;
    if (r.doneUntil == null || until.isAfter(r.doneUntil!)) r.doneUntil = until;
    r.snoozeUntil = null;
    if (r.rec.kind == RecKind.once) r.enabled = false;
  }

  static Future<void> markDone(String id, {DateTime? occurrence}) async {
    final list = await Repo.reminders();
    final r = list.where((e) => e.id == id).firstOrNull;
    if (r == null) return;
    _applyDone(r, DateTime.now(), occurrence);
    await Repo.saveReminders(list);
    await Notifications.cancelShown(r.nid);
    await Planner.replan();
  }

  static Future<void> snooze(String id, Duration d) async {
    final list = await Repo.reminders();
    final r = list.where((e) => e.id == id).firstOrNull;
    if (r == null) return;
    final now = DateTime.now();
    r.snoozeUntil = now.add(d);
    // A ocorrência adiada não deve insistir de novo.
    if (r.rec.kind != RecKind.afterCompletion && r.rec.kind != RecKind.once) {
      if (r.doneUntil == null || now.isAfter(r.doneUntil!)) r.doneUntil = now;
    }
    await Repo.saveReminders(list);
    await Notifications.cancelShown(r.nid);
    await Planner.replan();
  }

  static Future<void> habitQuickAdd(String id) async {
    final list = await Repo.habits();
    final h = list.where((e) => e.id == id).firstOrNull;
    if (h == null) return;
    final k = dayKey(DateTime.now());
    h.log[k] = (h.log[k] ?? 0) + (h.quick.isEmpty ? 1 : h.quick.first);
    await Repo.saveHabits(list);
    await Planner.replan();
  }

  /// Usado pelo app aberto (mesma regra do botão da notificação).
  static void applyDone(Reminder r, {DateTime? occurrence}) => _applyDone(r, DateTime.now(), occurrence);
}
