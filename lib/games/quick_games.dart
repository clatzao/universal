import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import 'games_store.dart';

// ---------- Contas rápidas ----------

class MathQuestion {
  final String text;
  final int answer;
  final List<int> options;

  const MathQuestion(this.text, this.answer, this.options);
}

/// A dificuldade cresce com a pontuação. As alternativas são sempre quatro números diferentes.
MathQuestion mathQuestion(int score, Random random) {
  final level = min(score ~/ 5, 4);
  final limit = 10 + level * 15;
  int a = 1 + random.nextInt(limit), b = 1 + random.nextInt(limit);
  final String text;
  final int answer;
  switch (random.nextInt(level == 0 ? 2 : 3)) {
    case 0:
      text = '$a + $b';
      answer = a + b;
    case 1:
      if (b > a) (a, b) = (b, a);
      text = '$a − $b';
      answer = a - b;
    default:
      a = 2 + random.nextInt(5 + level * 2);
      b = 2 + random.nextInt(8);
      text = '$a × $b';
      answer = a * b;
  }
  final options = <int>{answer};
  while (options.length < 4) {
    final delta = 1 + random.nextInt(10);
    final wrong = random.nextBool() ? answer + delta : answer - delta;
    if (wrong >= 0) options.add(wrong);
  }
  return MathQuestion(text, answer, options.toList()..shuffle(random));
}

class MathGamePage extends StatefulWidget {
  final Random? random;

  const MathGamePage({super.key, this.random});

  static const seconds = 45;
  static const wrongPenalty = 3;

  @override
  State<MathGamePage> createState() => _MathGamePageState();
}

class _MathGamePageState extends State<MathGamePage> {
  late final Random random = widget.random ?? Random();
  Timer? timer;
  int score = 0;
  int left = 0;
  MathQuestion? question;
  bool finished = false;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      score = 0;
      left = MathGamePage.seconds;
      finished = false;
      question = mathQuestion(0, random);
    });
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick(1));
  }

  void _tick(int seconds) {
    setState(() => left = max(0, left - seconds));
    if (left == 0) _finish();
  }

  void _finish() {
    timer?.cancel();
    setState(() {
      finished = true;
      question = null;
    });
    context.read<GamesStore>().addResult('contas', score);
  }

  void _answer(int value) {
    if (value == question!.answer) {
      HapticFeedback.selectionClick();
      setState(() {
        score++;
        question = mathQuestion(score, random);
      });
    } else {
      HapticFeedback.heavyImpact();
      setState(() => question = mathQuestion(score, random));
      _tick(MathGamePage.wrongPenalty);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final q = question;
    final best = context.watch<GamesStore>().record('contas').best;
    return Scaffold(
      appBar: AppBar(title: const Text('Contas rápidas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (q == null) ...[
            Text(
              finished ? 'Fim de jogo: $score ponto(s)' : 'Resolva o máximo de contas. Cada erro tira 3 segundos.',
              textAlign: TextAlign.center,
              style: t.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Recorde: $best',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow),
              label: Text(finished ? 'Jogar de novo' : 'Começar'),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(child: Text('Pontos: $score', style: t.titleMedium)),
                Text('${left}s', style: t.titleMedium?.copyWith(color: left <= 10 ? AppTheme.negative : null)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: left / MathGamePage.seconds, minHeight: 6),
            const SizedBox(height: 32),
            Text(q.text, textAlign: TextAlign.center, style: t.displaySmall),
            const SizedBox(height: 32),
            for (final row in [q.options.sublist(0, 2), q.options.sublist(2)])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    for (var i = 0; i < 2; i++) ...[
                      if (i == 1) const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _answer(row[i]),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text('${row[i]}', style: t.titleLarge),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ---------- Jogo da memória ----------

class MemoryGame {
  static const pairs = 8;

  /// Cada carta guarda o número do seu par.
  final List<int> cards;
  final Set<int> matched = {};
  final List<int> open = [];
  int moves = 0;

  MemoryGame(Random random)
    : cards = [
        for (var i = 0; i < pairs; i++) ...[i, i],
      ]..shuffle(random);

  bool get won => matched.length == cards.length;

  /// Duas cartas diferentes abertas: esperam [closeOpen] para virar de volta.
  bool get waiting => open.length == 2;

  bool isVisible(int i) => matched.contains(i) || open.contains(i);

  /// Retorna true se a jogada formou um par.
  bool flip(int i) {
    if (waiting || isVisible(i)) return false;
    open.add(i);
    if (open.length < 2) return false;
    moves++;
    if (cards[open[0]] != cards[open[1]]) return false;
    matched.addAll(open);
    open.clear();
    return true;
  }

  void closeOpen() => open.clear();

  /// O mínimo possível são 8 jogadas. Cada jogada além disso tira pontos.
  int get score => max(10, 100 - (moves - pairs) * 4);
}

const _memoryIcons = [
  Icons.star,
  Icons.favorite,
  Icons.bolt,
  Icons.pets,
  Icons.local_florist,
  Icons.sports_soccer,
  Icons.music_note,
  Icons.rocket_launch,
];

class MemoryGamePage extends StatefulWidget {
  final Random? random;

  const MemoryGamePage({super.key, this.random});

  @override
  State<MemoryGamePage> createState() => _MemoryGamePageState();
}

class _MemoryGamePageState extends State<MemoryGamePage> {
  late final Random random = widget.random ?? Random();
  late MemoryGame game = MemoryGame(random);
  Timer? closing;

  @override
  void dispose() {
    closing?.cancel();
    super.dispose();
  }

  void _flip(int i) {
    final store = context.read<GamesStore>();
    final pair = game.flip(i);
    HapticFeedback.selectionClick();
    setState(() {});
    if (pair && game.won) store.addResult('memoria', game.score);
    if (game.waiting) {
      closing = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(game.closeOpen);
      });
    }
  }

  void _restart() {
    closing?.cancel();
    setState(() => game = MemoryGame(random));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final best = context.watch<GamesStore>().record('memoria').best;
    return Scaffold(
      appBar: AppBar(title: const Text('Jogo da memória')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Jogadas: ${game.moves} · Recorde: $best', textAlign: TextAlign.center, style: t.titleSmall),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (var i = 0; i < game.cards.length; i++)
                Material(
                  key: ValueKey('carta$i'),
                  color: game.matched.contains(i)
                      ? AppTheme.positive.withValues(alpha: 0.25)
                      : (game.isVisible(i) ? AppTheme.surfaceHighest : AppTheme.surface),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _flip(i),
                    child: Center(
                      child: game.isVisible(i)
                          ? Icon(_memoryIcons[game.cards[i]], size: 32)
                          : const Icon(Icons.help_outline, size: 22, color: AppTheme.textMuted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (game.won) ...[
            Text(
              'Você encontrou todos os pares! ${game.score} pontos',
              textAlign: TextAlign.center,
              style: t.titleMedium?.copyWith(color: AppTheme.positive),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(onPressed: _restart, icon: const Icon(Icons.refresh), label: const Text('Recomeçar')),
        ],
      ),
    );
  }
}

// ---------- Reflexo ----------

/// Quanto mais rápida a média, maior a pontuação, de 0 a 1000.
int reflexScore(List<int> millis) {
  if (millis.isEmpty) return 0;
  final average = millis.reduce((a, b) => a + b) / millis.length;
  return (1000 - average).round().clamp(0, 1000);
}

enum _ReflexPhase { idle, waiting, go, tooSoon, done }

class ReflexGamePage extends StatefulWidget {
  final Random? random;

  const ReflexGamePage({super.key, this.random});

  static const rounds = 5;

  @override
  State<ReflexGamePage> createState() => _ReflexGamePageState();
}

class _ReflexGamePageState extends State<ReflexGamePage> {
  late final Random random = widget.random ?? Random();
  final watch = Stopwatch();
  final times = <int>[];
  Timer? delay;
  _ReflexPhase phase = _ReflexPhase.idle;

  @override
  void dispose() {
    delay?.cancel();
    super.dispose();
  }

  void _wait() {
    setState(() => phase = _ReflexPhase.waiting);
    delay?.cancel();
    delay = Timer(Duration(milliseconds: 1500 + random.nextInt(2500)), () {
      if (!mounted) return;
      watch
        ..reset()
        ..start();
      setState(() => phase = _ReflexPhase.go);
    });
  }

  void _tap() {
    switch (phase) {
      case _ReflexPhase.idle || _ReflexPhase.done:
        times.clear();
        _wait();
      case _ReflexPhase.tooSoon:
        _wait();
      case _ReflexPhase.waiting:
        delay?.cancel();
        HapticFeedback.heavyImpact();
        setState(() => phase = _ReflexPhase.tooSoon);
      case _ReflexPhase.go:
        watch.stop();
        HapticFeedback.selectionClick();
        times.add(watch.elapsedMilliseconds);
        if (times.length < ReflexGamePage.rounds) {
          _wait();
        } else {
          setState(() => phase = _ReflexPhase.done);
          context.read<GamesStore>().addResult('reflexo', reflexScore(times));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final best = context.watch<GamesStore>().record('reflexo').best;
    final last = times.isEmpty ? '' : ' Último: ${times.last} ms.';
    final (color, title, detail) = switch (phase) {
      _ReflexPhase.idle => (
        AppTheme.surface,
        'Toque para começar',
        'São ${ReflexGamePage.rounds} rodadas. Recorde: $best',
      ),
      _ReflexPhase.waiting => (
        AppTheme.surfaceHighest,
        'Espere a cor mudar…',
        'Rodada ${times.length + 1} de ${ReflexGamePage.rounds}.$last',
      ),
      _ReflexPhase.go => (AppTheme.positive, 'Toque agora!', ''),
      _ReflexPhase.tooSoon => (AppTheme.negative, 'Cedo demais', 'Toque para repetir a rodada.'),
      _ReflexPhase.done => (
        AppTheme.surface,
        '${reflexScore(times)} pontos',
        'Média: ${(times.reduce((a, b) => a + b) / times.length).round()} ms. Recorde: $best. Toque para jogar de novo.',
      ),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Reflexo')),
      body: Material(
        color: color,
        child: InkWell(
          onTap: _tap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, textAlign: TextAlign.center, style: t.headlineMedium),
                  const SizedBox(height: 8),
                  Text(detail, textAlign: TextAlign.center, style: t.bodyMedium),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
