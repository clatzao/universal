import 'package:flutter_test/flutter_test.dart';
import 'package:universal/core/format.dart';
import 'package:universal/habits/habit.dart';
import 'package:universal/notify/planner.dart';
import 'package:universal/reminders/recurrence.dart';
import 'package:universal/reminders/reminder.dart';
import 'package:universal/settings/settings.dart';
import 'package:universal/update/updater.dart';

void main() {
  final now = DateTime(2026, 10, 29, 10, 0);
  final s = Settings(factNotify: false);

  Reminder rem(Recurrence rec, {int nid = 10, int insistEvery = 0, int insistMax = 0}) => Reminder(
        id: 'r$nid',
        nid: nid,
        title: 'Teste',
        rec: rec,
        createdAt: DateTime(2026, 1, 1),
        insistEveryMin: insistEvery,
        insistMax: insistMax,
      );

  test('máximo de 12 alarmes por lembrete, IDs nid*100+slot', () {
    final r = rem(const Recurrence(kind: RecKind.weekly, times: [HM(8, 0), HM(20, 0)]));
    final list = Planner.compute([r], [], s, now);
    expect(list.length, 12);
    expect(list.map((a) => a.id).toSet(), {for (var i = 0; i < 12; i++) 1000 + i});
    expect(list.first.at, DateTime(2026, 10, 29, 20, 0));
  });

  test('só os próximos 14 dias', () {
    final r = rem(const Recurrence(kind: RecKind.monthlyDay, monthDay: 5, times: [HM(9, 0)]));
    expect(Planner.compute([r], [], s, now).single.at, DateTime(2026, 11, 5, 9));
    final far = rem(const Recurrence(kind: RecKind.yearly, day: 25, month: 12));
    expect(Planner.compute([far], [], s, now), isEmpty);
  });

  test('insistência até N vezes', () {
    final r = rem(Recurrence(kind: RecKind.once, at: DateTime(2026, 10, 29, 11)), insistEvery: 5, insistMax: 3);
    final list = Planner.compute([r], [], s, now);
    expect(list.map((a) => hm(a.at)), ['11:00', '11:05', '11:10', '11:15']);
  });

  test('adiado gera alarme no horário do adiamento', () {
    final r = rem(Recurrence(kind: RecKind.once, at: DateTime(2026, 10, 29, 9)))
      ..snoozeUntil = DateTime(2026, 10, 29, 10, 10);
    expect(Planner.compute([r], [], s, now).single.at, DateTime(2026, 10, 29, 10, 10));
  });

  test('lembrete do hábito para no dia em que a meta é batida', () {
    final h = Habit.preset(HabitType.agua, 'h', 20)
      ..everyMin = 120
      ..windowStart = const HM(8, 0)
      ..windowEnd = const HM(18, 0);
    var list = Planner.compute([], [h], s, now);
    expect(list.first.at, DateTime(2026, 10, 29, 12));
    h.log[dayKey(now)] = 2000;
    list = Planner.compute([], [h], s, now);
    expect(list.first.at, DateTime(2026, 10, 30, 8));
  });

  test('curiosidade do dia agendada no horário configurado', () {
    final list = Planner.compute([], [], Settings(factTime: const HM(9, 0)), now);
    expect(list.first.at, DateTime(2026, 10, 30, 9));
    expect(list.first.id ~/ 100, 1);
  });

  test('número da tag da release', () {
    expect(buildFromTag('v1.0.42'), 42);
    expect(buildFromTag('v1.0.7 '), 7);
    expect(buildFromTag('sem-numero'), isNull);
  });
}
