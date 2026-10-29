import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:universal/core/json_store.dart';
import 'package:universal/core/theme.dart';
import 'package:universal/finance/finance.dart';
import 'package:universal/finance/finance_page.dart';
import 'package:universal/finance/finance_store.dart';

void main() {
  testWidgets('telas de Finanças abrem com dados sem erros de layout', (tester) async {
    await initializeDateFormatting('pt_BR');
    JsonStore.directory = Directory.systemTemp.createTempSync('finui');
    final store = FinanceStore();
    final now = DateTime.now();
    await tester.runAsync(() async {
      await store.load();
      await store.saveAccount(Account(id: 'b', name: 'Banco', type: AccountType.banco, initial: 250000));
      await store.saveAccount(
        Account(id: 'c', name: 'Cartão', type: AccountType.cartao, closingDay: 25, dueDay: 5, limit: 500000),
      );
      await store.addTx(kind: TxKind.income, amount: 350000, date: now, category: FinCategory.salario, accountId: 'b');
      await store.addTx(
        kind: TxKind.expense,
        amount: 8590,
        date: now,
        category: FinCategory.mercado,
        accountId: 'b',
        description: 'Mercado',
      );
      await store.addTx(
        kind: TxKind.expense,
        amount: 30000,
        date: now,
        category: FinCategory.compras,
        accountId: 'c',
        description: 'Tênis',
        installments: 3,
      );
      await store.setBudget(FinCategory.mercado, 10000);
      await store.saveGoal(SavingsGoal(id: 'g', name: 'Viagem', target: 500000, saved: 120000));
      await store.saveFixed(
        FixedBill(
          id: 'f',
          description: 'Aluguel',
          amount: 150000,
          category: FinCategory.moradia,
          accountId: 'b',
          day: 10,
        ),
      );
    });

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(theme: AppTheme.dark(), home: const FinancePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SALDO EM CONTAS'), findsOneWidget);

    for (final tab in ['Lançamentos', 'Contas', 'Planejamento']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }
    expect(find.text('Viagem'), findsOneWidget);

    await tester.tap(find.text('Contas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cartão'));
    await tester.pumpAndSettle();
    expect(find.text('Pagar fatura'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lançar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'uber 23');
    await tester.pump();
    expect(find.textContaining('Transporte'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
