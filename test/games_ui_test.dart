import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:universal/core/json_store.dart';
import 'package:universal/core/theme.dart';
import 'package:universal/games/career.dart';
import 'package:universal/games/games_logic.dart';
import 'package:universal/games/games_page.dart';
import 'package:universal/games/games_store.dart';

/// Sem gravar em disco: arquivos não terminam dentro do relógio simulado dos testes de tela.
class _MemoryGames extends GamesStore {
  @override
  Future<void> save() {
    notifyListeners();
    return Future.value();
  }
}

void main() {
  late GamesStore store;
  final day = DateTime(2026, 11, 3);

  setUp(() {
    JsonStore.directory = Directory.systemTemp.createTempSync('games');
    store = _MemoryGames();
  });

  Future<void> pump(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(360, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(theme: AppTheme.dark(), home: page),
      ),
    );
    await tester.pump();
  }

  group('recordes', () {
    setUp(() => store = GamesStore());

    test('guarda o melhor resultado e persiste', () async {
      await store.addResult('forca', 3);
      await store.addResult('forca', 1);
      expect(store.record('forca').best, 3);
      expect(store.record('forca').played, 2);
      final again = GamesStore();
      await again.load();
      expect(again.record('forca').best, 3);
    });

    test('sequência diária conta só vitórias em dias seguidos', () async {
      await store.addResult('palavra', 50, dailyWin: DateTime(2026, 11, 1));
      await store.addResult('palavra', 50, dailyWin: DateTime(2026, 11, 2));
      expect(store.record('palavra').streak, 2);
      await store.addResult('palavra', 50, dailyWin: DateTime(2026, 11, 5));
      expect(store.record('palavra').streak, 1);
    });

    test('progresso diário só vale no próprio dia', () async {
      await store.setDaily('caso', day, {'done': true});
      expect(store.dailyFor('caso', day)?['done'], isTrue);
      expect(store.dailyFor('caso', DateTime(2026, 11, 4)), isNull);
    });

    test('carreira persiste', () async {
      await store.setCareer(CareerState.start('Zé', Position.meia, Random(1)));
      final again = GamesStore();
      await again.load();
      expect(again.career?.name, 'Zé');
      await again.setCareer(null);
      final third = GamesStore();
      await third.load();
      expect(third.career, isNull);
    });
  });

  testWidgets('lista dos jogos abre', (tester) async {
    await pump(tester, const GamesPage());
    for (final title in ['Palavra do dia', 'Caso do dia', 'Forca', 'Carreira de futebol']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('forca: tocar nas letras e não estourar a tela', (tester) async {
    await pump(tester, HangmanPage(random: Random(3)));
    await tester.tap(find.text('A'));
    await tester.pump();
    await tester.tap(find.text('E'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('palavra do dia: tamanho errado avisa, tentativa fica salva', (tester) async {
    await pump(tester, WordDayPage(day: day));
    final target = wordOfDay(day);
    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pump();
    expect(find.textContaining('A palavra tem'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'z' * lettersOnly(target.word).length);
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pump();
    expect(store.dailyFor('palavra', day)?['tries'], hasLength(1));

    await pump(tester, Container());
    await pump(tester, WordDayPage(day: day));
    expect(find.text('Tentativa 2 de ${WordDayGame.maxTries}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('palavra do dia: vencer registra resultado e sequência', (tester) async {
    await pump(tester, WordDayPage(day: day));
    await tester.enterText(find.byType(TextField), wordOfDay(day).word);
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pump();
    expect(find.textContaining('Acertou em 1 tentativa'), findsOneWidget);
    expect(store.record('palavra').best, 80);
    expect(store.record('palavra').streak, 1);
    await tester.pump();
  });

  testWidgets('caso do dia: ouvir pista e acusar o culpado', (tester) async {
    final data = caseForDay(day);
    await pump(tester, CasePage(day: day));
    await tester.tap(find.text('Toque para ouvir').first);
    await tester.pump();
    expect(find.text(data.clues.first.text), findsOneWidget);

    final index = data.suspects.indexOf(data.suspects.firstWhere((s) => s.name == data.culprit.name));
    await tester.tap(find.text('Acusar').at(index));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Acusar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Caso resolvido'), findsOneWidget);
    expect(store.record('caso').best, 85);
    expect(store.dailyFor('caso', day)?['done'], isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('caso do dia: acusação errada encerra sem pontos', (tester) async {
    final data = caseForDay(day);
    await pump(tester, CasePage(day: day));
    final wrong = data.suspects.indexOf(data.suspects.firstWhere((s) => s.name != data.culprit.name));
    await tester.tap(find.text('Acusar').at(wrong));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Acusar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('pessoa errada'), findsOneWidget);
    expect(store.record('caso').best, 0);
    expect(store.record('caso').streak, 0);
  });

  testWidgets('carreira: criar, treinar e jogar uma partida', (tester) async {
    await pump(tester, CareerPage(random: Random(4)));
    await tester.tap(find.text('Começar carreira'));
    await tester.pump();
    expect(find.text('Dê um nome ao jogador'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Zé da Bola');
    await tester.tap(find.text('Começar carreira'));
    await tester.pump();
    expect(store.career?.name, 'Zé da Bola');
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Treinar Passe'));
    await tester.pump();
    expect(store.career!.energy, 75);

    await tester.tap(find.text('Jogar a partida da semana'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Lance 1 de 3'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pump();
    await tester.tap(find.text('Próximo lance'));
    await tester.pump();
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pump();
    await tester.tap(find.text('Próximo lance'));
    await tester.pump();
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pump();
    await tester.tap(find.text('Ver resultado'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(store.career!.week, 2);
    expect(store.career!.totalMatches, 1);
    expect(find.textContaining('Sua nota'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('carreira: temporada termina com resumo e aposentadoria grava recorde', (tester) async {
    final c = CareerState.start('Veterano', Position.atacante, Random(1))
      ..age = 37
      ..week = seasonWeeks
      ..totalGoals = 100;
    await store.setCareer(c);
    await pump(tester, CareerPage(random: Random(4)));
    await tester.tap(find.text('Jogar a partida da semana'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < matchPlays; i++) {
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pump();
      await tester.tap(find.text(i < matchPlays - 1 ? 'Próximo lance' : 'Ver resultado'));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Fim da temporada'), findsOneWidget);
    expect(c.retired, isTrue);
    expect(store.record('carreira').best, c.careerScore);
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Veterano se aposentou'), findsOneWidget);
    expect(find.text('Temporadas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('carreira: evento fora de campo aparece depois da quarta partida e grava a escolha', (tester) async {
    final c = CareerState.start('Novato', Position.meia, Random(1))..totalMatches = eventEveryMatches - 1;
    await store.setCareer(c);
    await pump(tester, CareerPage(random: Random(4)));
    await tester.tap(find.text('Jogar a partida da semana'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < matchPlays; i++) {
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pump();
      await tester.tap(find.text(i < matchPlays - 1 ? 'Próximo lance' : 'Ver resultado'));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Fora de campo'), findsOneWidget);
    final buttons = find.descendant(of: find.byType(AlertDialog), matching: find.byType(OutlinedButton));
    await tester.tap(buttons.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Fora de campo'), findsNothing);
    expect(c.totalMatches, eventEveryMatches);
    expect(tester.takeException(), isNull);
  });
}
