import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:universal/core/json_store.dart';
import 'package:universal/core/theme.dart';
import 'package:universal/finance/finance.dart';
import 'package:universal/finance/finance_store.dart';
import 'package:universal/finance/statement.dart';
import 'package:universal/finance/statement_page.dart';
import 'package:universal/games/career.dart';
import 'package:universal/games/games_logic.dart';
import 'package:universal/games/games_store.dart';
import 'package:universal/games/quick_games.dart';
import 'package:universal/notes/note.dart';
import 'package:universal/reminders/recurrence.dart';
import 'package:universal/reminders/reminder.dart';
import 'package:universal/search/search_page.dart';
import 'package:universal/settings/settings.dart';
import 'package:universal/tools/qr_page.dart';

class _MemoryGames extends GamesStore {
  @override
  Future<void> save() async => notifyListeners();
}

Tx _tx(String description, int amount, {FinCategory category = FinCategory.outros}) => Tx(
  id: description,
  kind: TxKind.expense,
  amount: amount,
  date: DateTime(2026, 11, 3),
  category: category,
  accountId: 'a',
  description: description,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('busca', () {
    final reminder = Reminder(
      id: 'r',
      nid: 1,
      title: 'Pagar condomínio',
      rec: Recurrence.fromJson(const {}),
      createdAt: DateTime(2026),
    );
    final note = Note(
      id: 'n',
      kind: NoteKind.nota,
      title: 'Viagem',
      body: 'Levar protetor solar',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    SearchResults find(String q) => searchAll(
      q,
      reminders: [reminder],
      notes: [note],
      txs: [_tx('Almoço no centro', 3550, category: FinCategory.alimentacao)],
      accountName: (_) => 'Nubank',
    );

    test('ignora acentos e maiúsculas', () {
      expect(find('CONDOMINIO').reminders, hasLength(1));
      expect(find('almoco').txs, hasLength(1));
    });

    test('todas as palavras precisam aparecer', () {
      expect(find('protetor viagem').notes, hasLength(1));
      expect(find('protetor praia').notes, isEmpty);
    });

    test('lançamento é achado por categoria, conta e valor', () {
      expect(find('alimentação').txs, hasLength(1));
      expect(find('nubank').txs, hasLength(1));
      expect(find('35,50').txs, hasLength(1));
    });

    test('busca vazia não traz nada', () => expect(find('  ').isEmpty, isTrue));
  });

  group('aviso de backup', () {
    final now = DateTime(2026, 11, 3);

    test('aparece sem backup ou com backup antigo', () {
      expect(backupIsDue(last: null, snoozedUntil: null, now: now), isTrue);
      expect(backupIsDue(last: now.subtract(const Duration(days: 30)), snoozedUntil: null, now: now), isTrue);
      expect(backupIsDue(last: now.subtract(const Duration(days: 29)), snoozedUntil: null, now: now), isFalse);
    });

    test('adiar esconde até o prazo', () {
      expect(backupIsDue(last: null, snoozedUntil: now.add(const Duration(days: 1)), now: now), isFalse);
      expect(backupIsDue(last: null, snoozedUntil: now.subtract(const Duration(days: 1)), now: now), isTrue);
    });

    test('adiamento persiste', () {
      final s = Settings(backupSnoozedUntil: now);
      expect(Settings.fromJson(s.toJson()).backupSnoozedUntil, now);
    });
  });

  test('QR salvo é um PNG quadrado com margem branca', () async {
    final png = await qrPng('https://exemplo.com', size: 512);
    final image = (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;
    expect((image.width, image.height), (512, 512));
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    expect(data.getUint32(0), 0xFFFFFFFF);
    expect(data.getUint32((512 * 256 + 10) * 4), 0xFFFFFFFF);
  });

  group('extrato', () {
    List<int> bytes(String s) => utf8.encode(s);

    test('OFX sem fechar tags, como os bancos exportam', () {
      final lines = parseStatement(
        bytes('''
OFXHEADER:100
<OFX><BANKTRANLIST>
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>20261102120000[-3:BRT]
<TRNAMT>-45.90
<FITID>abc1
<MEMO>Compra &amp; cia
<STMTTRN>
<TRNTYPE>CREDIT
<DTPOSTED>20261103
<TRNAMT>1200.00
<FITID>abc2
<NAME>Salario
</BANKTRANLIST></OFX>'''),
      );
      expect(lines, hasLength(2));
      expect(lines[0].date, DateTime(2026, 11, 2));
      expect(lines[0].amount, -4590);
      expect(lines[0].description, 'Compra & cia');
      expect(lines[0].bankId, 'abc1');
      expect(lines[1].amount, 120000);
      expect(lines[1].description, 'Salario');
    });

    test('CSV em formato de conta, com vírgula', () {
      final lines = parseStatement(
        bytes(
          'Data,Valor,Identificador,Descrição\n'
          '02/11/2026,-45.90,id-1,Padaria\n'
          '03/11/2026,1200.00,id-2,"Pix, recebido"\n',
        ),
      );
      expect(lines.map((l) => l.amount), [-4590, 120000]);
      expect(lines[1].description, 'Pix, recebido');
      expect(lines[0].bankId, 'id-1');
    });

    test('CSV com ponto e vírgula, cabeçalho depois de outras linhas e saldo ignorado', () {
      final lines = parseStatement(
        latin1.encode(
          'Conta: 123\n'
          'Data;Histórico;Valor\n'
          '02/11/26;Almoço;-1.234,56\n'
          '02/11/26;Saldo do dia;9.000,00\n'
          '03/11/2026;Farmácia;(10,00)\n'
          'data errada;Nada;5,00\n',
        ),
      );
      expect(lines, hasLength(2));
      expect(lines[0].date, DateTime(2026, 11, 2));
      expect(lines[0].amount, -123456);
      expect(lines[0].description, 'Almoço');
      expect(lines[1].amount, -1000);
    });

    test('CSV com colunas de débito e crédito', () {
      final lines = parseStatement(
        bytes(
          'Data;Descrição;Débito;Crédito\n'
          '02/11/2026;Luz;150,00;\n'
          '03/11/2026;Pix;;80,00\n',
        ),
      );
      expect(lines.map((l) => l.amount), [-15000, 8000]);
    });

    test('valores em vários formatos', () {
      expect(parseStatementAmount('R\$ 10,00'), 1000);
      expect(parseStatementAmount('10,00 D'), -1000);
      expect(parseStatementAmount('10,00 C'), 1000);
      expect(parseStatementAmount('-R\$ 1.000,50'), -100050);
      expect(parseStatementAmount('abc'), isNull);
    });

    test('arquivo sem lançamentos é recusado', () {
      expect(() => parseStatement(bytes('qualquer coisa\nsem dados')), throwsA(isA<StatementFormatError>()));
      expect(() => parseStatement(const []), throwsA(isA<StatementFormatError>()));
    });

    group('importação', () {
      setUp(() => JsonStore.directory = Directory.systemTemp.createTempSync('extrato'));

      final lines = [
        StatementLine(DateTime(2026, 11, 2), -4590, 'Uber centro', bankId: 'x1'),
        StatementLine(DateTime(2026, 11, 3), 120000, 'Salário'),
        StatementLine(DateTime(2026, 11, 3), -1000, 'Café'),
        StatementLine(DateTime(2026, 11, 3), -1000, 'Café'),
      ];

      Future<FinanceStore> store() async {
        final s = FinanceStore();
        await s.load(now: DateTime(2026, 11, 3));
        return s;
      }

      test('cria lançamentos com tipo e categoria, sem mexer em outra conta', () async {
        final s = await store();
        final id = s.accounts.first.id;
        final list = s.reviewImport(lines, id);
        expect(list.every((c) => c.selectedByDefault), isTrue);
        expect(await s.importCandidates(list, id), 4);
        final uber = s.txs.firstWhere((t) => t.description == 'Uber centro');
        expect(uber.kind, TxKind.expense);
        expect(uber.amount, 4590);
        expect(uber.category, FinCategory.transporte);
        expect(s.txs.firstWhere((t) => t.description == 'Salário').kind, TxKind.income);
        expect(s.balance(s.accounts.first, now: DateTime(2026, 11, 3)), 120000 - 4590 - 2000);
      });

      test('importar o mesmo extrato de novo não duplica, mesmo depois de recarregar', () async {
        final s = await store();
        final id = s.accounts.first.id;
        await s.importCandidates(s.reviewImport(lines, id), id);
        await s.load(now: DateTime(2026, 11, 3));
        final again = s.reviewImport(lines, id);
        expect(again.every((c) => c.alreadyImported && !c.selectedByDefault), isTrue);
      });

      test('compra lançada à mão no mesmo dia começa desmarcada, uma para cada', () async {
        final s = await store();
        final id = s.accounts.first.id;
        await s.addTx(
          kind: TxKind.expense,
          amount: 1000,
          date: DateTime(2026, 11, 3, 15),
          category: FinCategory.alimentacao,
          accountId: id,
        );
        final cafes = s.reviewImport(lines, id).where((c) => c.description == 'Café').toList();
        expect(cafes.where((c) => c.looksManual), hasLength(1));
        expect(cafes.where((c) => c.selectedByDefault), hasLength(1));
      });

      test('inverter transforma compra positiva de cartão em gasto', () async {
        final s = await store();
        final list = s.reviewImport([StatementLine(DateTime(2026, 11, 3), 5000, 'Loja')], 'c', invert: true);
        expect(list.single.kind, TxKind.expense);
        expect(list.single.amount, 5000);
      });

      testWidgets('tela importa só o que ficou marcado', (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final s = FinanceStore()..accounts = [Account(id: 'a', name: 'Banco', type: AccountType.banco)];
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: s,
            child: MaterialApp(
              theme: AppTheme.dark(),
              home: Builder(
                builder: (c) => TextButton(
                  onPressed: () => Navigator.push(
                    c,
                    MaterialPageRoute(builder: (_) => StatementImportPage(lines: lines.take(2).toList())),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        expect(find.text('Importar 2 lançamento(s)'), findsOneWidget);
        expect(s.txs, isEmpty);
        await tester.tap(find.text('Uber centro'));
        await tester.pump();
        expect(find.text('Importar 1 lançamento(s)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });

  group('alerta de orçamento', () {
    test('lista só de 80% para cima, do maior para o menor', () {
      final s = FinanceStore()
        ..budgets = {FinCategory.mercado: 10000, FinCategory.lazer: 10000, FinCategory.saude: 10000}
        ..txs = [
          _tx('a', 7900, category: FinCategory.mercado),
          _tx('b', 8000, category: FinCategory.lazer),
          _tx('c', 12000, category: FinCategory.saude),
        ];
      final alerts = s.budgetAlerts(DateTime(2026, 11));
      expect(alerts.map((a) => a.$1), [FinCategory.saude, FinCategory.lazer]);
      expect(s.budgetAlerts(DateTime(2026, 10)), isEmpty);
    });
  });

  group('contas rápidas', () {
    test('a resposta está entre quatro alternativas diferentes e nenhuma é negativa', () {
      final r = Random(4);
      for (var score = 0; score < 300; score++) {
        final q = mathQuestion(score % 30, r);
        expect(q.options.toSet(), hasLength(4));
        expect(q.options, contains(q.answer));
        expect(q.options.every((o) => o >= 0), isTrue);
      }
    });

    testWidgets('acertar soma ponto, errar tira tempo e o fim grava o recorde', (tester) async {
      final store = _MemoryGames();
      await tester.pumpWidget(
        ChangeNotifierProvider<GamesStore>.value(
          value: store,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: MathGamePage(random: Random(1)),
          ),
        ),
      );
      await tester.tap(find.text('Começar'));
      await tester.pump();
      expect(find.text('45s'), findsOneWidget);

      int? answer() {
        final expression = (tester.widget<Text>(find.textContaining(RegExp(r'[+−×]'))).data!).split(' ');
        final a = int.parse(expression[0]), b = int.parse(expression[2]);
        return switch (expression[1]) {
          '+' => a + b,
          '−' => a - b,
          _ => a * b,
        };
      }

      await tester.tap(find.text('${answer()}'));
      await tester.pump();
      expect(find.text('Pontos: 1'), findsOneWidget);
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pump();

      await tester.pump(const Duration(seconds: 46));
      expect(find.textContaining('Fim de jogo'), findsOneWidget);
      expect(store.record('contas').played, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('jogo da memória', () {
    test('par fica aberto, carta diferente espera para fechar e a vitória conta jogadas', () {
      final g = MemoryGame(Random(3));
      expect(g.cards, hasLength(16));
      final first = 0;
      final twin = g.cards.lastIndexOf(g.cards[first]);
      final other = g.cards.indexWhere((c) => c != g.cards[first]);

      g.flip(first);
      g.flip(other);
      expect(g.waiting, isTrue);
      expect(g.moves, 1);
      g.flip(twin);
      expect(g.isVisible(twin), isFalse);
      g.closeOpen();

      expect(g.flip(first), isFalse);
      expect(g.flip(twin), isTrue);
      expect(g.matched, containsAll([first, twin]));

      for (var v = 0; v < MemoryGame.pairs; v++) {
        final a = g.cards.indexOf(v), b = g.cards.lastIndexOf(v);
        if (g.matched.contains(a)) continue;
        g.flip(a);
        g.flip(b);
      }
      expect(g.won, isTrue);
      expect(g.moves, 9);
      expect(g.score, 96);
    });

    test('tocar na mesma carta não conta jogada', () {
      final g = MemoryGame(Random(3))..flip(0);
      g.flip(0);
      expect(g.moves, 0);
      expect(g.open, [0]);
    });

    testWidgets('vitória grava o recorde', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = _MemoryGames();
      final probe = MemoryGame(Random(9));
      await tester.pumpWidget(
        ChangeNotifierProvider<GamesStore>.value(
          value: store,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: MemoryGamePage(random: Random(9)),
          ),
        ),
      );
      for (var v = 0; v < MemoryGame.pairs; v++) {
        await tester.tap(find.byKey(ValueKey('carta${probe.cards.indexOf(v)}')));
        await tester.pump();
        await tester.tap(find.byKey(ValueKey('carta${probe.cards.lastIndexOf(v)}')));
        await tester.pump();
      }
      expect(find.textContaining('todos os pares'), findsOneWidget);
      expect(store.record('memoria').best, 100);
      expect(tester.takeException(), isNull);
    });
  });

  group('reflexo', () {
    test('média menor dá mais pontos, dentro de 0 a 1000', () {
      expect(reflexScore(const [200, 300]), 750);
      expect(reflexScore(const [5000]), 0);
      expect(reflexScore(const []), 0);
    });

    testWidgets('tocar cedo repete a rodada e cinco rodadas gravam o recorde', (tester) async {
      final store = _MemoryGames();
      await tester.pumpWidget(
        ChangeNotifierProvider<GamesStore>.value(
          value: store,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: ReflexGamePage(random: Random(2)),
          ),
        ),
      );
      await tester.tap(find.text('Toque para começar'));
      await tester.pump();
      await tester.tap(find.textContaining('Espere'));
      await tester.pump();
      expect(find.text('Cedo demais'), findsOneWidget);
      await tester.tap(find.text('Cedo demais'));
      await tester.pump();
      for (var i = 0; i < ReflexGamePage.rounds; i++) {
        await tester.pump(const Duration(seconds: 5));
        await tester.tap(find.text('Toque agora!'));
        await tester.pump();
      }
      expect(find.textContaining('pontos'), findsOneWidget);
      expect(store.record('reflexo').played, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('carreira ampliada', () {
    test('cada posição tem lances suficientes, com alternativas', () {
      for (final p in Position.values) {
        expect(scenesFor(p).length, greaterThanOrEqualTo(matchPlays + 2));
        expect(scenesFor(p).every((s) => s.options.length == 3), isTrue);
      }
    });

    test('evento aparece a cada 4 partidas e respeita o dinheiro', () {
      final c = CareerState.start('Teste', Position.meia, Random(1));
      expect(c.nextEvent(Random(1)), isNull);
      c.totalMatches = eventEveryMatches - 1;
      expect(c.nextEvent(Random(1)), isNull);
      c.totalMatches = eventEveryMatches;
      expect(c.nextEvent(Random(1)), isNotNull);
      const cost = EventOption('x', 'y', salaries: -1);
      expect(c.canChoose(cost), isFalse);
      c.money = c.salary;
      expect(c.canChoose(cost), isTrue);
    });

    test('efeito do evento fica dentro dos limites', () {
      final c = CareerState.start('Teste', Position.meia, Random(1))
        ..energy = 90
        ..money = 5000;
      final before = c.skill(Skill.passe);
      c.applyEvent(const EventOption('x', 'y', energy: 50, salaries: 1, skill: Skill.passe, gain: 2));
      expect(c.energy, 100);
      expect(c.money, 5000 + c.salary);
      expect(c.skill(Skill.passe), before + 2);
    });

    test('histórico sobrevive a salvar e carregar; carreira antiga abre sem histórico', () {
      final c = CareerState.start('Teste', Position.meia, Random(1));
      c.closeSeason(Random(1));
      final back = CareerState.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(back.history, hasLength(1));
      expect(back.history.single.season, 1);
      expect(back.history.single.club, c.club);
      expect(CareerState.fromJson(c.toJson()..remove('history')).history, isEmpty);
    });
  });

  test('caso do dia continua com um único culpado possível com os novos conteúdos', () {
    final start = DateTime(2026);
    for (var i = 0; i < 400; i++) {
      final c = caseForDay(start.add(Duration(days: i)));
      final left = c.suspects.where((s) => c.clues.every((clue) => clue.fits(s))).toList();
      expect(left.map((s) => s.name), [c.culprit.name]);
    }
  });
}
