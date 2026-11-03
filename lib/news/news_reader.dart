import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/theme.dart';
import 'article.dart';
import 'news_store.dart';
import 'rss.dart';

/// Resumo da notícia dentro do app; o site só abre se a pessoa quiser a matéria completa.
class NewsReaderPage extends StatefulWidget {
  final NewsItem item;
  final Future<ArticleSummary> Function(NewsItem) loader;

  const NewsReaderPage({super.key, required this.item, this.loader = ArticleService.load});

  @override
  State<NewsReaderPage> createState() => _NewsReaderPageState();
}

class _NewsReaderPageState extends State<NewsReaderPage> {
  late final Future<ArticleSummary> summary = widget.loader(widget.item);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NewsStore>();
    final item = widget.item;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: store.isSaved(item) ? 'Remover dos salvos' : 'Salvar',
            icon: Icon(store.isSaved(item) ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () => store.toggleSaved(item),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: () => launchUrl(Uri.parse(item.link), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Ler matéria completa'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text(
            '${item.sourceName.toUpperCase()} · ${ago(item.date)}',
            style: t.labelSmall?.copyWith(color: AppTheme.textMuted, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          Text(item.title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.25)),
          if (item.image != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                item.image!,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: 900,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FutureBuilder<ArticleSummary>(
            future: summary,
            builder: (context, snap) {
              final s = snap.data;
              if (s == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Lendo a matéria…', style: TextStyle(color: AppTheme.textMuted)),
                    ],
                  ),
                );
              }
              return _SummaryView(summary: s);
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  final ArticleSummary summary;

  const _SummaryView({required this.summary});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: AppTheme.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Principais pontos', style: t.titleMedium),
        const SizedBox(height: 12),
        if (summary.points.isEmpty)
          Text('Não foi possível resumir esta notícia. Abra a matéria completa para ler.', style: muted),
        for (final p in summary.points)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 9, right: 12),
                  decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                ),
                Expanded(child: Text(p, style: t.bodyLarge?.copyWith(height: 1.45))),
              ],
            ),
          ),
        if (summary.topics.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Assuntos', style: t.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final topic in summary.topics)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.line),
                  ),
                  child: Text(topic, style: t.labelMedium),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Text(
          summary.fromArticle
              ? 'Resumo automático: frases selecionadas do texto original.'
              : 'Este site não permitiu ler a matéria, então este é o resumo publicado pela própria fonte.',
          style: muted,
        ),
      ],
    );
  }
}
