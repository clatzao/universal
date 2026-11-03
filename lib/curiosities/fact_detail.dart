import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/net.dart';
import '../core/theme.dart';
import 'facts.dart';

/// Artigo da Wikipédia em português sobre o assunto de cada curiosidade (id → título).
const factWikiTitles = <int, String>{
  1: 'Ponto de ebulição',
  2: 'Esqueleto humano',
  3: 'Diamante',
  4: 'Sol',
  5: 'Genoma humano',
  6: 'Polvo',
  7: 'Ouro',
  8: 'Velocidade do som',
  9: 'Hidrogénio',
  10: 'Potássio',
  11: 'Tardigrada',
  12: 'Raio (meteorologia)',
  13: 'Vênus (planeta)',
  14: 'Júpiter (planeta)',
  15: 'Lua',
  16: 'Apollo 11',
  17: 'Olympus Mons',
  18: 'Saturno (planeta)',
  19: 'Estação Espacial Internacional',
  20: 'Proxima Centauri',
  21: 'Plutão (planeta anão)',
  22: 'Iuri Gagarin',
  23: 'Sagittarius A*',
  24: 'Marcos Pontes',
  25: 'Lei Áurea',
  26: 'Independência do Brasil',
  27: 'Brasília',
  28: 'Queda do Muro de Berlim',
  29: 'Primeira Guerra Mundial',
  30: 'Força Expedicionária Brasileira',
  31: 'Prensa móvel',
  32: 'Descobrimento do Brasil',
  33: 'Proclamação da República do Brasil',
  34: 'Queda da Bastilha',
  35: '14-bis',
  36: 'Constituição brasileira de 1988',
  37: 'Grande Pirâmide de Gizé',
  38: 'Sete Maravilhas do Mundo Antigo',
  39: 'Pedra de Roseta',
  40: 'Júlio César',
  41: 'Pompeia',
  42: 'Jogos Olímpicos da Antiguidade',
  43: 'Código de Hamurabi',
  44: 'Escrita cuneiforme',
  45: 'Coliseu',
  46: 'Alexandre, o Grande',
  47: 'Muralha da China',
  48: 'Panteão de Roma',
  49: 'Cristianismo',
  50: 'Catolicismo no Brasil',
  51: 'Ramadã',
  52: 'Budismo',
  53: 'Chanucá',
  54: 'Diwali',
  55: 'Vaticano',
  56: 'Cristo Redentor',
  57: 'Círio de Nazaré',
  58: 'Siquismo',
  59: 'Basílica de Nossa Senhora Aparecida',
  60: 'Candomblé',
  61: 'Samba de roda',
  62: 'Frevo',
  63: 'Capoeira',
  64: 'Cultura do Japão',
  65: 'Dia dos Mortos',
  66: 'Língua portuguesa',
  67: 'Língua chinesa',
  68: 'Chimarrão',
  69: 'Haiku',
  70: 'Bumba meu boi',
  72: 'Festival Folclórico de Parintins',
  73: 'Rússia',
  74: 'Brasil',
  75: 'Fronteiras do Brasil',
  76: 'Índia',
  77: 'Canadá',
  78: 'Bolívia',
  79: 'Islândia',
  80: 'Rio Amazonas',
  81: 'Mongólia',
  82: 'Bandeira do Nepal',
  83: 'Indonésia',
  84: 'Lago Baikal',
  85: 'iPhone',
  86: 'World Wide Web',
  87: 'ENIAC',
  88: 'Grace Hopper',
  89: 'Android',
  90: 'Ray Tomlinson',
  91: 'Pix',
  92: 'Lei de Moore',
  93: 'Código QR',
  94: '.com',
  95: 'Urna eletrônica',
  96: 'Bitcoin',
  97: 'Tetris',
  98: 'Mario (personagem)',
  99: 'Minecraft',
  100: 'Pac-Man',
  101: 'Pong',
  102: 'Master System',
  103: 'Game Boy',
  104: 'Sonic the Hedgehog',
  105: 'The Legend of Zelda',
  106: 'PlayStation 2',
  107: 'Pokémon',
  108: 'League of Legends',
  109: 'Mel',
  110: 'Flamingo',
  111: 'Rúmen',
  112: 'Girafa',
  113: 'Coala',
  114: 'Beija-flor',
  115: 'Coala',
  116: 'Golfinho',
  117: 'Biodiversidade',
  118: 'Floresta Amazônica',
  119: 'Abelha',
  120: 'Ornitorrinco',
};

class WikiSummary {
  final String title;
  final String extract;
  final String? image;
  final String url;

  const WikiSummary(this.title, this.extract, this.image, this.url);

  static final Map<String, WikiSummary> _cache = {};

  static Future<WikiSummary?> forTitle(String title) async {
    final cached = _cache[title];
    if (cached != null) return cached;
    final j = await Net.json(
      'https://pt.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(title.replaceAll(' ', '_'))}',
    );
    if (j is! Map || j['type'] == 'disambiguation') return null;
    final extract = (j['extract'] as String?)?.trim() ?? '';
    if (extract.isEmpty) return null;
    final url =
        ((j['content_urls'] as Map?)?['mobile'] as Map?)?['page'] as String? ??
        'https://pt.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}';
    return _cache[title] = WikiSummary(
      j['title'] as String? ?? title,
      extract,
      (j['thumbnail'] as Map?)?['source'] as String?,
      url,
    );
  }
}

/// Curiosidade detalhada. Deslize para os lados para ver a anterior e a próxima.
class FactDetailPage extends StatefulWidget {
  final List<Fact> list;
  final int index;

  const FactDetailPage({super.key, required this.list, required this.index});

  /// Abre a curiosidade dentro de todas as curiosidades da mesma categoria.
  static Future<void> open(BuildContext context, Fact fact, {List<Fact>? list}) {
    final items = list ?? facts.where((f) => f.category == fact.category).toList();
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FactDetailPage(list: items, index: items.indexOf(fact).clamp(0, items.length - 1)),
      ),
    );
  }

  @override
  State<FactDetailPage> createState() => _FactDetailPageState();
}

class _FactDetailPageState extends State<FactDetailPage> {
  late final PageController controller = PageController(initialPage: widget.index);
  late int index = widget.index;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fact = widget.list[index];
    return Scaffold(
      appBar: AppBar(
        title: Text('${index + 1} de ${widget.list.length}'),
        actions: [
          IconButton(
            tooltip: 'Copiar',
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: fact.text));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Curiosidade copiada')));
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: controller,
        itemCount: widget.list.length,
        onPageChanged: (i) => setState(() => index = i),
        itemBuilder: (_, i) => _FactView(fact: widget.list[i]),
      ),
    );
  }
}

class _FactView extends StatefulWidget {
  final Fact fact;

  const _FactView({required this.fact});

  @override
  State<_FactView> createState() => _FactViewState();
}

class _FactViewState extends State<_FactView> {
  String? get title => factWikiTitles[widget.fact.id];
  late Future<WikiSummary?> wiki = title == null ? Future.value(null) : WikiSummary.forTitle(title!);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            Icon(widget.fact.category.icon, size: 18, color: scheme.tertiary),
            const SizedBox(width: 8),
            Text(
              widget.fact.category.label.toUpperCase(),
              style: t.labelSmall?.copyWith(color: scheme.tertiary, letterSpacing: 1),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(widget.fact.text, style: t.headlineSmall?.copyWith(height: 1.35, fontWeight: FontWeight.w500)),
        const SizedBox(height: 28),
        if (title != null)
          FutureBuilder<WikiSummary?>(
            future: wiki,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              final w = snap.data;
              if (w == null) {
                return Text(
                  'Não foi possível buscar mais detalhes agora.',
                  style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saiba mais: ${w.title}', style: t.titleMedium),
                  const SizedBox(height: 12),
                  if (w.image != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        w.image!,
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(w.extract, style: t.bodyLarge?.copyWith(height: 1.5)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => launchUrl(Uri.parse(w.url), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Ler na Wikipédia'),
                  ),
                  Text('Texto da Wikipédia (CC BY-SA).', style: t.bodySmall?.copyWith(color: AppTheme.textMuted)),
                ],
              );
            },
          ),
        const SizedBox(height: 16),
        Text(
          'Deslize para os lados para ver outras curiosidades.',
          style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
        ),
      ],
    );
  }
}
