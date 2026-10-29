import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../info/info_store.dart';
import '../info/info_strip.dart';
import '../settings/settings.dart';
import 'news_store.dart';
import 'rss.dart';
import 'sources.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  Topic? topic;
  bool savedOnly = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NewsStore>();
    var list = savedOnly ? store.saved : store.visible;
    if (topic != null) list = list.where((i) => i.topic == topic).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notícias'),
        actions: [
          IconButton(
            tooltip: savedOnly ? 'Todas' : 'Salvas',
            icon: Icon(savedOnly ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () => setState(() => savedOnly = !savedOnly),
          ),
          IconButton(
            tooltip: 'Fontes',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SourcesPage())),
          ),
        ],
      ),
      body: Column(children: [
        const InfoStrip(),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(label: const Text('Tudo'), selected: topic == null, onSelected: (_) => setState(() => topic = null)),
              ),
              for (final t in Topic.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(label: Text(t.label), selected: topic == t, onSelected: (_) => setState(() => topic = t)),
                ),
            ],
          ),
        ),
        if (store.loading) const LinearProgressIndicator(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([store.refresh(), context.read<InfoStore>().refresh(force: true)]);
            },
            child: list.isEmpty
                ? ListView(children: [
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        savedOnly
                            ? 'Nenhuma notícia salva.'
                            : (store.loading ? 'Carregando…' : 'Puxe para baixo para carregar as notícias.'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: list.length + (store.failed.isNotEmpty && !savedOnly ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == list.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Sem resposta de: ${store.failed.join(', ')}',
                              style: Theme.of(context).textTheme.bodySmall),
                        );
                      }
                      return NewsCard(item: list[i]);
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}

class NewsCard extends StatelessWidget {
  final NewsItem item;
  final bool dense;

  const NewsCard({super.key, required this.item, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NewsStore>();
    final unread = !store.read.contains(item.id);
    final t = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 3 : 6),
      child: InkWell(
        onTap: () {
          store.markRead(item);
          launchUrl(Uri.parse(item.link), mode: LaunchMode.externalApplication);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (unread) ...[
                    Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text('${item.sourceName.toUpperCase()} · ${ago(item.date)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.labelSmall?.copyWith(color: AppTheme.textMuted, letterSpacing: 0.6)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(item.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall?.copyWith(
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      color: unread ? AppTheme.text : AppTheme.textMuted,
                      height: 1.3,
                    )),
                if (!dense && item.summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(item.summary, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                ],
              ]),
            ),
            if (item.image != null && !dense) ...[
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.image!,
                  width: 96,
                  height: 72,
                  fit: BoxFit.cover,
                  cacheWidth: 288,
                  errorBuilder: (_, _, _) => const SizedBox(width: 96, height: 72),
                ),
              ),
            ],
            if (!dense)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(store.isSaved(item) ? Icons.bookmark : Icons.bookmark_border),
                onPressed: () => store.toggleSaved(item),
              ),
          ]),
        ),
      ),
    );
  }
}

class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final disabled = settings.value.disabledSources;
    return Scaffold(
      appBar: AppBar(title: const Text('Fontes de notícias')),
      body: ListView(children: [
        for (final t in Topic.values) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(t.label, style: Theme.of(context).textTheme.titleSmall),
          ),
          for (final s in newsSources.where((s) => s.topic == t))
            SwitchListTile(
              title: Text(s.name),
              subtitle: Text(s.url, maxLines: 1, overflow: TextOverflow.ellipsis),
              value: !disabled.contains(s.id),
              onChanged: (v) => settings.update((x) {
                final set = {...x.disabledSources};
                v ? set.remove(s.id) : set.add(s.id);
                x.disabledSources = set;
              }),
            ),
        ],
      ]),
    );
  }
}
