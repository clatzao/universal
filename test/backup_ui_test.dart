import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:universal/backup/backup_page.dart';
import 'package:universal/core/json_store.dart';
import 'package:universal/core/theme.dart';
import 'package:universal/finance/finance.dart';
import 'package:universal/finance/finance_store.dart';
import 'package:universal/games/games_store.dart';
import 'package:universal/notes/note.dart';
import 'package:universal/notes/notes_store.dart';
import 'package:universal/settings/settings.dart';
import 'package:universal/tools/vault.dart';

class _Vault implements VaultBackend {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String value) async {}
}

void main() {
  setUp(() => JsonStore.directory = Directory.systemTemp.createTempSync('backupui'));

  test('data do último backup persiste', () {
    final s = Settings(lastBackup: DateTime(2026, 11, 3));
    expect(Settings.fromJson(s.toJson()).lastBackup, DateTime(2026, 11, 3));
    expect(Settings.fromJson({}).lastBackup, isNull);
  });

  group('recarregar depois de restaurar um backup sem esses dados', () {
    test('notas somem da memória', () async {
      final store = NotesStore()..create(NoteKind.nota).title = 'x';
      await store.persist();
      await JsonStore.delete('notes');
      await store.load();
      expect(store.items, isEmpty);
    });

    test('finanças voltam ao estado inicial', () async {
      final store = FinanceStore();
      await store.load(now: DateTime(2026, 11, 3));
      await store.saveAccount(Account(id: 'b', name: 'Banco', type: AccountType.banco));
      await store.addTx(
        kind: TxKind.expense,
        amount: 100,
        date: DateTime(2026, 11, 3),
        category: FinCategory.outros,
        accountId: 'b',
      );
      await JsonStore.delete('finance');
      await store.load(now: DateTime(2026, 11, 3));
      expect(store.txs, isEmpty);
      expect(store.accounts.single.name, 'Carteira');
    });

    test('recordes e carreira somem', () async {
      final store = GamesStore();
      await store.addResult('forca', 3);
      await JsonStore.delete('games');
      await store.load();
      expect(store.record('forca').best, 0);
      expect(store.career, isNull);
    });
  });

  group('tela', () {
    Future<SettingsStore> pump(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final settings = SettingsStore();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: BackupPage(vaultBackend: _Vault()),
          ),
        ),
      );
      await tester.pump();
      return settings;
    }

    testWidgets('abre sem erro e avisa que a senha não pode ser recuperada', (tester) async {
      await pump(tester);
      expect(find.textContaining('Não há como recuperá-la'), findsOneWidget);
      expect(find.text('Nenhum backup feito ainda.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('recusa senha curta', (tester) async {
      await pump(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Crie uma senha para o arquivo'), 'curta');
      await tester.tap(find.text('Criar e salvar backup'));
      await tester.pump();
      expect(find.textContaining('pelo menos 8 caracteres'), findsOneWidget);
    });

    testWidgets('recusa senhas diferentes', (tester) async {
      await pump(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Crie uma senha para o arquivo'), 'senha-grande');
      await tester.enterText(find.widgetWithText(TextField, 'Repita a senha'), 'outra-senha-grande');
      await tester.tap(find.text('Criar e salvar backup'));
      await tester.pump();
      expect(find.text('As senhas não são iguais'), findsOneWidget);
    });
  });
}
