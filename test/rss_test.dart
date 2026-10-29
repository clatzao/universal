import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal/news/rss.dart';

void main() {
  const src = NewsSource('t', 'Teste', 'https://x', Topic.tecnologia);
  final now = DateTime.utc(2026, 10, 29, 13);

  test('RSS 2.0 com entidades HTML, CDATA e imagem', () {
    const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/"><channel>
<item><title>Not&iacute;cia &amp; an&aacute;lise</title><link>https://a.com/1?x=1&y=2</link>
<description><![CDATA[<p>Resumo com <b>negrito</b> &ccedil;</p><img src="https://img/1.jpg">]]></description>
<pubDate>Wed, 29 Oct 2026 09:30:00 -0300</pubDate></item>
<item><title>Segunda</title><link>https://a.com/2</link><media:content url="https://img/2.png" medium="image"/>
<pubDate>Wed, 29 Oct 2026 12:00:00 GMT</pubDate></item>
</channel></rss>''';
    final items = parseFeed(xml, src, now: now);
    expect(items.length, 2);
    expect(items[0].title, 'Notícia & análise');
    expect(items[0].link, 'https://a.com/1?x=1&y=2');
    expect(items[0].summary, 'Resumo com negrito ç');
    expect(items[0].image, 'https://img/1.jpg');
    expect(items[0].date.toUtc(), DateTime.utc(2026, 10, 29, 12, 30));
    expect(items[1].image, 'https://img/2.png');
  });

  test('Atom', () {
    const xml = '''<feed xmlns="http://www.w3.org/2005/Atom">
<entry><title>Atom 1</title><link rel="alternate" href="https://b.com/1"/><summary>Oi</summary>
<updated>2026-10-29T08:00:00-03:00</updated></entry></feed>''';
    final items = parseFeed(xml, src, now: now);
    expect(items.single.link, 'https://b.com/1');
    expect(items.single.date.toUtc(), DateTime.utc(2026, 10, 29, 11));
  });

  test('ISO-8859-1', () {
    final bytes = latin1.encode('<?xml version="1.0" encoding="ISO-8859-1"?><rss><channel><item><title>Ação</title>'
        '<link>https://c/1</link></item></channel></rss>');
    final items = parseFeed(decodeBytes(bytes), src, now: now);
    expect(items.single.title, 'Ação');
  });

  test('data no futuro é limitada ao horário atual', () {
    const xml = '<rss><channel><item><title>F</title><link>https://d/1</link>'
        '<pubDate>Fri, 30 Oct 2026 20:00:00 -0300</pubDate></item></channel></rss>';
    expect(parseFeed(xml, src, now: now).single.date.toUtc(), now);
  });

  test('datas RFC 822 com fuso', () {
    expect(parseFeedDate('Thu, 29 Oct 2026 10:00:00 EST'), DateTime.utc(2026, 10, 29, 15));
    expect(parseFeedDate('29 Oct 26 10:00 +0100'), DateTime.utc(2026, 10, 29, 9));
    expect(parseFeedDate('Thu, 29 Oct 2026 10:00:00 BRT'), DateTime.utc(2026, 10, 29, 13));
  });
}
