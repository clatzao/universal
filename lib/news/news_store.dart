import 'package:flutter/foundation.dart';

import '../core/json_store.dart';
import '../core/net.dart';
import '../core/text_norm.dart';
import '../notify/notifications.dart';
import '../settings/settings.dart';
import 'rss.dart';
import 'sources.dart';

class NewsService {
  static Future<List<NewsItem>> fetchSource(NewsSource s) async {
    final r = await Net.get(s.url);
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return parseFeed(decodeBytes(r.bodyBytes, contentType: r.headers['content-type']), s);
  }

  /// Busca todas as fontes ativas em paralelo. Fontes com erro são ignoradas.
  static Future<(List<NewsItem>, List<String>)> fetchAll(Set<String> disabled) async {
    final active = newsSources.where((s) => !disabled.contains(s.id)).toList();
    final failed = <String>[];
    final results = await Future.wait(active.map((s) async {
      try {
        return await fetchSource(s);
      } catch (_) {
        failed.add(s.name);
        return <NewsItem>[];
      }
    }));
    final seen = <String>{};
    final all = <NewsItem>[];
    for (final list in results) {
      for (final i in list) {
        if (seen.add(i.id)) all.add(i);
      }
    }
    all.sort((a, b) => b.date.compareTo(a.date));
    return (all, failed);
  }

  /// Alertas por palavra-chave (segundo plano, ~30 min). Na primeira execução
  /// só marca as notícias existentes como vistas.
  static Future<void> checkKeywordAlerts(Settings s, {bool force = false}) async {
    if (!s.keywordAlerts || s.keywords.isEmpty) return;
    final state = (await JsonStore.read('news_alerts') as Map?)?.cast<String, dynamic>() ?? {};
    final last = state['lastRun'] == null ? null : DateTime.tryParse(state['lastRun'] as String);
    final now = DateTime.now();
    if (!force && last != null && now.difference(last).inMinutes < 28) return;
    final initialized = (state['initialized'] as bool?) ?? false;
    final seen = ((state['seen'] as List?) ?? const []).cast<String>().toList();
    final seenSet = seen.toSet();
    final (items, _) = await fetchAll(s.disabledSources);
    final keys = s.keywords.map((k) => normalizeKeepLength(k.trim())).where((k) => k.isNotEmpty).toList();
    var sent = 0;
    for (final i in items) {
      if (seenSet.contains(i.id)) continue;
      seenSet.add(i.id);
      seen.add(i.id);
      if (!initialized || sent >= 5) continue;
      final text = normalizeKeepLength('${i.title} ${i.summary}');
      final hit = keys.where((k) => RegExp('\\b${RegExp.escape(k)}\\b').hasMatch(text)).firstOrNull;
      if (hit == null) continue;
      await Notifications.show(
        id: nidNews * 100 + (i.id.hashCode.abs() % 100),
        title: '${i.sourceName}: "$hit"',
        body: i.title,
        payload: Payload('n', id: i.link),
      );
      sent++;
    }
    final trimmed = seen.length > 3000 ? seen.sublist(seen.length - 3000) : seen;
    await JsonStore.write('news_alerts', {'initialized': true, 'seen': trimmed, 'lastRun': now.toIso8601String()});
  }
}

class NewsStore extends ChangeNotifier {
  final SettingsStore settings;
  List<NewsItem> items = [];
  List<NewsItem> saved = [];
  Set<String> read = {};
  bool loading = false;
  List<String> failed = [];
  DateTime? updatedAt;

  NewsStore(this.settings);

  Future<void> load() async {
    final c = await JsonStore.read('news_cache');
    if (c is Map) {
      items = ((c['items'] as List?) ?? const [])
          .map((e) => NewsItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      updatedAt = c['updatedAt'] == null ? null : DateTime.tryParse(c['updatedAt'] as String);
    }
    final s = await JsonStore.read('news_saved');
    if (s is List) saved = s.map((e) => NewsItem.fromJson((e as Map).cast<String, dynamic>())).toList();
    final r = await JsonStore.read('news_read');
    if (r is List) read = r.cast<String>().toSet();
    notifyListeners();
  }

  List<NewsItem> get visible => items.where((i) => !settings.value.disabledSources.contains(i.sourceId)).toList();

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    notifyListeners();
    try {
      final (list, f) = await NewsService.fetchAll(settings.value.disabledSources);
      failed = f;
      if (list.isNotEmpty) {
        items = list.length > 400 ? list.sublist(0, 400) : list;
        updatedAt = DateTime.now();
        await JsonStore.write('news_cache', {
          'items': items.map((e) => e.toJson()).toList(),
          'updatedAt': updatedAt!.toIso8601String(),
        });
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  bool isSaved(NewsItem i) => saved.any((s) => s.id == i.id);

  Future<void> toggleSaved(NewsItem i) async {
    if (isSaved(i)) {
      saved.removeWhere((s) => s.id == i.id);
    } else {
      saved.insert(0, i);
    }
    notifyListeners();
    await JsonStore.write('news_saved', saved.map((e) => e.toJson()).toList());
  }

  Future<void> markRead(NewsItem i) async {
    if (!read.add(i.id)) return;
    notifyListeners();
    final list = read.toList();
    await JsonStore.write('news_read', list.length > 3000 ? list.sublist(list.length - 3000) : list);
  }
}
