import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:universal/core/json_store.dart';
import 'package:universal/core/theme.dart';
import 'package:universal/news/article.dart';
import 'package:universal/news/news_page.dart';
import 'package:universal/news/news_reader.dart';
import 'package:universal/news/news_store.dart';
import 'package:universal/news/rss.dart';
import 'package:universal/settings/settings.dart';

const _long =
    'O governo anunciou nesta terça um novo pacote de medidas para reduzir o preço da energia elétrica no país.';

NewsItem _item({String summary = 'Resumo do feed. Segunda frase do feed.'}) => NewsItem(
  id: 'n1',
  sourceId: 's',
  sourceName: 'Fonte',
  topic: Topic.brasil,
  title: 'Governo anuncia pacote para energia',
  summary: summary,
  link: 'https://example.com/materia',
  date: DateTime(2026, 11, 3),
);

void main() {
  group('extração', () {
    test('usa o articleBody do JSON-LD, inclusive dentro de @graph', () {
      final body = List.filled(6, _long).join('\n');
      final page =
          '<html><head><script type="application/ld+json">'
          '${jsonEncode({
            '@graph': [
              {'@type': 'WebSite'},
              {'@type': 'NewsArticle', 'articleBody': body},
            ],
          })}</script></head><body><p>Texto de menu que não deve aparecer no resultado final da página.</p></body></html>';
      final out = extractParagraphs(page);
      expect(out.length, 6);
      expect(out.first, _long);
    });

    test('acha o bloco principal quando cada parágrafo tem o próprio embrulho (g1)', () {
      final blocks = List.generate(
        5,
        (i) => '<div><div class="content-text"><p>Parágrafo $i. $_long</p></div></div>',
      ).join();
      final page =
          '<html><body><div class="menu"><p>Assine agora a nossa revista com um preço especial neste mês.</p></div>'
          '<article>$blocks</article></body></html>';
      final out = extractParagraphs(page);
      expect(out.length, 5);
      expect(out.first, startsWith('Parágrafo 0'));
    });

    test('classe genérica no bloco principal não apaga a matéria (paywall, share)', () {
      final ps = List.generate(6, (i) => '<p>Parágrafo $i. $_long</p>').join();
      final page =
          '<html><body><div class="container j-paywall -share-parent">$ps'
          '<div class="c-tools-share"><p>Compartilhe esta reportagem com os seus amigos nas redes.</p></div></div></body></html>';
      final out = extractParagraphs(page);
      expect(out.length, 6);
      expect(out.any((p) => p.contains('Compartilhe')), isFalse);
    });

    test('remove legendas, relacionadas, blocos ocultos e chamadas', () {
      final ps = List.generate(4, (i) => '<p>Parágrafo $i. $_long</p>').join();
      final page =
          '<html><body><article>$ps<p>Leia também: outra notícia qualquer sobre este mesmo assunto aqui.</p>'
          '<p class="content-media__description">Legenda longa de uma foto que não faz parte do texto corrido.</p>'
          '<div class="is-hidden"><p>Popup oculto que também não pode entrar no resumo da matéria.</p></div>'
          '<div class="related-news"><p>Matéria relacionada que não pode entrar no resumo desta matéria.</p></div>'
          '</article></body></html>';
      expect(extractParagraphs(page).length, 4);
    });

    test('charset latin1 declarado na meta', () {
      final bytes = latin1.encode('<html><head><meta charset="iso-8859-1"></head><body>ação</body></html>');
      expect(decodeHtmlBytes(bytes), contains('ação'));
    });

    test('tira espaço antes da pontuação', () {
      final ps = '<p>O aparelho Galaxy A58 chega ao mercado em breve , segundo vazamentos recentes .</p>' * 3;
      expect(extractParagraphs('<html><body><div>$ps</div></body></html>').first, endsWith('recentes.'));
    });
  });

  group('frases', () {
    test('não quebra em abreviações, decimais e siglas', () {
      expect(splitSentences('O Dr. Silva pagou R\$ 3,50 ao ministro. A U.S. Steel subiu 1.5 ponto! Depois caiu.'), [
        'O Dr. Silva pagou R\$ 3,50 ao ministro.',
        'A U.S. Steel subiu 1.5 ponto!',
        'Depois caiu.',
      ]);
    });
  });

  group('resumo', () {
    final paragraphs = [
      'O governo anunciou um pacote para reduzir o preço da energia elétrica em todo o país nesta semana.',
      'Adversário: Corinthians, na Vila Belmiro.',
      'O pacote prevê corte de impostos sobre a energia e deve baratear a conta de luz das famílias.',
      'Você sabe quanto paga de energia elétrica todos os meses na sua conta de luz?',
      'Segundo o ministro Alexandre Silveira, o pacote de energia começa a valer em janeiro para todos os consumidores.',
      'Alexandre Silveira disse ainda que a redução da conta de energia será gradual ao longo dos próximos meses.',
      'Em outro assunto, a chuva atrapalhou o trânsito da capital durante a tarde desta quarta-feira passada.',
      '"Foi uma decisão difícil para todos nós do ministério, e ainda vamos discutir mais detalhes.',
    ];

    test('escolhe frases centrais, mantém a ordem e ignora ruído', () {
      final points = pickPoints('Governo anuncia pacote para energia', paragraphs);
      expect(points.length, inInclusiveRange(2, 4));
      expect(points.first, paragraphs.first);
      expect(points.any((p) => p.contains('Adversário')), isFalse);
      expect(points.any((p) => p.endsWith('?')), isFalse);
      expect(points.any((p) => p.startsWith('"')), isFalse);
      final indexes = points.map(paragraphs.indexOf).toList();
      expect(indexes, [...indexes]..sort());
    });

    test('não repete frases quase iguais', () {
      const a = 'O pacote de energia reduz o preço da conta de luz para todas as famílias do país.';
      const b = 'O pacote de energia reduz o preço da conta de luz para todas as famílias brasileiras.';
      final points = pickPoints('Pacote de energia', [
        a,
        b,
        'Outra informação relevante sobre economia nacional foi divulgada hoje cedo.',
      ]);
      expect(points.contains(a) && points.contains(b), isFalse);
    });

    test('assuntos priorizam nomes próprios e mantêm os acentos', () {
      final topics = pickTopics('Alexandre Silveira anuncia pacote', paragraphs);
      expect(topics.first, 'Alexandre Silveira');
      final words = pickTopics('sem nomes aqui', [
        'a solução da região e a solução da nação, com solução para a região e a região.',
      ]);
      expect(words, contains('Solução'));
      expect(words, contains('Região'));
    });

    test('com texto insuficiente usa o resumo do feed', () {
      final s = summarize(_item(), ['Curto demais.']);
      expect(s.fromArticle, isFalse);
      expect(s.points, ['Resumo do feed.', 'Segunda frase do feed.']);
    });

    test('com a matéria lida marca como vindo do artigo', () {
      final s = summarize(_item(), paragraphs);
      expect(s.fromArticle, isTrue);
      expect(s.points, isNotEmpty);
    });
  });

  group('tela', () {
    late NewsStore store;

    setUp(() {
      JsonStore.directory = Directory.systemTemp.createTempSync('news');
      store = NewsStore(SettingsStore());
    });

    Widget wrap(Widget child) => ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(theme: AppTheme.dark(), home: child),
    );

    testWidgets('tocar no card abre o resumo dentro do app', (tester) async {
      await tester.pumpWidget(wrap(Scaffold(body: NewsCard(item: _item()))));
      await tester.tap(find.text('Governo anuncia pacote para energia'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(NewsReaderPage), findsOneWidget);
      expect(find.text('Ler matéria completa'), findsOneWidget);
    });

    testWidgets('mostra pontos, assuntos e botão da matéria completa', (tester) async {
      Future<ArticleSummary> loader(NewsItem _) async => const ArticleSummary(
        points: ['Primeiro ponto da matéria.', 'Segundo ponto da matéria.'],
        topics: ['Energia', 'Alexandre Silveira'],
        fromArticle: true,
      );
      await tester.pumpWidget(wrap(NewsReaderPage(item: _item(), loader: loader)));
      await tester.pumpAndSettle();
      expect(find.text('Principais pontos'), findsOneWidget);
      expect(find.text('Primeiro ponto da matéria.'), findsOneWidget);
      expect(find.text('Alexandre Silveira'), findsOneWidget);
      expect(find.text('Ler matéria completa'), findsOneWidget);
      expect(find.textContaining('frases selecionadas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('avisa quando o site não permitiu ler a matéria', (tester) async {
      Future<ArticleSummary> loader(NewsItem _) async =>
          const ArticleSummary(points: ['Resumo do feed.'], topics: [], fromArticle: false);
      await tester.pumpWidget(wrap(NewsReaderPage(item: _item(), loader: loader)));
      await tester.pumpAndSettle();
      expect(find.textContaining('não permitiu ler'), findsOneWidget);
    });
  });
}
