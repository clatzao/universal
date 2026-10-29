import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal/core/json_store.dart';
import 'package:universal/finance/finance.dart';
import 'package:universal/finance/finance_store.dart';

void main() {
  group('valores', () {
    test('parseCents aceita formatos brasileiros e com ponto', () {
      expect(parseCents('85,90'), 8590);
      expect(parseCents('1.234,56'), 123456);
      expect(parseCents('3.500'), 350000);
      expect(parseCents('55.90'), 5590);
      expect(parseCents('R\$ 12'), 1200);
      expect(parseCents('abc'), isNull);
    });

    test('parcelas: centavos que sobram vão para a 1ª', () {
      expect(splitInstallments(1000, 3), [334, 333, 333]);
      expect(splitInstallments(30000, 3), [10000, 10000, 10000]);
      expect(splitInstallments(500, 1), [500]);
    });

    test('addMonths ajusta fim de mês', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
    });
  });

  group('texto livre', () {
    test('gasto simples com categoria', () {
      final p = parseTx('mercado 85,90')!;
      expect(p.kind, TxKind.expense);
      expect(p.amount, 8590);
      expect(p.description, 'Mercado');
      expect(p.category, FinCategory.mercado);
    });

    test('transporte e R\$', () {
      expect(parseTx('uber 23')!.category, FinCategory.transporte);
      final p = parseTx('almoço R\$ 32,50')!;
      expect(p.amount, 3250);
      expect(p.category, FinCategory.alimentacao);
    });

    test('parcelado', () {
      final p = parseTx('tênis 300 em 3x')!;
      expect(p.installments, 3);
      expect(p.amount, 30000);
      expect(p.description, 'Tênis');
      expect(p.category, FinCategory.compras);
      expect(parseTx('café 2 xícaras 10')!.installments, 1);
    });

    test('entradas', () {
      final s = parseTx('+ salário 3.500')!;
      expect(s.kind, TxKind.income);
      expect(s.amount, 350000);
      expect(s.category, FinCategory.salario);
      final f = parseTx('recebi 150 do freela')!;
      expect(f.kind, TxKind.income);
      expect(f.category, FinCategory.extra);
    });

    test('sem valor não lança', () {
      expect(parseTx('mercado'), isNull);
      expect(parseTx(''), isNull);
    });
  });

  group('cartão', () {
    test('fechamento define a fatura', () {
      // Fecha dia 25, vence dia 5 do mês seguinte.
      expect(invoiceMonth(DateTime(2026, 10, 10), 25, 5), DateTime(2026, 11));
      expect(invoiceMonth(DateTime(2026, 10, 25), 25, 5), DateTime(2026, 12));
      // Fecha dia 3, vence dia 10 do mesmo mês.
      expect(invoiceMonth(DateTime(2026, 10, 2), 3, 10), DateTime(2026, 10));
      expect(invoiceMonth(DateTime(2026, 10, 3), 3, 10), DateTime(2026, 11));
    });
  });

  group('FinanceStore', () {
    late FinanceStore store;
    late Account bank;
    late Account card;

    setUp(() async {
      JsonStore.directory = Directory.systemTemp.createTempSync('fin');
      store = FinanceStore();
      await store.load(now: DateTime(2026, 10, 5));
      bank = Account(id: 'b', name: 'Banco', type: AccountType.banco, initial: 100000);
      card = Account(id: 'c', name: 'Cartão', type: AccountType.cartao, closingDay: 25, dueDay: 5);
      await store.saveAccount(bank);
      await store.saveAccount(card);
    });

    test('compra parcelada cai em faturas seguidas e pagamento abate', () async {
      await store.addTx(
        kind: TxKind.expense,
        amount: 30000,
        date: DateTime(2026, 10, 10),
        category: FinCategory.compras,
        accountId: card.id,
        installments: 3,
      );
      expect(store.invoiceTotal(card, DateTime(2026, 11)), 10000);
      expect(store.invoiceTotal(card, DateTime(2026, 12)), 10000);
      expect(store.invoiceTotal(card, DateTime(2027, 1)), 10000);
      expect(store.cardDebt(card), 30000);
      await store.payInvoice(card, DateTime(2026, 11), bank, 10000, date: DateTime(2026, 10, 6));
      expect(store.invoicePaid(card, DateTime(2026, 11)), 10000);
      expect(store.cardDebt(card), 20000);
      expect(store.balance(bank, now: DateTime(2026, 10, 6)), 90000);
    });

    test('gastos e entradas do mês por categoria', () async {
      await store.addTx(
        kind: TxKind.expense,
        amount: 5000,
        date: DateTime(2026, 10, 2),
        category: FinCategory.mercado,
        accountId: bank.id,
      );
      await store.addTx(
        kind: TxKind.income,
        amount: 200000,
        date: DateTime(2026, 10, 1),
        category: FinCategory.salario,
        accountId: bank.id,
      );
      final m = DateTime(2026, 10);
      expect(store.expenses(m), 5000);
      expect(store.incomes(m), 200000);
      expect(store.byCategory(m)[FinCategory.mercado], 5000);
      await store.setBudget(FinCategory.mercado, 10000);
      expect(store.budget(FinCategory.mercado, m)!.ratio, 0.5);
    });

    test('conta fixa lança uma vez por mês a partir do próximo vencimento', () async {
      final f = FixedBill(
        id: 'f',
        description: 'Aluguel',
        amount: 150000,
        category: FinCategory.moradia,
        accountId: bank.id,
        day: 10,
      );
      await store.saveFixed(f, now: DateTime(2026, 10, 5));
      expect(store.txs.where((t) => t.fixedId == 'f'), isEmpty);
      expect(store.generateFixed(DateTime(2026, 12, 15)), 3);
      expect(store.generateFixed(DateTime(2026, 12, 20)), 0);
      final late = FixedBill(
        id: 'g',
        description: 'Luz',
        amount: 20000,
        category: FinCategory.contas,
        accountId: bank.id,
        day: 3,
      );
      await store.saveFixed(late, now: DateTime(2026, 12, 20));
      expect(store.txs.where((t) => t.fixedId == 'g'), isEmpty);
    });

    test('CSV com ponto e vírgula e vírgula decimal', () async {
      await store.addTx(
        kind: TxKind.expense,
        amount: 8590,
        date: DateTime(2026, 10, 2),
        category: FinCategory.mercado,
        accountId: bank.id,
        description: 'Mercado "bom"',
      );
      final csv = store.toCsv().split('\n');
      expect(csv.first, startsWith('Data;Tipo'));
      expect(csv[1], '02/10/2026;Gasto;"Mercado ""bom""";Mercado;"Banco";"";;-85,90');
    });
  });
}
