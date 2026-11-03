import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import 'career.dart';
import 'games_logic.dart';
import 'games_store.dart';
import 'quick_games.dart';

class GamesPage extends StatelessWidget {
  const GamesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<GamesStore>();
    final today = DateTime.now();
    final career = store.career;

    Widget tile(String game, String title, String subtitle, IconData icon, Widget Function() page, {String? stat}) {
      final record = store.record(game);
      final info =
          stat ??
          [
            if (record.best > 0) 'Recorde: ${record.best}',
            if (record.streak > 0) 'Sequência: ${record.streak}',
          ].join(' · ');
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(
            info.isEmpty ? subtitle : '$subtitle\n$info',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
          isThreeLine: info.isNotEmpty,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page())),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Jogos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          tile(
            'palavra',
            'Palavra do dia',
            store.dailyFor('palavra', today)?['done'] == true
                ? 'Volte amanhã para uma nova palavra'
                : 'Descubra a palavra de hoje',
            Icons.abc,
            () => const WordDayPage(),
          ),
          tile(
            'caso',
            'Caso do dia',
            store.dailyFor('caso', today)?['done'] == true
                ? 'Caso de hoje encerrado'
                : 'Ouça as testemunhas e acuse o culpado',
            Icons.search,
            () => const CasePage(),
          ),
          tile('forca', 'Forca', 'Adivinhe a palavra letra por letra', Icons.spellcheck, () => const HangmanPage()),
          tile(
            'carreira',
            'Carreira de futebol',
            career == null || career.retired
                ? 'Crie um jogador e suba até a elite'
                : '${career.name}, ${career.age} anos · ${divisions[career.division]}',
            Icons.sports_soccer,
            () => const CareerPage(),
          ),
          tile(
            'contas',
            'Contas rápidas',
            'Quantas contas você resolve em 45 segundos',
            Icons.calculate_outlined,
            () => const MathGamePage(),
          ),
          tile(
            'memoria',
            'Jogo da memória',
            'Encontre os pares com poucas jogadas',
            Icons.grid_view,
            () => const MemoryGamePage(),
          ),
          tile('reflexo', 'Reflexo', 'Toque assim que a tela mudar de cor', Icons.bolt, () => const ReflexGamePage()),
        ],
      ),
    );
  }
}

// ---------- Forca ----------

class HangmanPage extends StatefulWidget {
  final Random? random;

  const HangmanPage({super.key, this.random});

  @override
  State<HangmanPage> createState() => _HangmanPageState();
}

class _HangmanPageState extends State<HangmanPage> {
  late final Random random = widget.random ?? Random();
  late HangmanGame game = _newGame();
  int wins = 0;

  HangmanGame _newGame() {
    final words = allWords;
    return HangmanGame(words[random.nextInt(words.length)]);
  }

  void _guess(String letter) {
    final store = context.read<GamesStore>();
    final hit = game.guess(letter);
    HapticFeedback.selectionClick();
    setState(() {});
    if (!hit && !game.over) return;
    if (game.won) {
      wins++;
      store.addResult('forca', wins);
    } else if (game.lost) {
      wins = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Forca')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Categoria: ${game.target.category}',
            textAlign: TextAlign.center,
            style: t.titleSmall?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            'Vitórias seguidas: $wins · Recorde: ${context.watch<GamesStore>().record('forca').best}',
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          Center(
            child: CustomPaint(size: const Size(150, 150), painter: _GallowsPainter(game.errors)),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(game.masked, style: t.headlineSmall?.copyWith(letterSpacing: 2, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          if (game.over) ...[
            Text(
              game.won ? 'Você acertou!' : 'Não foi desta vez.',
              textAlign: TextAlign.center,
              style: t.titleMedium?.copyWith(color: game.won ? AppTheme.positive : AppTheme.negative),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => setState(() => game = _newGame()),
              icon: const Icon(Icons.refresh),
              label: const Text('Nova palavra'),
            ),
          ] else
            _Keyboard(used: game.guessed, isHit: (l) => normalizedContains(game.target.word, l), onTap: _guess),
        ],
      ),
    );
  }
}

bool normalizedContains(String word, String letter) => lettersOnly(word).contains(letter);

class _Keyboard extends StatelessWidget {
  final Set<String> used;
  final bool Function(String) isHit;
  final ValueChanged<String> onTap;

  const _Keyboard({required this.used, required this.isHit, required this.onTap});

  static const _rows = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final l in row.split(''))
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: SizedBox(
                        height: 44,
                        child: Material(
                          color: !used.contains(l)
                              ? AppTheme.surfaceHighest
                              : (isHit(l) ? AppTheme.positive.withValues(alpha: 0.3) : AppTheme.surface),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: used.contains(l) ? null : () => onTap(l),
                            child: Center(
                              child: Text(
                                l.toUpperCase(),
                                style: TextStyle(color: used.contains(l) ? AppTheme.textMuted : AppTheme.text),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GallowsPainter extends CustomPainter {
  final int errors;

  const _GallowsPainter(this.errors);

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = AppTheme.textMuted
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final body = Paint()
      ..color = errors >= HangmanGame.maxErrors ? AppTheme.negative : AppTheme.text
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(w * .1, h * .97), Offset(w * .6, h * .97), base);
    canvas.drawLine(Offset(w * .25, h * .97), Offset(w * .25, h * .05), base);
    canvas.drawLine(Offset(w * .25, h * .05), Offset(w * .7, h * .05), base);
    canvas.drawLine(Offset(w * .7, h * .05), Offset(w * .7, h * .18), base);
    final cx = w * .7;
    if (errors >= 1) canvas.drawCircle(Offset(cx, h * .27), h * .09, body);
    if (errors >= 2) canvas.drawLine(Offset(cx, h * .36), Offset(cx, h * .62), body);
    if (errors >= 3) canvas.drawLine(Offset(cx, h * .42), Offset(cx - w * .12, h * .54), body);
    if (errors >= 4) canvas.drawLine(Offset(cx, h * .42), Offset(cx + w * .12, h * .54), body);
    if (errors >= 5) canvas.drawLine(Offset(cx, h * .62), Offset(cx - w * .11, h * .8), body);
    if (errors >= 6) canvas.drawLine(Offset(cx, h * .62), Offset(cx + w * .11, h * .8), body);
  }

  @override
  bool shouldRepaint(_GallowsPainter old) => old.errors != errors;
}

// ---------- Palavra do dia ----------

class WordDayPage extends StatefulWidget {
  final DateTime? day;

  const WordDayPage({super.key, this.day});

  @override
  State<WordDayPage> createState() => _WordDayPageState();
}

class _WordDayPageState extends State<WordDayPage> {
  late final DateTime day = widget.day ?? DateTime.now();
  late final WordDayGame game = WordDayGame(wordOfDay(day));
  final input = TextEditingController();
  String? error;

  @override
  void initState() {
    super.initState();
    // Reabre o progresso de hoje: sair da tela não devolve tentativas.
    final saved = context.read<GamesStore>().dailyFor('palavra', day);
    for (final g in (saved?['tries'] as List?) ?? const []) {
      game.submit(g as String);
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void _submit() {
    final store = context.read<GamesStore>();
    final message = game.submit(input.text);
    if (message != null) {
      setState(() => error = message);
      return;
    }
    HapticFeedback.selectionClick();
    input.clear();
    setState(() => error = null);
    store.setDaily('palavra', day, {
      'tries': [for (final t in game.tries) t.guess],
      'done': game.over,
    });
    if (game.over) store.addResult('palavra', game.score, dailyWin: game.won ? day : null);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final record = context.watch<GamesStore>().record('palavra');
    return Scaffold(
      appBar: AppBar(title: const Text('Palavra do dia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Categoria: ${game.target.category} · ${game.length} letras',
            textAlign: TextAlign.center,
            style: t.titleSmall,
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(game.hint, style: t.headlineMedium?.copyWith(letterSpacing: 4, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 6),
          Text(
            'Uma letra é revelada a cada 2 tentativas. Acentos não importam.',
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          if (game.over) ...[
            Text(
              game.won
                  ? 'Acertou em ${game.tries.length} tentativa(s)! +${game.score} pontos'
                  : 'A palavra era ${game.target.word.toUpperCase()}.',
              textAlign: TextAlign.center,
              style: t.titleMedium?.copyWith(color: game.won ? AppTheme.positive : AppTheme.negative),
            ),
            const SizedBox(height: 6),
            Text(
              'Sequência: ${record.streak} · Recorde: ${record.best}. Amanhã tem outra.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
          ] else ...[
            TextField(
              controller: input,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Tentativa ${game.tries.length + 1} de ${WordDayGame.maxTries}',
                errorText: error,
                suffixIcon: IconButton(tooltip: 'Enviar', icon: const Icon(Icons.send), onPressed: _submit),
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (final g in game.tries.reversed)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.guess.toUpperCase(), style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${g.placed} no lugar · ${g.present} fora do lugar',
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------- Caso do dia ----------

class CasePage extends StatefulWidget {
  final DateTime? day;

  const CasePage({super.key, this.day});

  @override
  State<CasePage> createState() => _CasePageState();
}

class _CasePageState extends State<CasePage> {
  late final DateTime day = widget.day ?? DateTime.now();
  late final DailyCase data = caseForDay(day);
  final heard = <int>{};
  String? accused;

  @override
  void initState() {
    super.initState();
    final saved = context.read<GamesStore>().dailyFor('caso', day);
    if (saved != null) {
      heard.addAll(((saved['heard'] as List?) ?? const []).cast<int>());
      accused = saved['accused'] as String?;
    }
  }

  bool get done => accused != null;

  void _save() =>
      context.read<GamesStore>().setDaily('caso', day, {'heard': heard.toList(), 'accused': accused, 'done': done});

  void _hear(int i) {
    setState(() => heard.add(i));
    _save();
  }

  Future<void> _accuse(Suspect s) async {
    final store = context.read<GamesStore>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Acusar ${s.name}?'),
        content: const Text('Você só pode acusar uma vez por dia.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Acusar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => accused = s.name);
    _save();
    final correct = s.name == data.culprit.name;
    await store.addResult('caso', data.score(heard.length, correct), dailyWin: correct ? day : null);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final correct = accused == data.culprit.name;
    return Scaffold(
      appBar: AppBar(title: const Text('Caso do dia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(data.title, style: t.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${data.description}. Cada testemunha ouvida tira ${DailyCase.cluePenalty} pontos.',
            style: t.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
          if (done) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      correct
                          ? 'Caso resolvido! +${data.score(heard.length, true)} pontos'
                          : 'Você acusou a pessoa errada.',
                      style: t.titleMedium?.copyWith(color: correct ? AppTheme.positive : AppTheme.negative),
                    ),
                    const SizedBox(height: 4),
                    Text('Culpado: ${data.culprit.name}. Volte amanhã para um novo caso.'),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text('Testemunhas', style: t.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < data.clues.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: heard.contains(i) || done
                  ? ListTile(
                      leading: const Icon(Icons.record_voice_over_outlined),
                      title: Text(data.clues[i].witness),
                      subtitle: Text(data.clues[i].text),
                    )
                  : ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(data.clues[i].witness),
                      subtitle: const Text('Toque para ouvir', style: TextStyle(color: AppTheme.textMuted)),
                      onTap: () => _hear(i),
                    ),
            ),
          const SizedBox(height: 14),
          Text('Suspeitos', style: t.titleMedium),
          const SizedBox(height: 8),
          for (final s in data.suspects)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s.name}, ${s.job}', style: t.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Estava ${s.placeLabel}, ${s.hourLabel}, com ${s.itemLabel}.',
                      style: t.bodyMedium?.copyWith(color: AppTheme.textMuted),
                    ),
                    if (!done) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: () => _accuse(s), child: const Text('Acusar')),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------- Carreira ----------

class CareerPage extends StatefulWidget {
  final Random? random;

  const CareerPage({super.key, this.random});

  @override
  State<CareerPage> createState() => _CareerPageState();
}

class _CareerPageState extends State<CareerPage> {
  late final Random random = widget.random ?? Random();
  final name = TextEditingController();
  Position position = Position.atacante;
  String? lastEvent;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  GamesStore get store => context.read<GamesStore>();

  void _create() {
    final text = name.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dê um nome ao jogador')));
      return;
    }
    store.setCareer(CareerState.start(text, position, random));
    setState(() => lastEvent = null);
  }

  void _train(CareerState c, Skill s) {
    final gain = c.train(s, random);
    setState(
      () => lastEvent = gain == 0
          ? 'Pouca energia para treinar. Descanse.'
          : 'Treino de ${s.label}: ${gain == 1 ? '+1 ponto' : '+$gain pontos'}.',
    );
    store.save();
  }

  void _rest(CareerState c) {
    c.rest();
    setState(() => lastEvent = 'Você descansou e recuperou energia.');
    store.save();
  }

  Future<void> _play(CareerState c) async {
    final report = await Navigator.push<MatchReport>(
      context,
      MaterialPageRoute(
        builder: (_) => MatchPage(career: c, random: random),
      ),
    );
    if (report == null || !mounted) return;
    setState(
      () => lastEvent =
          '${c.club} ${report.goalsFor} x ${report.goalsAgainst} ${report.opponent}. Sua nota: ${report.rating.toStringAsFixed(1).replaceAll('.', ',')}.',
    );
    await store.save();
    if (!mounted) return;
    final event = c.nextEvent(random);
    if (event != null) await _showEvent(c, event);
    if (c.seasonOver && mounted) await _closeSeason(c);
  }

  Future<void> _showEvent(CareerState c, CareerEvent event) async {
    final choice = await showDialog<EventOption>(
      context: context,
      barrierDismissible: false,
      builder: (d) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Fora de campo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(event.text),
              const SizedBox(height: 16),
              for (final o in event.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: c.canChoose(o) ? () => Navigator.pop(d, o) : null,
                    child: Text(c.canChoose(o) ? o.label : '${o.label} (sem dinheiro)', textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    c.applyEvent(choice);
    setState(() => lastEvent = '${lastEvent ?? ''}\n${choice.result}'.trim());
    await store.save();
  }

  Widget _history(CareerState c) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        Text('Temporadas', style: t.titleMedium),
        const SizedBox(height: 8),
        for (final s in c.history.reversed)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              leading: Icon(switch (s.movement) {
                1 => Icons.arrow_upward,
                -1 => Icons.arrow_downward,
                _ => Icons.remove,
              }),
              title: Text('${s.season}ª · ${s.club}'),
              subtitle: Text(
                '${s.division} · média ${s.average.toStringAsFixed(1).replaceAll('.', ',')} · '
                '${s.goals} gols · ${s.assists} assist.',
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _closeSeason(CareerState c) async {
    final s = c.closeSeason(random);
    await store.save();
    if (c.retired) await store.addResult('carreira', c.careerScore);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Fim da temporada ${s.season}'),
        content: Text(
          '${s.club} · ${s.division}\n'
          'Média: ${s.average.toStringAsFixed(1).replaceAll('.', ',')} · Gols: ${s.goals} · Assistências: ${s.assists}\n\n'
          '${switch (s.movement) {
            1 => 'Você subiu de nível e foi contratado pelo ${s.newClub}!',
            -1 => 'Temporada ruim: você foi para o ${s.newClub}, uma divisão abaixo.',
            _ => 'Você segue no ${s.newClub}.',
          }}',
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(d), child: const Text('Continuar'))],
      ),
    );
    if (mounted) setState(() => lastEvent = null);
  }

  @override
  Widget build(BuildContext context) {
    final games = context.watch<GamesStore>();
    final c = games.career;
    return Scaffold(
      appBar: AppBar(title: const Text('Carreira de futebol')),
      body: c == null ? _creation(games) : (c.retired ? _retired(c, games) : _dashboard(c)),
    );
  }

  Widget _creation(GamesStore games) {
    final t = Theme.of(context).textTheme;
    final best = games.record('carreira').best;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Comece na Liga Regional, aos 17 anos, e tente chegar à Liga Continental.', style: t.bodyLarge),
        const SizedBox(height: 16),
        TextField(
          controller: name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome do jogador'),
        ),
        const SizedBox(height: 14),
        SegmentedButton<Position>(
          segments: [for (final p in Position.values) ButtonSegment(value: p, label: Text(p.label))],
          selected: {position},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => position = s.first),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _create,
          icon: const Icon(Icons.sports_soccer),
          label: const Text('Começar carreira'),
        ),
        if (best > 0) ...[
          const SizedBox(height: 12),
          Text(
            'Recorde: $best pontos',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMuted),
          ),
        ],
      ],
    );
  }

  Widget _retired(CareerState c, GamesStore games) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${c.name} se aposentou', style: t.titleLarge),
        const SizedBox(height: 8),
        Text(
          '${c.totalMatches} jogos · ${c.totalGoals} gols · ${c.totalAssists} assistências\n'
          'Último clube: ${c.club} (${divisions[c.division]})\n'
          'Pontuação: ${c.careerScore} · Recorde: ${games.record('carreira').best}',
          style: t.bodyLarge,
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => store.setCareer(null),
          icon: const Icon(Icons.refresh),
          label: const Text('Nova carreira'),
        ),
        if (c.history.isNotEmpty) _history(c),
      ],
    );
  }

  Widget _dashboard(CareerState c) {
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: AppTheme.textMuted);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(c.name, style: t.titleLarge),
        Text(
          '${c.position.label}, ${c.age} anos · ${c.club}',
          style: t.bodyMedium?.copyWith(color: AppTheme.textMuted),
        ),
        Text('${divisions[c.division]} · Temporada ${c.season}, semana ${c.week} de $seasonWeeks', style: muted),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text('Energia: ${c.energy}%', style: t.labelLarge)),
            Text(
              NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0).format(c.money),
              style: t.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: c.energy / 100,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
          color: c.energy < 30 ? AppTheme.negative : AppTheme.positive,
        ),
        const SizedBox(height: 10),
        Text(
          'Nesta temporada: ${c.seasonMatches} jogos · ${c.seasonGoals} gols · ${c.seasonAssists} assist. · '
          'média ${c.seasonAverage.toStringAsFixed(1).replaceAll('.', ',')}',
          style: muted,
        ),
        Text('Média 7,0 ou mais sobe de divisão; abaixo de 5,5, cai.', style: muted),
        if (lastEvent != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(padding: const EdgeInsets.all(12), child: Text(lastEvent!)),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => _play(c),
          icon: const Icon(Icons.sports_soccer),
          label: const Text('Jogar a partida da semana'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: c.energy >= 100 ? null : () => _rest(c),
          icon: const Icon(Icons.hotel_outlined),
          label: const Text('Descansar'),
        ),
        const SizedBox(height: 18),
        Text('Treinar (gasta energia)', style: t.titleMedium),
        const SizedBox(height: 8),
        for (final s in Skill.values)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              title: Text(s.label),
              subtitle: LinearProgressIndicator(
                value: c.skill(s) / 99,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${c.skill(s)}', style: t.titleSmall),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Treinar ${s.label}',
                    onPressed: c.energy < 20 ? null : () => _train(c, s),
                    icon: const Icon(Icons.fitness_center, size: 20),
                  ),
                ],
              ),
            ),
          ),
        if (c.history.isNotEmpty) _history(c),
      ],
    );
  }
}

/// Partida: dois lances com escolhas e resultado na hora.
class MatchPage extends StatefulWidget {
  final CareerState career;
  final Random random;

  const MatchPage({super.key, required this.career, required this.random});

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  late final String opponent = widget.career.opponentName(widget.random);
  late final List<PlayScene> scenes = ([
    ...scenesFor(widget.career.position),
  ]..shuffle(widget.random)).take(matchPlays).toList();
  int index = 0;
  int goals = 0;
  int assists = 0;
  int successes = 0;
  String? outcome;
  bool lastOk = false;

  void _choose(PlayOption o) {
    final ok = widget.random.nextDouble() < widget.career.chance(o);
    HapticFeedback.mediumImpact();
    setState(() {
      lastOk = ok;
      outcome = ok ? o.successText : o.failText;
      if (ok) {
        successes++;
        if (o.goal) goals++;
        if (o.assist) assists++;
      }
    });
  }

  void _next() {
    if (index + 1 < scenes.length) {
      setState(() {
        index++;
        outcome = null;
      });
      return;
    }
    final report = widget.career.finishMatch(
      opponent: opponent,
      goals: goals,
      assists: assists,
      plays: scenes.length,
      successes: successes,
      random: widget.random,
    );
    Navigator.pop(context, report);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scene = scenes[index];
    return PopScope(
      // A partida já começou: sair no meio deixaria a semana sem resultado.
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('${widget.career.club} x $opponent', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Lance ${index + 1} de ${scenes.length}', style: t.labelLarge?.copyWith(color: AppTheme.textMuted)),
            const SizedBox(height: 8),
            Text(scene.text, style: t.titleMedium),
            const SizedBox(height: 16),
            if (outcome == null)
              for (final o in scene.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () => _choose(o),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          Text(o.label, textAlign: TextAlign.center),
                          const SizedBox(height: 2),
                          Text(
                            '${o.skill.label} · chance ${(widget.career.chance(o) * 100).round()}%',
                            style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
            else ...[
              Text(outcome!, style: t.titleMedium?.copyWith(color: lastOk ? AppTheme.positive : AppTheme.negative)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _next,
                child: Text(index + 1 < scenes.length ? 'Próximo lance' : 'Ver resultado'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
