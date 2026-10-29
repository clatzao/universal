import 'package:flutter/foundation.dart';

import '../core/format.dart';
import '../reminders/reminders_store.dart';
import '../reminders/repo.dart';
import '../settings/settings.dart';
import 'habit.dart';

class HabitsStore extends ChangeNotifier {
  final SettingsStore settings;
  List<Habit> items = [];

  /// Pilha de adições para "desfazer": (hábito, dia, valor).
  final List<(String, String, double)> _undo = [];

  HabitsStore(this.settings);

  Future<void> load() async {
    items = await Repo.habits();
    notifyListeners();
  }

  Future<void> _save() async {
    notifyListeners();
    await Repo.saveHabits(items);
    Replanner.request();
  }

  Future<Habit> create(HabitType t) async {
    final h = Habit.preset(t, DateTime.now().microsecondsSinceEpoch.toString(), await settings.takeNid());
    items.add(h);
    await _save();
    return h;
  }

  Future<void> save(Habit h) async {
    final i = items.indexWhere((e) => e.id == h.id);
    if (i < 0) {
      items.add(h);
    } else {
      items[i] = h;
    }
    await _save();
  }

  Future<void> remove(Habit h) async {
    items.removeWhere((e) => e.id == h.id);
    await _save();
  }

  Future<void> add(Habit h, double v) async {
    final k = dayKey(DateTime.now());
    h.log[k] = (h.log[k] ?? 0) + v;
    _undo.add((h.id, k, v));
    await _save();
  }

  bool get canUndo => _undo.isNotEmpty;

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    final (id, k, v) = _undo.removeLast();
    final h = items.where((e) => e.id == id).firstOrNull;
    if (h == null) return;
    final nv = (h.log[k] ?? 0) - v;
    if (nv <= 0) {
      h.log.remove(k);
    } else {
      h.log[k] = nv;
    }
    await _save();
  }

  /// Ajuste manual de um dia (inclusive anteriores).
  Future<void> setDay(Habit h, DateTime day, double v) async {
    final k = dayKey(day);
    if (v <= 0) {
      h.log.remove(k);
    } else {
      h.log[k] = v;
    }
    await _save();
  }
}
