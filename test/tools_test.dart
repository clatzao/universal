import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal/tools/tools_logic.dart';

UnitGroup _group(String label) => unitGroups.firstWhere((g) => g.label == label);

Unit _unit(UnitGroup g, String id) => g.units.firstWhere((u) => u.id == id);

void main() {
  group('conversor', () {
    test('unidades comuns', () {
      final d = _group('Distância');
      expect(convertUnit(1, d, _unit(d, 'km'), _unit(d, 'm')), 1000);
      expect(convertUnit(1, d, _unit(d, 'mi'), _unit(d, 'km')), closeTo(1.609344, 1e-9));
      final w = _group('Peso');
      expect(convertUnit(1, w, _unit(w, 'lb'), _unit(w, 'kg')), closeTo(0.45359237, 1e-9));
      final s = _group('Velocidade');
      expect(convertUnit(36, s, _unit(s, 'kmh'), _unit(s, 'ms')), closeTo(10, 1e-9));
    });

    test('temperatura', () {
      final t = temperatureGroup;
      expect(convertUnit(100, t, _unit(t, 'c'), _unit(t, 'f')), closeTo(212, 1e-9));
      expect(convertUnit(32, t, _unit(t, 'f'), _unit(t, 'c')), closeTo(0, 1e-9));
      expect(convertUnit(0, t, _unit(t, 'c'), _unit(t, 'k')), closeTo(273.15, 1e-9));
    });

    test('moedas', () {
      expect(convertCurrency(10, 5.5, 1), 55);
      expect(convertCurrency(55, 1, 5.5), closeTo(10, 1e-9));
      expect(convertCurrency(10, 6.05, 5.5), closeTo(11, 1e-9));
    });

    test('formatar e ler números', () {
      expect(formatNumber(1000), '1000');
      expect(formatNumber(1.5), '1,5');
      expect(formatNumber(0), '0');
      expect(formatNumber(double.nan), '—');
      expect(parseNumber('1.234,5'), 1234.5);
      expect(parseNumber('1234.5'), 1234.5);
      expect(parseNumber('12,5'), 12.5);
      expect(parseNumber('abc'), isNull);
      expect(parseNumber(''), isNull);
    });
  });

  group('dividir conta', () {
    test('partes iguais somam o total', () {
      expect(splitEqually(1000, 3), [334, 333, 333]);
      expect(splitEqually(900, 3), [300, 300, 300]);
      expect(splitEqually(100, 0), isEmpty);
    });

    test('gorjeta', () {
      expect(addTip(10000, 10), 11000);
      expect(addTip(10000, 0), 10000);
    });

    test('por consumo: gorjeta proporcional e soma exata', () {
      final parts = splitByConsumption([3000, 1000], 0, 10);
      expect(parts, [3300, 1100]);
      final odd = splitByConsumption([3333, 1234, 999], 500, 13);
      expect(odd.fold<int>(0, (s, v) => s + v), addTip(3333 + 1234 + 999 + 500, 13));
    });

    test('por consumo sem nada consumido divide o compartilhado', () {
      expect(splitByConsumption([0, 0], 1000, 0), [500, 500]);
      expect(splitByConsumption([0, 0], 0, 10), [0, 0]);
    });
  });

  group('porcentagem', () {
    test('cálculos', () {
      expect(percentOf(20, 150), 30);
      expect(applyIncrease(100, 10), closeTo(110, 1e-9));
      expect(applyDiscount(100, 10), closeTo(90, 1e-9));
      expect(whatPercent(30, 150), 20);
      expect(percentChange(100, 150), 50);
      expect(percentChange(200, 150), -25);
    });

    test('divisão por zero não quebra', () {
      expect(whatPercent(1, 0), isNull);
      expect(percentChange(0, 10), isNull);
    });
  });

  group('juros', () {
    test('juros compostos conhecidos', () {
      final r = compound(initial: 1000, monthlyRate: 1, months: 12);
      expect(r.total, closeTo(1126.825, 0.001));
      expect(r.interest, closeTo(126.825, 0.001));
    });

    test('com aportes e sem juros', () {
      expect(compound(initial: 100, monthlyRate: 0, months: 10, monthly: 50).total, 600);
      final r = compound(initial: 0, monthlyRate: 1, months: 12, monthly: 100);
      expect(r.total, closeTo(1268.25, 0.01));
      expect(r.invested, 1200);
    });

    test('parcela pela tabela Price', () {
      expect(installmentValue(principal: 10000, monthlyRate: 2, months: 12), closeTo(945.60, 0.01));
      expect(installmentValue(principal: 1200, monthlyRate: 0, months: 12), 100);
    });

    test('taxa embutida recupera a taxa usada', () {
      final p = installmentValue(principal: 10000, monthlyRate: 2, months: 12);
      expect(impliedMonthlyRate(principal: 10000, installment: p, months: 12), closeTo(2, 1e-6));
      expect(impliedMonthlyRate(principal: 1200, installment: 100, months: 12), 0);
      expect(impliedMonthlyRate(principal: 1200, installment: 50, months: 12), isNull);
    });

    test('valor presente das parcelas', () {
      expect(presentValue(installment: 100, months: 12, monthlyReturn: 0), 1200);
      expect(presentValue(installment: 945.60, months: 12, monthlyReturn: 2), closeTo(10000, 0.1));
    });
  });

  group('sorteio', () {
    final random = Random(7);

    test('lê nomes por linha, vírgula e ponto e vírgula', () {
      expect(parseNames('Ana, Bia\n\nCaio; Davi  '), ['Ana', 'Bia', 'Caio', 'Davi']);
    });

    test('número dentro do intervalo, inclusive os extremos', () {
      final seen = {for (var i = 0; i < 300; i++) drawNumber(1, 3, random)};
      expect(seen, {1, 2, 3});
    });

    test('vários números não repetem', () {
      final n = drawNumbers(1, 60, 6, random);
      expect(n.toSet().length, 6);
      expect(n.every((v) => v >= 1 && v <= 60), isTrue);
      expect(drawNumbers(1, 3, 10, random).length, 3);
    });

    test('times com a quantidade escolhida e ninguém repetido', () {
      final people = [for (var i = 0; i < 10; i++) 'P$i'];
      final teams = drawTeams(people, 5, random);
      expect(teams.length, 2);
      expect(teams.every((t) => t.length == 5), isTrue);
      expect(teams.expand((t) => t).toSet(), people.toSet());
    });

    test('quem sobra fica num time menor', () {
      final teams = drawTeams(['A', 'B', 'C', 'D', 'E', 'F', 'G'], 3, random);
      expect(teams.map((t) => t.length), [3, 3, 1]);
    });

    test('entradas inválidas', () {
      expect(drawTeams(['A'], 0, random), isEmpty);
      expect(drawTeams([], 3, random), isEmpty);
    });
  });

  group('senha', () {
    test('tamanho e tipos pedidos', () {
      for (var i = 0; i < 50; i++) {
        final p = generatePassword(length: 16, random: Random(i));
        expect(p.length, 16);
        expect(p, matches(RegExp(r'[a-z]')));
        expect(p, matches(RegExp(r'[A-Z]')));
        expect(p, matches(RegExp(r'[0-9]')));
        expect(p, matches(RegExp(r'[!@#$%&*\-_=+?]')));
        expect(p, isNot(matches(RegExp(r'[lIO01]'))));
      }
    });

    test('respeita o que foi desligado', () {
      final p = generatePassword(length: 20, upper: false, digits: false, symbols: false);
      expect(p, matches(RegExp(r'^[a-z]{20}$')));
    });

    test('tamanho pequeno ainda inclui cada tipo', () {
      expect(generatePassword(length: 2).length, 4);
    });

    test('senhas diferentes a cada geração', () {
      expect(generatePassword(), isNot(generatePassword()));
    });
  });
}
