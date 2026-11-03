import 'dart:convert';
import 'dart:math';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../core/net.dart';
import '../core/text_norm.dart';
import 'rss.dart';

/// Resumo feito no próprio aparelho: escolhe as frases mais importantes do texto
/// da matéria (sem IA nem serviço externo, as frases são as originais).
class ArticleSummary {
  final List<String> points;
  final List<String> topics;

  /// false quando não deu para ler a matéria e o resumo veio só do feed.
  final bool fromArticle;

  const ArticleSummary({required this.points, required this.topics, required this.fromArticle});
}

const _minArticleChars = 400;

final _noiseAttr = RegExp(
  r'comment|coment|related|relacionad|share|compartilh|social|newsletter|sidebar|promo|publicidade|advert|\bads?\b|'
  r'leia-?(tambem|mais)|veja-?(tambem|mais)|saiba-?mais|recomend|breadcrumb|cookie|author-bio|caption|legenda|'
  r'media__description|is-hidden|\bhidden\b',
  caseSensitive: false,
);

final _noiseText = RegExp(
  r'^(leia (também|mais)|veja (também|mais|o vídeo)|saiba mais|assista|siga o|siga a|inscreva-se|clique aqui|'
  r'assine|receba|baixe o|📱|👉|foto:|imagem:|crédito:|reportagem:|edição:|publicidade)|'
  r'whatsapp|telegram|todos os direitos|newsletter',
  caseSensitive: false,
);

const _protected = {'html', 'body', 'main', 'article'};

String _clean(String s) =>
    s.replaceAll(RegExp(r'\s+'), ' ').replaceAllMapped(RegExp(r' +([.,;:!?])(?=\s|$)'), (m) => m.group(1)!).trim();

/// Decodifica a página respeitando o charset do cabeçalho ou da tag meta.
String decodeHtmlBytes(List<int> bytes, {String? contentType}) {
  final head = latin1.decode(bytes.length > 2048 ? bytes.sublist(0, 2048) : bytes).toLowerCase();
  final declared =
      RegExp(r'charset=["\x27]?([\w-]+)').firstMatch(contentType?.toLowerCase() ?? '')?.group(1) ??
      RegExp(r'charset=["\x27]?([\w-]+)').firstMatch(head)?.group(1);
  if (declared != null && (declared.contains('8859') || declared.contains('latin') || declared.contains('1252'))) {
    return latin1.decode(bytes, allowInvalid: true);
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String? _findArticleBody(dynamic node) {
  if (node is List) {
    for (final e in node) {
      final r = _findArticleBody(e);
      if (r != null) return r;
    }
  } else if (node is Map) {
    final body = node['articleBody'];
    if (body is String && body.trim().isNotEmpty) return body;
    final graph = node['@graph'];
    if (graph != null) return _findArticleBody(graph);
    final main = node['mainEntity'] ?? node['mainEntityOfPage'];
    if (main is Map) return _findArticleBody(main);
  }
  return null;
}

int _longParagraphs(Element e) => e.querySelectorAll('p').where((p) => _clean(p.text).length >= 40).length;

/// Parágrafos da matéria: primeiro os dados estruturados da página (JSON-LD);
/// se não houver, o bloco com mais texto em parágrafos.
List<String> extractParagraphs(String page) {
  final doc = html_parser.parse(page);

  for (final s in doc.querySelectorAll('script[type="application/ld+json"]')) {
    try {
      final body = _findArticleBody(jsonDecode(s.text));
      if (body == null) continue;
      // Quebras de linha e tags de parágrafo separam os blocos, que o htmlToText juntaria.
      final blocks = body.split(RegExp(r'\n+|</p>|<br\s*/?>', caseSensitive: false));
      final parts = blocks.map((b) => _clean(htmlToText(b))).where((p) => p.isNotEmpty).toList();
      if (parts.fold<int>(0, (n, p) => n + p.length) < _minArticleChars) continue;
      return parts.where((p) => !_noiseText.hasMatch(p)).toList();
    } catch (_) {}
  }

  for (final e in doc.querySelectorAll('script,style,noscript,nav,header,footer,aside,form,figure,iframe,button,svg')) {
    e.remove();
  }
  final totalParagraphs = _longParagraphs(doc.documentElement!);
  for (final e in doc.querySelectorAll('[class],[id]')) {
    if (_protected.contains(e.localName)) continue;
    if (!_noiseAttr.hasMatch('${e.className} ${e.id}')) continue;
    // Classe genérica no bloco principal não é ruído: ele concentra a maior parte do texto.
    if (_longParagraphs(e) * 2 > totalParagraphs) continue;
    e.remove();
  }

  final scores = <Element, int>{};
  for (final p in doc.querySelectorAll('p')) {
    final len = _clean(p.text).length;
    if (len < 40) continue;
    // Sites como o g1 embrulham cada parágrafo em blocos próprios: o texto também conta para os ancestrais.
    var node = p.parent;
    for (var level = 1; node != null && level <= 4; level++) {
      scores[node] = (scores[node] ?? 0) + len ~/ level;
      node = node.parent;
    }
  }
  if (scores.isEmpty) return [];
  final best = scores.entries.reduce((a, b) => b.value > a.value ? b : a).key;

  final out = <String>[];
  for (final p in best.querySelectorAll('p')) {
    final text = _clean(p.text);
    if (text.length < 40 || _noiseText.hasMatch(text)) continue;
    final linked = p.querySelectorAll('a').fold<int>(0, (s, a) => s + _clean(a.text).length);
    if (linked > text.length / 2) continue;
    out.add(text);
  }
  return out;
}

const _abbrev = {
  'sr',
  'sra',
  'srs',
  'dr',
  'dra',
  'prof',
  'profa',
  'gov',
  'pres',
  'dep',
  'sen',
  'min',
  'av',
  'art',
  'etc',
  'nº',
  'n',
  'p',
  'ex',
  'vs',
  'cia',
  'ltda',
  'jr',
  'st',
  'mr',
  'mrs',
};

/// Divide em frases sem quebrar em abreviações, decimais e siglas.
List<String> splitSentences(String text) {
  final out = <String>[];
  var start = 0;
  for (final m in RegExp(r'[.!?…]+["”’»)]*\s+(?=["“‘«(]?[A-ZÀ-Ú0-9])').allMatches(text)) {
    final before = text.substring(start, m.start);
    final last = before.split(RegExp(r'\s+')).last.toLowerCase();
    // Abreviação, inicial ou sigla com pontos ("U.S.").
    if (text[m.start] == '.' && (_abbrev.contains(last) || RegExp(r'^([a-zà-ú]\.)*[a-zà-ú]$').hasMatch(last))) continue;
    out.add(text.substring(start, m.end).trim());
    start = m.end;
  }
  final rest = text.substring(start).trim();
  if (rest.isNotEmpty) out.add(rest);
  return out;
}

const _stop = {
  'a',
  'o',
  'as',
  'os',
  'um',
  'uma',
  'uns',
  'umas',
  'de',
  'do',
  'da',
  'dos',
  'das',
  'em',
  'no',
  'na',
  'nos',
  'nas',
  'por',
  'pelo',
  'pela',
  'pelos',
  'pelas',
  'para',
  'pra',
  'com',
  'sem',
  'sob',
  'sobre',
  'entre',
  'ate',
  'apos',
  'desde',
  'contra',
  'ao',
  'aos',
  'e',
  'ou',
  'mas',
  'que',
  'se',
  'como',
  'quando',
  'onde',
  'porque',
  'pois',
  'porem',
  'embora',
  'nao',
  'sim',
  'ja',
  'ainda',
  'tambem',
  'so',
  'mais',
  'menos',
  'muito',
  'muita',
  'muitos',
  'muitas',
  'pouco',
  'bem',
  'mal',
  'ser',
  'ter',
  'estar',
  'foi',
  'foram',
  'era',
  'eram',
  'sao',
  'sera',
  'serao',
  'seria',
  'esta',
  'estao',
  'estava',
  'tem',
  'tinha',
  'tiveram',
  'teve',
  'ha',
  'havia',
  'fazer',
  'faz',
  'fez',
  'disse',
  'diz',
  'afirmou',
  'segundo',
  'ele',
  'ela',
  'eles',
  'elas',
  'seu',
  'sua',
  'seus',
  'suas',
  'dele',
  'dela',
  'deles',
  'delas',
  'este',
  'esse',
  'isso',
  'isto',
  'essa',
  'essas',
  'esses',
  'estes',
  'estas',
  'aquele',
  'aquela',
  'aquilo',
  'nesta',
  'neste',
  'nessa',
  'nesse',
  'cada',
  'todo',
  'toda',
  'todos',
  'todas',
  'outro',
  'outra',
  'outros',
  'outras',
  'mesmo',
  'mesma',
  'qual',
  'quais',
  'quem',
  'lhe',
  'sendo',
  'pode',
  'podem',
  'deve',
  'devem',
  'vai',
  'vao',
  'ano',
  'anos',
  'dia',
  'dias',
  'hoje',
  'ontem',
  'amanha',
  'agora',
  'assim',
  'entao',
  'alem',
  'durante',
  'antes',
  'depois',
  'num',
  'numa',
  'seja',
  'sejam',
  'the',
  'of',
  'and',
  'in',
  'to',
  'for',
  'segunda',
  'terca',
  'quarta',
  'quinta',
  'sexta',
  'sabado',
  'domingo',
  'feira',
  'janeiro',
  'fevereiro',
  'marco',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
  'brasil',
};

List<String> _tokens(String s) =>
    RegExp(r'[a-z0-9]+')
        .allMatches(normalizeKeepLength(s))
        .map((m) => m.group(0)!)
        .where((w) => w.length > 2 && !_stop.contains(w))
        .toList();

double _overlap(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  return a.intersection(b).length / min(a.length, b.length);
}

/// Descarta títulos intermediários, fichas ("Adversário: Corinthians") e citações cortadas.
bool _isCompleteSentence(String s) {
  if (!RegExp(r'[.!…]["”’»)]*$').hasMatch(s)) return false;
  if (RegExp(r'^[^\s:]+(\s+[^\s:]+){0,3}:\s').hasMatch(s)) return false;
  if ('"'.allMatches(s).length.isOdd) return false;
  return '“'.allMatches(s).length == '”'.allMatches(s).length;
}

/// Pontos principais: frases com as palavras mais frequentes do texto e do título,
/// favorecendo o início da matéria e evitando frases repetidas. Mantém a ordem original.
List<String> pickPoints(String title, List<String> paragraphs, {int? maxPoints}) {
  final freq = <String, int>{};
  final titleWords = _tokens(title).toSet();
  final sentences = <(String, int)>[];
  var total = 0;
  for (final p in paragraphs) {
    total += p.length;
    for (final s in splitSentences(p)) {
      sentences.add((s, sentences.length));
      for (final w in _tokens(s)) {
        freq[w] = (freq[w] ?? 0) + 1;
      }
    }
  }
  if (sentences.isEmpty) return [];
  final maxFreq = freq.values.fold<int>(1, max);
  final n = maxPoints ?? (total < 1200 ? 3 : (total < 3500 ? 4 : 5));

  final scored = <(String, int, double, Set<String>)>[];
  for (final (s, i) in sentences) {
    if (s.length < 40 || s.length > 340 || !_isCompleteSentence(s) || _noiseText.hasMatch(s)) continue;
    final words = _tokens(s);
    if (words.length < 4) continue;
    final set = words.toSet();
    var score = set.fold<double>(0, (v, w) => v + (freq[w] ?? 0) / maxFreq) / sqrt(words.length);
    score += 0.35 * _overlap(set, titleWords);
    score *= 1 + 0.6 / (1 + i / 2);
    scored.add((s, i, score, set));
  }
  scored.sort((a, b) => b.$3.compareTo(a.$3));

  final chosen = <(String, int, double, Set<String>)>[];
  for (final c in scored) {
    if (chosen.length >= n) break;
    if (titleWords.length >= 4 && _overlap(c.$4, titleWords) > 0.85 && c.$4.length <= titleWords.length + 1) continue;
    if (chosen.any((o) => _overlap(o.$4, c.$4) > 0.6)) continue;
    chosen.add(c);
  }
  chosen.sort((a, b) => a.$2.compareTo(b.$2));
  return chosen.map((c) => c.$1).toList();
}

/// Assuntos: nomes próprios citados (pessoas, empresas, lugares) e, para completar,
/// as palavras mais repetidas.
List<String> pickTopics(String title, List<String> paragraphs, {int limit = 6}) {
  final counts = <String, int>{};
  final display = <String, String>{};
  final name = RegExp(r"\b[A-ZÀ-Ú][\wÀ-ú'’-]+(?:\s+(?:(?:de|do|da|dos|das)\s+)?[A-ZÀ-Ú][\wÀ-ú'’-]+)*");
  for (final text in [title, ...paragraphs]) {
    for (final sentence in splitSentences(text)) {
      for (final m in name.allMatches(sentence)) {
        final raw = m.group(0)!;
        final key = normalizeKeepLength(raw);
        final words = _tokens(raw);
        if (words.isEmpty) continue;
        // Palavra única no começo da frase costuma ser só maiúscula de início de frase.
        if (m.start == 0 && !raw.contains(' ') && text != title) continue;
        if (!raw.contains(' ') && _stop.contains(key)) continue;
        counts[key] = (counts[key] ?? 0) + (text == title ? 2 : 1);
        display[key] ??= raw;
      }
    }
  }
  final names = counts.entries.where((e) => e.value >= 2).toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : b.key.length.compareTo(a.key.length);
    });

  final out = <String>[];
  bool covered(String key) => out.any((o) {
    final k = normalizeKeepLength(o);
    return k == key || k.contains(key) || key.contains(k);
  });
  for (final e in names) {
    if (out.length >= limit) break;
    if (!covered(e.key)) out.add(display[e.key]!);
  }

  if (out.length < 3) {
    final freq = <String, int>{};
    final accented = <String, String>{};
    for (final p in paragraphs) {
      for (final m in RegExp(r'[a-zA-ZÀ-ú]+').allMatches(p)) {
        final word = m.group(0)!;
        final key = normalizeKeepLength(word);
        // Terminações comuns de verbos não servem como assunto.
        if (key.length <= 3 || _stop.contains(key) || RegExp(r'(ria|riam|ram|ndo|ava|avam|isa)$').hasMatch(key)) {
          continue;
        }
        freq[key] = (freq[key] ?? 0) + 1;
        accented[key] ??= word.toLowerCase();
      }
    }
    final words = freq.entries.where((e) => e.value >= 3 && e.key.length > 3).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in words) {
      if (out.length >= 5) break;
      if (covered(e.key)) continue;
      final word = accented[e.key]!;
      out.add(word[0].toUpperCase() + word.substring(1));
    }
  }
  return out;
}

ArticleSummary summarize(NewsItem item, List<String> paragraphs) {
  final chars = paragraphs.fold<int>(0, (s, p) => s + p.length);
  if (chars >= _minArticleChars) {
    final points = pickPoints(item.title, paragraphs);
    if (points.isNotEmpty) {
      return ArticleSummary(points: points, topics: pickTopics(item.title, paragraphs), fromArticle: true);
    }
  }
  final feed = _clean(item.summary);
  final points = feed.isEmpty ? <String>[] : splitSentences(feed);
  return ArticleSummary(
    points: points,
    topics: pickTopics(item.title, [if (feed.isNotEmpty) feed]),
    fromArticle: false,
  );
}

class ArticleService {
  static final Map<String, ArticleSummary> _cache = {};

  /// Nunca lança: sem internet ou sem acesso à matéria, resume o texto do feed.
  static Future<ArticleSummary> load(NewsItem item) async {
    final cached = _cache[item.id];
    if (cached != null) return cached;
    var paragraphs = <String>[];
    var ok = false;
    try {
      final r = await Net.get(item.link);
      if (r.statusCode == 200) {
        paragraphs = extractParagraphs(decodeHtmlBytes(r.bodyBytes, contentType: r.headers['content-type']));
        ok = true;
      }
    } catch (_) {}
    final s = summarize(item, paragraphs);
    if (ok) {
      if (_cache.length > 100) _cache.clear();
      _cache[item.id] = s;
    }
    return s;
  }
}
