import 'package:flutter_test/flutter_test.dart';
import 'package:universal/reminders/holidays.dart';
import 'package:universal/reminders/recurrence.dart';

void main() {
  final created = DateTime(2026, 1, 1, 8);
  final ctx = EngineContext(createdAt: created);

  group('feriados', () {
    test('Páscoa', () {
      expect(easterSunday(2024), DateTime(2024, 3, 31));
      expect(easterSunday(2025), DateTime(2025, 4, 20));
      expect(easterSunday(2026), DateTime(2026, 4, 5));
      expect(easterSunday(2027), DateTime(2027, 3, 28));
    });

    test('móveis de 2026', () {
      final names = {for (final h in nationalHolidays(2026)) '${h.date.month}/${h.date.day}': h.name};
      expect(names['2/16'], 'Carnaval');
      expect(names['2/17'], 'Carnaval');
      expect(names['4/3'], 'Sexta-feira Santa');
      expect(names['6/4'], 'Corpus Christi');
    });

    test('Consciência Negra só a partir de 2024', () {
      expect(const HolidayCalendar().isHoliday(DateTime(2023, 11, 20)), isFalse);
      expect(const HolidayCalendar().isHoliday(DateTime(2024, 11, 20)), isTrue);
    });

    test('pontos facultativos opcionais', () {
      expect(const HolidayCalendar().isHoliday(DateTime(2026, 2, 17)), isFalse);
      expect(const HolidayCalendar(countCarnival: true).isHoliday(DateTime(2026, 2, 17)), isTrue);
      expect(const HolidayCalendar(countCorpusChristi: true).isHoliday(DateTime(2026, 6, 4)), isTrue);
    });

    test('feriado local', () {
      const cal = HolidayCalendar(local: [LocalHoliday(day: 25, month: 1, name: 'Aniversário de SP')]);
      expect(cal.isHoliday(DateTime(2027, 1, 25)), isTrue);
      expect(cal.holidayName(DateTime(2027, 1, 25)), 'Aniversário de SP');
    });
  });

  group('regras de dias úteis', () {
    const cal = HolidayCalendar();
    // 07/09/2026 é segunda-feira (feriado).
    test('mover para o próximo', () {
      expect(applyBusinessRule(DateTime(2026, 9, 7), BusinessRule.next, cal), DateTime(2026, 9, 8));
    });
    test('antecipar', () {
      expect(applyBusinessRule(DateTime(2026, 9, 7), BusinessRule.previous, cal), DateTime(2026, 9, 4));
    });
    test('pular', () {
      expect(applyBusinessRule(DateTime(2026, 9, 7), BusinessRule.skip, cal), isNull);
    });
    test('mensal dia 5 cai no sábado e vai para segunda', () {
      // 05/09/2026 é sábado.
      const r = Recurrence(kind: RecKind.monthlyDay, monthDay: 5, times: [HM(10, 0)], businessRule: BusinessRule.next);
      expect(nextOccurrence(r, DateTime(2026, 9, 1), ctx), DateTime(2026, 9, 8, 10));
    });
  });

  test('uma vez', () {
    final r = Recurrence(kind: RecKind.once, at: DateTime(2026, 3, 1, 9));
    expect(nextOccurrence(r, DateTime(2026, 2, 1), ctx), DateTime(2026, 3, 1, 9));
    expect(nextOccurrence(r, DateTime(2026, 3, 2), ctx), isNull);
    final done = EngineContext(createdAt: created, lastCompleted: DateTime(2026, 2, 1));
    expect(nextOccurrence(r, DateTime(2026, 2, 1), done), isNull);
  });

  test('diário (todos os dias da semana)', () {
    const r = Recurrence(kind: RecKind.weekly, times: [HM(7, 0)]);
    final list = occurrencesBetween(r, DateTime(2026, 3, 1), DateTime(2026, 3, 4), ctx);
    expect(list.length, 3);
  });

  test('a cada 3 dias', () {
    final r = Recurrence(
        kind: RecKind.interval, every: 3, unit: IntervalUnit.days, anchor: DateTime(2026, 3, 1), times: const [HM(8, 0)]);
    final list = occurrencesBetween(r, DateTime(2026, 3, 1), DateTime(2026, 3, 10, 23), ctx);
    expect(list.map((d) => d.day), [1, 4, 7, 10]);
  });

  test('a cada 90 min contínuo', () {
    final r = Recurrence(kind: RecKind.interval, every: 90, unit: IntervalUnit.minutes, anchor: DateTime(2026, 3, 1, 8));
    final list = occurrencesBetween(r, DateTime(2026, 3, 1, 9), DateTime(2026, 3, 1, 13), ctx);
    expect(list, [DateTime(2026, 3, 1, 9, 30), DateTime(2026, 3, 1, 11), DateTime(2026, 3, 1, 12, 30)]);
  });

  test('janela com filtro de dias da semana', () {
    const r = Recurrence(
        kind: RecKind.interval,
        every: 2,
        unit: IntervalUnit.hours,
        windowStart: HM(8, 0),
        windowEnd: HM(12, 0),
        weekdays: {1});
    // 02/03/2026 é segunda.
    final list = occurrencesBetween(r, DateTime(2026, 3, 1), DateTime(2026, 3, 8), ctx);
    expect(list, [DateTime(2026, 3, 2, 8), DateTime(2026, 3, 2, 10), DateTime(2026, 3, 2, 12)]);
  });

  test('dia 31 = último dia do mês', () {
    const r = Recurrence(kind: RecKind.monthlyDay, monthDay: 31, times: [HM(9, 0)]);
    expect(nextOccurrence(r, DateTime(2026, 2, 1), ctx), DateTime(2026, 2, 28, 9));
    expect(nextOccurrence(r, DateTime(2026, 4, 1), ctx), DateTime(2026, 4, 30, 9));
  });

  test('anual 29/02 em ano não bissexto', () {
    const r = Recurrence(kind: RecKind.yearly, day: 29, month: 2, times: [HM(9, 0)]);
    expect(nextOccurrence(r, DateTime(2026, 1, 1), ctx), DateTime(2026, 2, 28, 9));
    expect(nextOccurrence(r, DateTime(2027, 3, 1), ctx), DateTime(2028, 2, 29, 9));
  });

  test('depois da última conclusão com aviso diário se atrasar', () {
    const r = Recurrence(kind: RecKind.afterCompletion, every: 2, unit: IntervalUnit.days, times: [HM(9, 0)]);
    final c = EngineContext(createdAt: created, lastCompleted: DateTime(2026, 3, 1, 15));
    final list = occurrencesBetween(r, DateTime(2026, 3, 1), DateTime(2026, 3, 6), c);
    expect(list, [DateTime(2026, 3, 3, 9), DateTime(2026, 3, 4, 9), DateTime(2026, 3, 5, 9)]);
    // Já atrasado: próximo aviso no dia seguinte, mesmo horário.
    expect(nextOccurrence(r, DateTime(2026, 3, 3, 10), c), DateTime(2026, 3, 4, 9));
  });

  test('antes de uma data, repetindo todo ano', () {
    final r = Recurrence(
        kind: RecKind.relativeDate, target: DateTime(2026, 5, 20), offsets: const [-7, -1], repeatYearly: true);
    final list = occurrencesBetween(r, DateTime(2026, 5, 15), DateTime(2027, 5, 31), ctx);
    expect(list, [DateTime(2026, 5, 19, 9), DateTime(2027, 5, 13, 9), DateTime(2027, 5, 19, 9)]);
  });

  test('corrente: B dispara X min depois de concluir A', () {
    const r = Recurrence(kind: RecKind.chain, chainFrom: 'a', chainDelayMin: 30);
    final c = EngineContext(createdAt: created, chainSourceCompleted: DateTime(2026, 3, 1, 10));
    expect(nextOccurrence(r, DateTime(2026, 3, 1, 10), c), DateTime(2026, 3, 1, 10, 30));
    final doneB = EngineContext(
        createdAt: created, chainSourceCompleted: DateTime(2026, 3, 1, 10), lastCompleted: DateTime(2026, 3, 1, 10, 40));
    expect(nextOccurrence(r, DateTime(2026, 3, 1, 10), doneB), isNull);
    expect(nextOccurrence(r, DateTime(2026, 3, 1), EngineContext(createdAt: created)), isNull);
  });

  test('doneUntil esconde ocorrências já concluídas', () {
    const r = Recurrence(kind: RecKind.weekly, times: [HM(9, 0)]);
    final c = EngineContext(createdAt: created, doneUntil: DateTime(2026, 3, 2, 9));
    expect(nextOccurrence(r, DateTime(2026, 3, 2), c), DateTime(2026, 3, 3, 9));
  });

  test('JSON ida e volta', () {
    final r = Recurrence(
      kind: RecKind.interval,
      every: 1,
      unit: IntervalUnit.hours,
      windowStart: const HM(8, 0),
      windowEnd: const HM(18, 0),
      weekdays: const {1, 2},
      anchor: DateTime(2026, 1, 1),
      businessRule: BusinessRule.skip,
    );
    final back = Recurrence.fromJson(r.toJson());
    expect(back.toJson(), r.toJson());
  });
}
