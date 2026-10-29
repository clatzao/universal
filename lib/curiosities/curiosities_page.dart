import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import 'curiosities_store.dart';
import 'facts.dart';

class CuriositiesPage extends StatefulWidget {
  const CuriositiesPage({super.key});

  @override
  State<CuriositiesPage> createState() => _CuriositiesPageState();
}

class _CuriositiesPageState extends State<CuriositiesPage> {
  FactCategory? category;
  List<Fact> order = [...facts];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<CuriositiesStore>().loadOnThisDay());
  }

  void _shuffle() => setState(() => order = [...facts]..shuffle(Random()));

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CuriositiesStore>();
    final today = DateTime.now();
    final list = category == null ? order : order.where((f) => f.category == category).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Curiosidades'),
        actions: [IconButton(tooltip: 'Embaralhar', icon: const Icon(Icons.shuffle), onPressed: _shuffle)],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          FactOfDayCard(fact: factOfDay(today)),
          _OnThisDay(store: store, today: today),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                      label: const Text('Todas'), selected: category == null, onSelected: (_) => setState(() => category = null)),
                ),
                for (final c in FactCategory.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      avatar: Icon(c.icon, size: 16),
                      label: Text(c.label),
                      selected: category == c,
                      onSelected: (_) => setState(() => category = c),
                    ),
                  ),
              ],
            ),
          ),
          for (final f in list)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: Icon(f.category.icon, color: Theme.of(context).colorScheme.primary),
                title: Text(f.text),
                subtitle: Text(f.category.label),
              ),
            ),
        ],
      ),
    );
  }
}

class FactOfDayCard extends StatelessWidget {
  final Fact fact;

  const FactOfDayCard({super.key, required this.fact});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.lightbulb, color: scheme.onTertiaryContainer),
            const SizedBox(width: 8),
            Text('Curiosidade do dia · ${fact.category.label}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onTertiaryContainer)),
          ]),
          const SizedBox(height: 8),
          Text(fact.text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onTertiaryContainer)),
        ]),
      ),
    );
  }
}

class _OnThisDay extends StatelessWidget {
  final CuriositiesStore store;
  final DateTime today;

  const _OnThisDay({required this.store, required this.today});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.today),
        title: Text('Neste dia · ${two(today.day)}/${two(today.month)}'),
        subtitle: const Text('Wikipédia'),
        children: [
          if (store.loading) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
          if (store.error != null)
            ListTile(
              title: Text(store.error!),
              trailing: TextButton(onPressed: () => store.loadOnThisDay(force: true), child: const Text('Tentar de novo')),
            ),
          for (final e in store.events.take(25))
            ListTile(
              dense: true,
              leading: Text(e.year == null ? '' : '${e.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
              title: Text(e.text),
              onTap: e.url == null ? null : () => launchUrl(Uri.parse(e.url!), mode: LaunchMode.externalApplication),
            ),
        ],
      ),
    );
  }
}
