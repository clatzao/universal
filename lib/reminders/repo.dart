import '../core/json_store.dart';
import '../habits/habit.dart';
import 'reminder.dart';

/// Leitura/escrita direta dos arquivos (usada também em segundo plano).
class Repo {
  static Future<List<Reminder>> reminders() async {
    final j = await JsonStore.read('reminders');
    if (j is! List) return [];
    final out = <Reminder>[];
    for (final e in j) {
      try {
        out.add(Reminder.fromJson((e as Map).cast<String, dynamic>()));
      } catch (_) {}
    }
    return out;
  }

  static Future<void> saveReminders(List<Reminder> list) =>
      JsonStore.write('reminders', list.map((r) => r.toJson()).toList());

  static Future<List<Habit>> habits() async {
    final j = await JsonStore.read('habits');
    if (j is! List) return [];
    final out = <Habit>[];
    for (final e in j) {
      try {
        out.add(Habit.fromJson((e as Map).cast<String, dynamic>()));
      } catch (_) {}
    }
    return out;
  }

  static Future<void> saveHabits(List<Habit> list) => JsonStore.write('habits', list.map((h) => h.toJson()).toList());
}
