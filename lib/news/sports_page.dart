import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../settings/settings.dart';
import 'news_store.dart';
import 'sports.dart';

/// Escolha dos times, ligas e esportes que aparecem nas notícias.
class SportsFollowPage extends StatefulWidget {
  const SportsFollowPage({super.key});

  @override
  State<SportsFollowPage> createState() => _SportsFollowPageState();
}

class _SportsFollowPageState extends State<SportsFollowPage> {
  final custom = TextEditingController();
  late final Set<String> initial;

  @override
  void initState() {
    super.initState();
    initial = {...context.read<SettingsStore>().value.followedSports};
  }

  @override
  void dispose() {
    custom.dispose();
    super.dispose();
  }

  void _toggle(SettingsStore settings, String id) => settings.update((s) {
    final set = {...s.followedSports};
    set.contains(id) ? set.remove(id) : set.add(id);
    s.followedSports = set;
  });

  void _addCustom(SettingsStore settings) {
    final text = custom.text.trim();
    if (text.length < 2) return;
    _toggle(settings, '$customPrefix$text');
    custom.clear();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final followed = settings.value.followedSports;
    final t = Theme.of(context).textTheme;
    final customs = followed.where((f) => f.startsWith(customPrefix)).toList();

    Widget section(String title, FollowKind kind) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final topic in sportsCatalog.where((c) => c.kind == kind))
                FilterChip(
                  label: Text(topic.label),
                  selected: followed.contains(topic.id),
                  onSelected: (_) => _toggle(settings, topic.id),
                ),
            ],
          ),
        ],
      ),
    );

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Times novos têm feed próprio: atualiza ao sair se a seleção mudou.
        if (didPop && !setEquals(initial, followed)) context.read<NewsStore>().refresh();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Times e ligas'),
          actions: [
            if (followed.isNotEmpty)
              TextButton(onPressed: () => settings.update((s) => s.followedSports = {}), child: const Text('Limpar')),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                followed.isEmpty
                    ? 'Nada escolhido: você vê todas as notícias de esporte.'
                    : 'Em Esportes aparecem só notícias de ${followed.length} ${followed.length == 1 ? 'seleção' : 'seleções'}.',
                style: t.bodyMedium?.copyWith(color: AppTheme.textMuted),
              ),
            ),
            section('Times', FollowKind.time),
            section('Ligas e campeonatos', FollowKind.liga),
            section('Outros esportes', FollowKind.esporte),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Outro time ou assunto', style: t.titleMedium),
                  const SizedBox(height: 10),
                  TextField(
                    controller: custom,
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (_) => _addCustom(settings),
                    decoration: InputDecoration(
                      hintText: 'Ex.: Real Madrid, Neymar',
                      suffixIcon: IconButton(
                        tooltip: 'Adicionar',
                        icon: const Icon(Icons.add),
                        onPressed: () => _addCustom(settings),
                      ),
                    ),
                  ),
                  if (customs.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in customs)
                          InputChip(
                            label: Text(c.substring(customPrefix.length)),
                            onDeleted: () => _toggle(settings, c),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
