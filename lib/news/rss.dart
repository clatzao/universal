import 'dart:convert';

import 'package:xml/xml.dart';

enum Topic {
  tecnologia('Tecnologia'),
  games('Games'),
  economia('Economia'),
  brasil('Brasil e política'),
  esportes('Esportes');

  final String label;

  const Topic(this.label);

  static Topic of(String? n) => Topic.values.firstWhere((t) => t.name == n, orElse: () => Topic.brasil);
}

class NewsSource {
  final String id;
  final String name;
  final String url;
  final Topic topic;

  const NewsSource(this.id, this.name, this.url, this.topic);
}

class NewsItem {
  final String id;
  final String sourceId;
  final String sourceName;
  final Topic topic;
  final String title;
  final String summary;
  final String link;
  final String? image;
  final DateTime date;

  const NewsItem({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.topic,
    required this.title,
    required this.summary,
    required this.link,
    this.image,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceId': sourceId,
        'sourceName': sourceName,
        'topic': topic.name,
        'title': title,
        'summary': summary,
        'link': link,
        'image': image,
        'date': date.toIso8601String(),
      };

  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
        id: j['id'] as String,
        sourceId: j['sourceId'] as String,
        sourceName: j['sourceName'] as String,
        topic: Topic.of(j['topic'] as String?),
        title: j['title'] as String,
        summary: (j['summary'] as String?) ?? '',
        link: j['link'] as String,
        image: j['image'] as String?,
        date: DateTime.parse(j['date'] as String),
      );
}

const _latin1Names = [
  'nbsp', 'iexcl', 'cent', 'pound', 'curren', 'yen', 'brvbar', 'sect', 'uml', 'copy', 'ordf', 'laquo', 'not', 'shy',
  'reg', 'macr', 'deg', 'plusmn', 'sup2', 'sup3', 'acute', 'micro', 'para', 'middot', 'cedil', 'sup1', 'ordm', 'raquo',
  'frac14', 'frac12', 'frac34', 'iquest', 'Agrave', 'Aacute', 'Acirc', 'Atilde', 'Auml', 'Aring', 'AElig', 'Ccedil',
  'Egrave', 'Eacute', 'Ecirc', 'Euml', 'Igrave', 'Iacute', 'Icirc', 'Iuml', 'ETH', 'Ntilde', 'Ograve', 'Oacute', 'Ocirc',
  'Otilde', 'Ouml', 'times', 'Oslash', 'Ugrave', 'Uacute', 'Ucirc', 'Uuml', 'Yacute', 'THORN', 'szlig', 'agrave',
  'aacute', 'acirc', 'atilde', 'auml', 'aring', 'aelig', 'ccedil', 'egrave', 'eacute', 'ecirc', 'euml', 'igrave',
  'iacute', 'icirc', 'iuml', 'eth', 'ntilde', 'ograve', 'oacute', 'ocirc', 'otilde', 'ouml', 'divide', 'oslash',
  'ugrave', 'uacute', 'ucirc', 'uuml', 'yacute', 'thorn', 'yuml',
];

final Map<String, int> htmlEntities = {
  for (var i = 0; i < _latin1Names.length; i++) _latin1Names[i]: 160 + i,
  'amp': 38, 'lt': 60, 'gt': 62, 'quot': 34, 'apos': 39,
  'ndash': 0x2013, 'mdash': 0x2014, 'lsquo': 0x2018, 'rsquo': 0x2019, 'sbquo': 0x201A, 'ldquo': 0x201C,
  'rdquo': 0x201D, 'bdquo': 0x201E, 'hellip': 0x2026, 'bull': 0x2022, 'euro': 0x20AC, 'trade': 0x2122,
  'dagger': 0x2020, 'Dagger': 0x2021, 'prime': 0x2032, 'OElig': 0x152, 'oelig': 0x153, 'Scaron': 0x160,
  'scaron': 0x161, 'thinsp': 0x2009, 'ensp': 0x2002, 'emsp': 0x2003, 'zwnj': 0x200C, 'zwj': 0x200D,
  'lrm': 0x200E, 'rlm': 0x200F, 'rarr': 0x2192, 'larr': 0x2190,
};

const _xmlEntities = {'amp', 'lt', 'gt', 'quot', 'apos'};

/// Converte entidades HTML (como &iacute;) em referências numéricas, que o
/// parser XML aceita, e escapa "&" soltos.
String prepareXml(String s) {
  return s.replaceAllMapped(RegExp(r'&(#?[a-zA-Z0-9]+;)?'), (m) {
    final ent = m.group(1);
    if (ent == null) return '&amp;';
    final name = ent.substring(0, ent.length - 1);
    if (name.startsWith('#') || _xmlEntities.contains(name)) return m.group(0)!;
    final code = htmlEntities[name];
    return code == null ? '&amp;$ent' : '&#$code;';
  });
}

/// Decodifica entidades HTML num texto.
String decodeEntities(String s) => s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z][a-zA-Z0-9]*);'), (m) {
      final e = m.group(1)!;
      int? code;
      if (e.startsWith('#x') || e.startsWith('#X')) {
        code = int.tryParse(e.substring(2), radix: 16);
      } else if (e.startsWith('#')) {
        code = int.tryParse(e.substring(1));
      } else {
        code = htmlEntities[e];
      }
      if (code == null || code > 0x10FFFF) return m.group(0)!;
      return String.fromCharCode(code);
    });

String htmlToText(String html) {
  var s = html.replaceAll(RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false), ' ');
  s = s.replaceAll(RegExp(r'<br\s*/?>|</p>', caseSensitive: false), ' ');
  s = s.replaceAll(RegExp(r'<[^>]*>'), ' ');
  s = decodeEntities(decodeEntities(s));
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Decodifica os bytes respeitando ISO-8859-1/Windows-1252 quando declarado.
String decodeBytes(List<int> bytes, {String? contentType}) {
  var b = bytes;
  if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) b = b.sublist(3);
  final head = latin1.decode(b.length > 200 ? b.sublist(0, 200) : b).toLowerCase();
  final declared = RegExp(r'encoding="([^"]+)"').firstMatch(head)?.group(1) ??
      RegExp(r"encoding='([^']+)'").firstMatch(head)?.group(1) ??
      RegExp(r'charset=([\w-]+)').firstMatch(contentType?.toLowerCase() ?? '')?.group(1);
  if (declared != null && (declared.contains('8859') || declared.contains('latin') || declared.contains('1252'))) {
    return latin1.decode(b, allowInvalid: true);
  }
  return utf8.decode(b, allowMalformed: true);
}

const _months = {
  'jan': 1, 'feb': 2, 'fev': 2, 'mar': 3, 'apr': 4, 'abr': 4, 'may': 5, 'mai': 5, 'jun': 6, 'jul': 7,
  'aug': 8, 'ago': 8, 'sep': 9, 'set': 9, 'oct': 10, 'out': 10, 'nov': 11, 'dec': 12, 'dez': 12,
};

const _zones = {
  'gmt': 0, 'ut': 0, 'utc': 0, 'z': 0, 'est': -5, 'edt': -4, 'cst': -6, 'cdt': -5, 'mst': -7, 'mdt': -6,
  'pst': -8, 'pdt': -7, 'brt': -3, 'brst': -2, 'bst': 1, 'cet': 1, 'cest': 2,
};

/// Datas RFC 822 ("Wed, 29 Oct 2026 10:00:00 -0300") e ISO 8601.
DateTime? parseFeedDate(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;
  final m = RegExp(r'(\d{1,2})\s+([A-Za-z]{3})[A-Za-z]*\.?\s+(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{2}:?\d{2}|[A-Za-z]{1,5})?')
      .firstMatch(s);
  if (m != null) {
    final month = _months[m.group(2)!.toLowerCase()];
    if (month != null) {
      var year = int.parse(m.group(3)!);
      if (year < 100) year += 2000;
      final utc = DateTime.utc(year, month, int.parse(m.group(1)!), int.parse(m.group(4)!), int.parse(m.group(5)!),
          int.tryParse(m.group(6) ?? '') ?? 0);
      final z = m.group(7);
      var offsetMin = 0;
      if (z != null) {
        if (z.startsWith('+') || z.startsWith('-')) {
          final digits = z.replaceAll(':', '');
          final sign = z.startsWith('-') ? -1 : 1;
          offsetMin = sign * (int.parse(digits.substring(1, 3)) * 60 + int.parse(digits.substring(3, 5)));
        } else {
          offsetMin = (_zones[z.toLowerCase()] ?? 0) * 60;
        }
      }
      return utc.subtract(Duration(minutes: offsetMin));
    }
  }
  return DateTime.tryParse(s)?.toUtc();
}

Iterable<XmlElement> _children(XmlElement e, String local) => e.childElements.where((c) => c.name.local == local);

String? _text(XmlElement e, List<String> names) {
  for (final n in names) {
    for (final c in _children(e, n)) {
      final t = c.innerText.trim();
      if (t.isNotEmpty) return t;
    }
  }
  return null;
}

String? _image(XmlElement item, String html) {
  for (final c in item.childElements) {
    final local = c.name.local;
    final url = c.getAttribute('url');
    if (url == null || url.isEmpty) continue;
    final type = c.getAttribute('type') ?? '';
    final medium = c.getAttribute('medium') ?? '';
    if (local == 'thumbnail') return url;
    if (local == 'content' && (medium == 'image' || type.startsWith('image') || RegExp(r'\.(jpe?g|png|webp|gif)', caseSensitive: false).hasMatch(url))) {
      return url;
    }
    if (local == 'enclosure' && (type.startsWith('image') || RegExp(r'\.(jpe?g|png|webp)', caseSensitive: false).hasMatch(url))) {
      return url;
    }
  }
  for (final g in _children(item, 'group')) {
    final img = _image(g, '');
    if (img != null) return img;
  }
  final m = RegExp(r'''<img[^>]+src=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
  return m == null ? null : decodeEntities(m.group(1)!);
}

/// Lê um feed RSS 2.0 / 0.91 ou Atom.
List<NewsItem> parseFeed(String xmlText, NewsSource src, {DateTime? now}) {
  final clock = (now ?? DateTime.now()).toUtc();
  final doc = XmlDocument.parse(prepareXml(xmlText));
  final out = <NewsItem>[];
  final entries = doc.descendants.whereType<XmlElement>().where((e) => e.name.local == 'item' || e.name.local == 'entry');
  for (final it in entries) {
    final title = htmlToText(_text(it, ['title']) ?? '');
    if (title.isEmpty) continue;
    var link = _text(it, ['link']) ?? '';
    if (link.isEmpty) {
      final links = _children(it, 'link').toList();
      final alt = links.where((l) => (l.getAttribute('rel') ?? 'alternate') == 'alternate').firstOrNull ?? links.firstOrNull;
      link = alt?.getAttribute('href') ?? '';
    }
    if (link.isEmpty) link = _text(it, ['guid', 'id']) ?? '';
    link = decodeEntities(link.trim());
    final rawHtml = _text(it, ['description', 'summary', 'encoded', 'content']) ?? '';
    var summary = htmlToText(rawHtml);
    if (summary.length > 280) summary = '${summary.substring(0, 277).trimRight()}…';
    var date = parseFeedDate(_text(it, ['pubDate', 'date', 'published', 'updated', 'issued'])) ?? clock;
    // Algumas fontes (ex.: ESPN) publicam horário no futuro.
    if (date.isAfter(clock)) date = clock;
    final encoded = _text(it, ['encoded']) ?? '';
    out.add(NewsItem(
      id: link.isNotEmpty ? link : '${src.id}:$title',
      sourceId: src.id,
      sourceName: src.name,
      topic: src.topic,
      title: title,
      summary: summary == title ? '' : summary,
      link: link,
      image: _image(it, '$rawHtml $encoded'),
      date: date.toLocal(),
    ));
  }
  return out;
}
