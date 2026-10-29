import 'package:flutter/foundation.dart';

import '../core/format.dart';
import '../core/json_store.dart';
import '../core/net.dart';

class OnThisDay {
  final int? year;
  final String text;
  final String? url;

  const OnThisDay(this.year, this.text, this.url);

  Map<String, dynamic> toJson() => {'year': year, 'text': text, 'url': url};

  factory OnThisDay.fromJson(Map<String, dynamic> j) =>
      OnThisDay(j['year'] as int?, j['text'] as String, j['url'] as String?);
}

/// "Neste dia" da Wikipédia em português (com cache diário).
class CuriositiesStore extends ChangeNotifier {
  List<OnThisDay> events = [];
  bool loading = false;
  String? error;
  String? _loadedFor;

  Future<void> loadOnThisDay({bool force = false}) async {
    final now = DateTime.now();
    final key = dayKey(now);
    if (!force && _loadedFor == key && events.isNotEmpty) return;
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final cache = await JsonStore.read('onthisday');
      if (!force && cache is Map && cache['day'] == key) {
        events = ((cache['events'] as List?) ?? const [])
            .map((e) => OnThisDay.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      } else {
        final j = await Net.json(
            'https://pt.wikipedia.org/api/rest_v1/feed/onthisday/events/${two(now.month)}/${two(now.day)}') as Map;
        final list = <OnThisDay>[];
        for (final e in (j['events'] as List? ?? const [])) {
          final m = e as Map;
          final pages = (m['pages'] as List?) ?? const [];
          String? url;
          if (pages.isNotEmpty) {
            final urls = (pages.first as Map)['content_urls'] as Map?;
            url = ((urls?['mobile'] ?? urls?['desktop']) as Map?)?['page'] as String?;
          }
          list.add(OnThisDay((m['year'] as num?)?.toInt(), (m['text'] as String?) ?? '', url));
        }
        list.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
        events = list.where((e) => e.text.isNotEmpty).toList();
        await JsonStore.write('onthisday', {'day': key, 'events': events.map((e) => e.toJson()).toList()});
      }
      _loadedFor = key;
    } catch (_) {
      error = 'Não foi possível carregar "Neste dia".';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
