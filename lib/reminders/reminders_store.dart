import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import '../notify/actions.dart';
import '../notify/notifications.dart';
import '../notify/planner.dart';
import '../settings/settings.dart';
import 'recurrence.dart';
import 'reminder.dart';
import 'repo.dart';

/// Agrupa pedidos de replanejamento feitos em sequência (ex.: vários toques).
class Replanner {
  static Timer? _t;

  static void request() {
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 1200), Planner.replan);
  }
}

class Occurrence {
  final Reminder reminder;
  final DateTime at;

  const Occurrence(this.reminder, this.at);
}

class RemindersStore extends ChangeNotifier {
  final SettingsStore settings;
  List<Reminder> items = [];

  RemindersStore(this.settings);

  Future<void> load() async {
    items = await Repo.reminders();
    notifyListeners();
  }

  Future<void> _save() async {
    notifyListeners();
    await Repo.saveReminders(items);
    Replanner.request();
  }

  Future<Reminder> add({
    required String title,
    required Recurrence rec,
    Category category = Category.pessoal,
    bool alarm = false,
    int insistEveryMin = 0,
    int insistMax = 0,
    String notes = '',
  }) async {
    final r = Reminder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nid: await settings.takeNid(),
      title: title.isEmpty ? 'Lembrete' : title,
      notes: notes,
      category: category,
      rec: rec,
      alarm: alarm,
      insistEveryMin: insistEveryMin,
      insistMax: insistMax,
      createdAt: DateTime.now(),
    );
    items.add(r);
    await _save();
    return r;
  }

  Future<void> save(Reminder r) async {
    final i = items.indexWhere((e) => e.id == r.id);
    if (i < 0) {
      items.add(r);
    } else {
      items[i] = r;
    }
    await _save();
  }

  Future<void> remove(Reminder r) async {
    items.removeWhere((e) => e.id == r.id);
    await Notifications.cancelShown(r.nid);
    await _save();
  }

  Future<void> done(Reminder r, {DateTime? occurrence}) async {
    NotificationActions.applyDone(r, occurrence: occurrence);
    await Notifications.cancelShown(r.nid);
    await _save();
  }

  Future<void> snooze(Reminder r, Duration d) async {
    final now = DateTime.now();
    r.snoozeUntil = now.add(d);
    if (r.rec.kind != RecKind.afterCompletion && r.rec.kind != RecKind.once) {
      if (r.doneUntil == null || now.isAfter(r.doneUntil!)) r.doneUntil = now;
    }
    await Notifications.cancelShown(r.nid);
    await _save();
  }

  Reminder? byId(String? id) => items.where((e) => e.id == id).firstOrNull;

  EngineContext ctx(Reminder r) => Planner.contextFor(r, items, settings.value);

  DateTime? next(Reminder r, {DateTime? after}) {
    if (!r.enabled) return null;
    final now = after ?? DateTime.now();
    final n = nextOccurrence(r.rec, now, ctx(r));
    final s = r.snoozeUntil;
    if (s != null && s.isAfter(now) && (n == null || s.isBefore(n))) return s;
    return n;
  }

  /// Próximas ocorrências na janela (padrão 36 h).
  List<Occurrence> upcoming({Duration window = const Duration(hours: 36)}) {
    final now = DateTime.now();
    final out = <Occurrence>[];
    for (final r in items) {
      if (!r.enabled) continue;
      for (final t in occurrencesBetween(r.rec, now, now.add(window), ctx(r), limit: 6)) {
        out.add(Occurrence(r, t));
      }
      final s = r.snoozeUntil;
      if (s != null && s.isAfter(now) && s.isBefore(now.add(window))) out.add(Occurrence(r, s));
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  /// Ocorrências das últimas 24 h ainda não concluídas.
  List<Occurrence> pending() {
    final now = DateTime.now();
    final out = <Occurrence>[];
    for (final r in items) {
      if (!r.enabled) continue;
      if (r.snoozeUntil != null && r.snoozeUntil!.isAfter(now)) continue;
      if (!r.rec.isTimeBased) {
        final t = r.lastTriggered;
        if (t != null &&
            now.difference(t).inHours < 24 &&
            (r.lastCompleted == null || r.lastCompleted!.isBefore(t))) {
          out.add(Occurrence(r, t));
        }
        continue;
      }
      final past = occurrencesBetween(r.rec, now.subtract(const Duration(hours: 24)), now, ctx(r));
      if (past.isNotEmpty) out.add(Occurrence(r, past.last));
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }
}
