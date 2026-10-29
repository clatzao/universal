import 'package:flutter_test/flutter_test.dart';
import 'package:universal/core/text_norm.dart';
import 'package:universal/reminders/holidays.dart';
import 'package:universal/reminders/parser.dart';
import 'package:universal/reminders/recurrence.dart';

void main() {
  // Quinta-feira, 29/10/2026 10:00.
  final now = DateTime(2026, 10, 29, 10, 0);
  final ctx = EngineContext(createdAt: now);

  ParsedReminder p(String s) {
    final r = parseReminder(s, now: now);
    expect(r, isNotNull, reason: s);
    return r!;
  }

  DateTime? next(ParsedReminder r, [DateTime? after]) =>
      nextOccurrence(r.recurrence, after ?? now, EngineContext(createdAt: now));

  test('normalização mantém o tamanho', () {
    const s = 'Amanhã às 15h30 Ação ÇÃO ªº';
    final n = normalizeKeepLength(s);
    expect(n.length, s.length);
    expect(n, 'amanha as 15h30 acao cao ao');
  });

  test('toda segunda às 9h pagar academia', () {
    final r = p('toda segunda às 9h pagar academia');
    expect(r.title, 'Pagar academia');
    expect(r.recurrence.kind, RecKind.weekly);
    expect(r.recurrence.weekdays, {1});
    expect(next(r), DateTime(2026, 11, 2, 9, 0));
  });

  test('segundas e quartas 7:30', () {
    final r = p('segundas e quartas 7:30');
    expect(r.recurrence.kind, RecKind.weekly);
    expect(r.recurrence.weekdays, {1, 3});
    expect(r.recurrence.times, [const HM(7, 30)]);
    expect(next(r), DateTime(2026, 11, 2, 7, 30));
  });

  test('beber água a cada 1h das 8h às 18h', () {
    final r = p('beber água a cada 1h das 8h às 18h');
    expect(r.title, 'Beber água');
    expect(r.recurrence.kind, RecKind.interval);
    expect(r.recurrence.windowStart, const HM(8, 0));
    expect(r.recurrence.windowEnd, const HM(18, 0));
    expect(next(r), DateTime(2026, 10, 29, 11, 0));
    expect(next(r, DateTime(2026, 10, 29, 18, 30)), DateTime(2026, 10, 30, 8, 0));
    final day = occurrencesBetween(r.recurrence, DateTime(2026, 10, 30), DateTime(2026, 10, 31), ctx);
    expect(day.length, 11);
  });

  test('regar a planta a cada 4 dias depois de concluir às 9h', () {
    final r = p('regar a planta a cada 4 dias depois de concluir às 9h');
    expect(r.title, 'Regar a planta');
    expect(r.recurrence.kind, RecKind.afterCompletion);
    expect(r.recurrence.every, 4);
    expect(r.recurrence.unit, IntervalUnit.days);
    expect(next(r), DateTime(2026, 11, 2, 9, 0));
  });

  test('reunião na última sexta do mês às 17h', () {
    final r = p('reunião na última sexta do mês às 17h');
    expect(r.title, 'Reunião');
    expect(r.recurrence.kind, RecKind.monthlyNth);
    expect(r.recurrence.nth, -1);
    expect(r.recurrence.nthWeekday, 5);
    expect(next(r), DateTime(2026, 10, 30, 17, 0));
    expect(next(r, DateTime(2026, 10, 31)), DateTime(2026, 11, 27, 17, 0));
  });

  test('2ª terça do mês', () {
    final r = p('reunião 2ª terça do mês às 14h');
    expect(r.recurrence.kind, RecKind.monthlyNth);
    expect(r.recurrence.nth, 2);
    expect(r.recurrence.nthWeekday, 2);
    expect(next(r), DateTime(2026, 11, 10, 14, 0));
  });

  test('pagar aluguel todo dia 5 às 10h', () {
    final r = p('pagar aluguel todo dia 5 às 10h');
    expect(r.title, 'Pagar aluguel');
    expect(r.recurrence.kind, RecKind.monthlyDay);
    expect(r.recurrence.monthDay, 5);
    expect(next(r), DateTime(2026, 11, 5, 10, 0));
  });

  test('ponto em dias úteis às 8h', () {
    final r = p('ponto em dias úteis às 8h');
    expect(r.title, 'Ponto');
    expect(r.recurrence.kind, RecKind.weekly);
    expect(r.recurrence.weekdays, {1, 2, 3, 4, 5});
    expect(r.recurrence.businessRule, BusinessRule.skip);
    final list = occurrencesBetween(
        r.recurrence, DateTime(2026, 10, 29, 12), DateTime(2026, 11, 3, 23), EngineContext(createdAt: now));
    // 02/11 (Finados) é pulado.
    expect(list, [DateTime(2026, 10, 30, 8), DateTime(2026, 11, 3, 8)]);
  });

  test('amanhã às 15h30', () {
    final r = p('amanhã às 15h30');
    expect(r.title, '');
    expect(r.recurrence.kind, RecKind.once);
    expect(r.recurrence.at, DateTime(2026, 10, 30, 15, 30));
  });

  test('em 20 minutos', () {
    final r = p('tirar o bolo do forno em 20 minutos');
    expect(r.title, 'Tirar o bolo do forno');
    expect(r.recurrence.at, DateTime(2026, 10, 29, 10, 20));
  });

  test('pagar IPVA 5 e 1 dias antes de 10/11', () {
    final r = p('pagar IPVA 5 e 1 dias antes de 10/11');
    expect(r.title, 'Pagar IPVA');
    expect(r.recurrence.kind, RecKind.relativeDate);
    expect(r.recurrence.offsets, [-5, -1]);
    expect(r.recurrence.target, DateTime(2026, 11, 10));
    final list = occurrencesBetween(r.recurrence, now, DateTime(2027, 12, 31), ctx);
    expect(list, [DateTime(2026, 11, 5, 9), DateTime(2026, 11, 9, 9)]);
  });

  test('aniversário da mãe todo ano 25/12', () {
    final r = p('aniversário da mãe todo ano 25/12');
    expect(r.title, 'Aniversário da mãe');
    expect(r.recurrence.kind, RecKind.yearly);
    expect(r.recurrence.day, 25);
    expect(r.recurrence.month, 12);
    expect(next(r), DateTime(2026, 12, 25, 9));
    expect(next(r, DateTime(2026, 12, 26)), DateTime(2027, 12, 25, 9));
  });

  test('sexta às 8 da noite', () {
    final r = p('sexta às 8 da noite');
    expect(r.recurrence.kind, RecKind.once);
    expect(r.recurrence.at, DateTime(2026, 10, 30, 20, 0));
  });

  test('todo dia às 8h e 20h tomar remédio', () {
    final r = p('todo dia às 8h e 20h tomar remédio');
    expect(r.title, 'Tomar remédio');
    expect(r.recurrence.kind, RecKind.weekly);
    expect(r.recurrence.weekdays, isEmpty);
    expect(r.recurrence.times, [const HM(8, 0), const HM(20, 0)]);
  });

  test('só hora: hoje se ainda vem, senão amanhã', () {
    expect(p('ligar 9h').recurrence.at, DateTime(2026, 10, 30, 9));
    expect(p('ligar 14h').recurrence.at, DateTime(2026, 10, 29, 14));
  });

  test('sem data nem hora retorna nulo', () {
    expect(parseReminder('comprar pão', now: now), isNull);
  });

  test('feriado do dia é reconhecido', () {
    expect(const HolidayCalendar().holidayName(DateTime(2026, 11, 20)), contains('Consciência Negra'));
  });
}
