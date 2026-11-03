import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:universal/app.dart';
import 'package:universal/core/json_store.dart';
import 'package:universal/core/theme.dart';
import 'package:universal/curiosities/curiosities_store.dart';
import 'package:universal/curiosities/fact_detail.dart';
import 'package:universal/curiosities/facts.dart';
import 'package:universal/finance/finance_store.dart';
import 'package:universal/habits/habits_store.dart';
import 'package:universal/info/info_store.dart';
import 'package:universal/info/quote_detail.dart';
import 'package:universal/info/weather_detail.dart';
import 'package:universal/news/news_store.dart';
import 'package:universal/news/rss.dart';
import 'package:universal/notes/notes_store.dart';
import 'package:universal/news/sports.dart';
import 'package:universal/news/sports_page.dart';
import 'package:universal/reminders/reminders_store.dart';
import 'package:universal/settings/settings.dart';

NewsItem _news(String title, {Topic topic = Topic.esportes, String source = 'ge', String summary = ''}) => NewsItem(
  id: title,
  sourceId: source,
  sourceName: source,
  topic: topic,
  title: title,
  summary: summary,
  link: 'https://example.com/$title',
  date: DateTime(2026, 11, 3),
);

void main() {
  group('times e ligas', () {
    test('sem seleção mostra tudo', () {
      expect(matchesFollow(_news('Qualquer coisa'), {}), isTrue);
    });

    test('filtra só esportes, por time, liga e acentos', () {
      expect(matchesFollow(_news('Flamengo vence o clássico'), {'flamengo'}), isTrue);
      expect(matchesFollow(_news('Palmeiras vence o clássico'), {'flamengo'}), isFalse);
      expect(matchesFollow(_news('Dólar sobe', topic: Topic.economia), {'flamengo'}), isTrue);
      expect(matchesFollow(_news('Fim de jogo no Grêmio'), {'gremio'}), isTrue);
      expect(matchesFollow(_news('Rodada', summary: 'Decisão da Libertadores hoje'), {'libertadores'}), isTrue);
    });

    test('não confunde palavra comum com nome de time', () {
      expect(matchesFollow(_news('Santos busca vitória fora de casa'), {'vitoria'}), isFalse);
      expect(matchesFollow(_news('Lesão na coxa tira atacante'), {'coritiba'}), isFalse);
      expect(matchesFollow(_news('Flamenguista comemora'), {'flamengo'}), isFalse);
    });

    test('feed próprio do time passa mesmo sem citar o nome', () {
      expect(matchesFollow(_news('Neymar canta', source: teamSourceId('santos')), {'santos'}), isTrue);
      expect(matchesFollow(_news('Neymar canta', source: teamSourceId('santos')), {'flamengo'}), isFalse);
    });

    test('assunto digitado pela pessoa', () {
      expect(matchesFollow(_news('Real Madrid contrata'), {'${customPrefix}Real Madrid'}), isTrue);
      expect(followLabel('${customPrefix}Real Madrid'), 'Real Madrid');
      expect(followLabel('gremio'), 'Grêmio');
    });

    test('só gera feed extra de times seguidos com feed próprio', () {
      expect(teamSources({'flamengo', 'libertadores', 'bahia'}).map((s) => s.id), [teamSourceId('flamengo')]);
    });

    test('seleção persiste nas configurações', () {
      final s = Settings(followedSports: {'flamengo', '${customPrefix}Neymar'});
      expect(Settings.fromJson(s.toJson()).followedSports, {'flamengo', '${customPrefix}Neymar'});
      expect(Settings.fromJson({}).followedSports, isEmpty);
    });
  });

  group('cotações', () {
    test('histórico em ordem cronológica, um ponto por dia', () {
      final points = parseQuoteHistory([
        {'bid': '5.50', 'high': '5.6', 'low': '5.4', 'timestamp': '1793707527'},
        {'bid': '5.45', 'high': '5.5', 'low': '5.4', 'timestamp': '1793707000'},
        {'bid': '5.30', 'high': '5.4', 'low': '5.2', 'timestamp': '1793577558'},
        {'bid': 'x', 'timestamp': 'y'},
      ]);
      expect(points.length, 2);
      expect(points.first.value, 5.30);
      expect(points.last.value, 5.50);
    });
  });

  group('clima', () {
    final json = <String, dynamic>{
      'current': {
        'temperature_2m': 24.3,
        'apparent_temperature': 27.1,
        'relative_humidity_2m': 64,
        'wind_speed_10m': 8.4,
        'wind_direction_10m': 270,
        'surface_pressure': 1012.4,
        'precipitation': 0.2,
        'uv_index': 6.5,
        'weather_code': 3,
      },
      'hourly': {
        'time': ['2026-11-03T08:00', '2026-11-03T09:00', '2026-11-03T10:00'],
        'temperature_2m': [20, 21, 22],
        'precipitation_probability': [10, 20, 30],
        'weather_code': [0, 1, 2],
      },
      'daily': {
        'time': ['2026-11-03', '2026-11-04'],
        'temperature_2m_max': [28, 29],
        'temperature_2m_min': [18, 19],
        'precipitation_probability_max': [40, null],
        'weather_code': [3, 61],
        'sunrise': ['2026-11-03T05:19', '2026-11-04T05:18'],
        'sunset': ['2026-11-03T18:20', '2026-11-04T18:21'],
        'uv_index_max': [9.1, 8],
      },
    };

    test('previsão por hora começa na hora atual e aceita valores nulos', () {
      final w = WeatherDetail.fromJson(json, now: DateTime(2026, 11, 3, 9, 30));
      expect(w.hours.map((h) => h.time.hour), [9, 10]);
      expect(w.days.length, 2);
      expect(w.days[1].rain, 0);
      expect(w.days[0].sunset, DateTime(2026, 11, 3, 18, 20));
    });

    test('rótulos de vento e UV', () {
      expect(windDirectionLabel(0), 'N');
      expect(windDirectionLabel(270), 'O');
      expect(windDirectionLabel(350), 'N');
      expect(uvLabel(2), 'baixo');
      expect(uvLabel(9), 'muito alto');
    });
  });

  group('curiosidades', () {
    test('todo título aponta para uma curiosidade que existe', () {
      final ids = facts.map((f) => f.id).toSet();
      expect(factWikiTitles.keys.every(ids.contains), isTrue);
      expect(factWikiTitles.length, greaterThanOrEqualTo(facts.length - 1));
    });

    testWidgets('abre a curiosidade e desliza para a próxima', (tester) async {
      final list = facts.take(3).toList();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: FactDetailPage(list: list, index: 0),
        ),
      );
      await tester.pump();
      expect(find.text('1 de 3'), findsOneWidget);
      expect(find.text(list[0].text), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2 de 3'), findsOneWidget);
    });
  });

  group('navegação', () {
    late SettingsStore settings;

    setUp(() {
      JsonStore.directory = Directory.systemTemp.createTempSync('nav');
      settings = SettingsStore();
      tabIndex.value = Tabs.hoje;
    });

    Future<void> pumpShell(WidgetTester tester) async {
      await initializeDateFormatting('pt_BR');
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final finance = FinanceStore();
      await tester.runAsync(finance.load);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider(create: (_) => RemindersStore(settings)),
            ChangeNotifierProvider(create: (_) => HabitsStore(settings)),
            ChangeNotifierProvider(create: (_) => NewsStore(settings)),
            ChangeNotifierProvider(create: (_) => InfoStore(settings)),
            ChangeNotifierProvider(create: (_) => CuriositiesStore()),
            ChangeNotifierProvider(create: (_) => NotesStore()),
            ChangeNotifierProvider.value(value: finance),
          ],
          child: MaterialApp(theme: AppTheme.dark(), home: const HomeShell()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> systemBack(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('voltar leva ao Hoje e só depois pede confirmação para sair', (tester) async {
      await pumpShell(tester);
      tabIndex.value = Tabs.noticias;
      await tester.pump(const Duration(milliseconds: 400));
      await systemBack(tester);
      expect(tabIndex.value, Tabs.hoje);
      expect(find.text('Volte de novo para sair'), findsNothing);
      await systemBack(tester);
      expect(tabIndex.value, Tabs.hoje);
      expect(find.text('Volte de novo para sair'), findsOneWidget);
    });

    testWidgets('deslizar troca de aba', (tester) async {
      await pumpShell(tester);
      await tester.drag(find.byType(PageView), const Offset(-250, 0));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(tabIndex.value, Tabs.lembretes);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a barra troca de aba ao tocar e rola até as últimas funções', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.text('Hábitos').last);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tabIndex.value, Tabs.habitos);
      await tester.drag(find.text('Hábitos').last, const Offset(-400, 0));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Mais').last);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tabIndex.value, Tabs.mais);
    });
  });

  testWidgets('escolher time grava a seleção', (tester) async {
    JsonStore.directory = Directory.systemTemp.createTempSync('sports');
    final settings = SettingsStore();
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider(create: (_) => NewsStore(settings)),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: const SportsFollowPage()),
      ),
    );
    await tester.tap(find.widgetWithText(FilterChip, 'Flamengo'));
    await tester.pump();
    expect(settings.value.followedSports, {'flamengo'});
    await tester.scrollUntilVisible(find.byType(TextField), 300, scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byType(TextField), 'Real Madrid');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(settings.value.followedSports, contains('${customPrefix}Real Madrid'));
  });
}
