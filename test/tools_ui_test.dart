import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:universal/core/theme.dart';
import 'package:universal/info/info_store.dart';
import 'package:universal/settings/settings.dart';
import 'package:universal/tools/qr_page.dart';
import 'package:universal/tools/tools_page.dart';
import 'package:universal/tools/vault.dart';
import 'package:universal/tools/vault_page.dart';

class _MemoryBackend implements VaultBackend {
  String? value;
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;

  @override
  Future<String?> read() async {
    if (failRead) throw Exception('sem acesso');
    return value;
  }

  @override
  Future<void> write(String v) async {
    if (failWrite) throw Exception('sem acesso');
    writes++;
    value = v;
  }
}

VaultEntry _entry(String id, String name, {String password = 'segredo'}) =>
    VaultEntry(id: id, name: name, username: 'eu@exemplo.com', password: password, updatedAt: DateTime(2026, 11, 3));

void main() {
  group('cofre', () {
    test('grava, reabre e tranca sem deixar senhas na memória', () async {
      final backend = _MemoryBackend();
      final store = VaultStore(backend);
      await store.open();
      await store.save(_entry('1', 'Banco'));
      store.lock();
      expect(store.entries, isEmpty);
      expect(store.isOpen, isFalse);
      final again = VaultStore(backend);
      await again.open();
      expect(again.entries.single.password, 'segredo');
    });

    test('erro de leitura não apaga nem sobrescreve o cofre', () async {
      final backend = _MemoryBackend()..value = 'dados que não são json';
      final store = VaultStore(backend);
      await expectLater(store.open(), throwsA(isA<VaultReadError>()));
      expect(store.isOpen, isFalse);
      await expectLater(store.save(_entry('1', 'Banco')), throwsStateError);
      expect(backend.value, 'dados que não são json');
      expect(backend.writes, 0);
    });

    test('falha ao gravar mantém a lista como estava', () async {
      final backend = _MemoryBackend();
      final store = VaultStore(backend);
      await store.open();
      await store.save(_entry('1', 'Banco'));
      backend.failWrite = true;
      await expectLater(store.save(_entry('2', 'Email')), throwsException);
      expect(store.entries.map((e) => e.id), ['1']);
      await expectLater(store.remove(store.entries.single), throwsException);
      expect(store.entries.map((e) => e.id), ['1']);
    });

    test('editar substitui, busca e ordena por nome', () async {
      final store = VaultStore(_MemoryBackend());
      await store.open();
      await store.save(_entry('1', 'Zeta'));
      await store.save(_entry('2', 'alfa'));
      await store.save(_entry('1', 'Zeta nova'));
      expect(store.entries.length, 2);
      expect(store.search('').map((e) => e.name), ['alfa', 'Zeta nova']);
      expect(store.search('ZETA').single.id, '1');
      expect(store.search('segredo'), isEmpty);
    });

    Future<void> pump(WidgetTester tester, Widget page) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: page));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('sem confirmar a identidade nada aparece', (tester) async {
      final backend = _MemoryBackend();
      final store = VaultStore(backend);
      await store.open();
      await store.save(_entry('1', 'Banco'));
      await pump(tester, VaultPage(backend: backend, auth: () async => VaultAuthResult.canceled));
      expect(find.text('Cofre trancado'), findsOneWidget);
      expect(find.text('Banco'), findsNothing);
      expect(find.text('Não foi possível confirmar sua identidade.'), findsOneWidget);
    });

    testWidgets('sem bloqueio de tela explica o que fazer', (tester) async {
      await pump(tester, VaultPage(backend: _MemoryBackend(), auth: () async => VaultAuthResult.noDeviceLock));
      expect(find.textContaining('ative um bloqueio de tela'), findsOneWidget);
    });

    testWidgets('abre, cria uma senha e tranca ao sair do app', (tester) async {
      final backend = _MemoryBackend();
      await pump(tester, VaultPage(backend: backend, auth: () async => VaultAuthResult.ok));
      expect(find.text('Nova senha'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500)); // o botão entra com animação
      await tester.tap(find.text('Nova senha'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.widgetWithText(TextField, 'Nome (ex.: Banco, e-mail)'), 'Banco');
      await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'minha-senha');
      await tester.tap(find.text('Salvar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Banco'), findsOneWidget);
      expect(backend.value, contains('minha-senha'));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(find.text('Cofre trancado'), findsOneWidget);
      expect(find.text('Banco'), findsNothing);
    });
  });

  test('QR code: só links web ganham botão de abrir', () {
    expect(webLinkIn('https://exemplo.com/a')?.host, 'exemplo.com');
    expect(webLinkIn(' http://exemplo.com '), isNotNull);
    expect(webLinkIn('javascript:alert(1)'), isNull);
    expect(webLinkIn('intent://abrir#Intent;end'), isNull);
    expect(webLinkIn('tel:+5511999999999'), isNull);
    expect(webLinkIn('apenas texto'), isNull);
  });

  group('telas das ferramentas', () {
    Future<void> pump(WidgetTester tester, Widget page) async {
      await tester.binding.setSurfaceSize(const Size(360, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final settings = SettingsStore();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider(create: (_) => InfoStore(settings)),
          ],
          child: MaterialApp(theme: AppTheme.dark(), home: page),
        ),
      );
      await tester.pump();
    }

    testWidgets('lista de ferramentas e todas abrem sem erro de layout', (tester) async {
      await tester.pumpWidget(Container());
      for (final page in const [ConverterPage(), SplitPage(), PercentPage(), InterestPage(), DrawPage(), QrPage()]) {
        await pump(tester, page);
        expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
      }
      await tester.binding.setSurfaceSize(const Size(360, 1400));
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsStore(),
          child: MaterialApp(theme: AppTheme.dark(), home: const ToolsPage()),
        ),
      );
      await tester.pump();
      expect(find.text('Cofre de senhas'), findsOneWidget);
    });

    testWidgets('sorteio de times com a quantidade por time', (tester) async {
      await pump(tester, DrawPage(random: Random(1)));
      await tester.enterText(find.byType(TextField), 'Ana, Bia, Caio, Davi, Edu');
      await tester.pump();
      await tester.tap(find.byTooltip('Menos'));
      await tester.pump();
      await tester.tap(find.byTooltip('Menos'));
      await tester.pump();
      await tester.tap(find.byTooltip('Menos'));
      await tester.pump();
      expect(find.textContaining('3 time(s); o último fica com 1 pessoa(s)'), findsOneWidget);
      await tester.tap(find.text('Sortear times'));
      await tester.pump();
      expect(find.text('Time 1 (2)'), findsOneWidget);
      expect(find.text('Time 3 (1)'), findsOneWidget);
    });

    testWidgets('dividir conta em partes iguais com gorjeta', (tester) async {
      await pump(tester, const SplitPage());
      await tester.enterText(find.widgetWithText(TextField, 'Valor da conta'), '100');
      await tester.pump();
      expect(find.textContaining('110,00'), findsOneWidget);
      expect(find.textContaining('55,00'), findsOneWidget);
    });

    testWidgets('conversor de distância', (tester) async {
      await pump(tester, const ConverterPage());
      expect(find.text('Resultado'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Valor'), '2');
      await tester.pump();
      expect(find.text('0,002'), findsOneWidget);
    });
  });
}
