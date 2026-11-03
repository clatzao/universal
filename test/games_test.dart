import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal/games/career.dart';
import 'package:universal/games/games_logic.dart';

void main() {
  group('banco de palavras', () {
    test('sem repetição dentro de cada categoria', () {
      for (final e in wordBank.entries) {
        expect(e.value.toSet().length, e.value.length, reason: e.key);
      }
    });
  });

  group('forca', () {
    test('acentos contam como a letra simples', () {
      final g = HangmanGame(const BankWord('jacaré', 'Animais'));
      expect(g.guess('e'), isTrue);
      expect(g.masked, '_ _ _ _ _ É');
    });

    test('hífen já aparece e não precisa ser adivinhado', () {
      final g = HangmanGame(const BankWord('arco-íris', 'Natureza'));
      expect(g.masked, contains('-'));
      for (final l in 'arcois'.split('')) {
        g.guess(l);
      }
      expect(g.won, isTrue);
    });

    test('perde com 6 erros, mostra a palavra e para de aceitar letras', () {
      final g = HangmanGame(const BankWord('gato', 'Animais'));
      for (final l in 'bcdefh'.split('')) {
        g.guess(l);
      }
      expect(g.lost, isTrue);
      expect(g.masked, 'G A T O');
      g.guess('g');
      expect(g.guessed.contains('g'), isFalse);
    });

    test('letra repetida não conta dois erros', () {
      final g = HangmanGame(const BankWord('gato', 'Animais'));
      g.guess('z');
      g.guess('z');
      expect(g.errors, 1);
    });
  });

  group('palavra do dia', () {
    test('mesma palavra no mesmo dia e sem hífen', () {
      expect(wordOfDay(DateTime(2026, 11, 3, 8)).word, wordOfDay(DateTime(2026, 11, 3, 23)).word);
      final seen = {for (var i = 0; i < 365; i++) wordOfDay(DateTime(2026, 1, 1 + i)).word};
      expect(seen.length, greaterThan(100));
      expect(seen.any((w) => w.contains('-')), isFalse);
    });

    test('contagem certa de letras, inclusive repetidas', () {
      final a = scoreGuess('gato', 'gato');
      expect((a.placed, a.present), (4, 0));
      final b = scoreGuess('toga', 'gato');
      expect((b.placed, b.present), (0, 4));
      final c = scoreGuess('aaaa', 'gato');
      expect((c.placed, c.present), (1, 0));
      final d = scoreGuess('arara', 'barco');
      expect((d.placed, d.present), (0, 2));
    });

    test('acentos são ignorados', () {
      expect(scoreGuess('jacare', 'jacaré').placed, 6);
    });

    test('recusa tamanho errado, sem gastar tentativa', () {
      final g = WordDayGame(const BankWord('gato', 'Animais'));
      expect(g.submit('cachorro'), 'A palavra tem 4 letras');
      expect(g.tries, isEmpty);
    });

    test('vencer pontua mais com menos tentativas', () {
      final g = WordDayGame(const BankWord('gato', 'Animais'));
      expect(g.submit('pato'), isNull);
      expect(g.won, isFalse);
      expect(g.submit('gato'), isNull);
      expect(g.won, isTrue);
      expect(g.score, 70);
      expect(g.submit('pato'), isNotNull);
    });

    test('revela uma letra a cada 2 tentativas, sem entregar tudo', () {
      final g = WordDayGame(const BankWord('gato', 'Animais'));
      g.submit('pato');
      expect(g.revealed, isEmpty);
      g.submit('mato');
      expect(g.revealed.length, 1);
      for (var i = 0; i < 5; i++) {
        g.submit('rato');
      }
      expect(g.revealed.length, lessThan(4));
    });

    test('acaba em 8 tentativas e mostra a palavra', () {
      final g = WordDayGame(const BankWord('gato', 'Animais'));
      for (var i = 0; i < 8; i++) {
        g.submit('pato');
      }
      expect(g.over, isTrue);
      expect(g.won, isFalse);
      expect(g.score, 0);
      expect(g.hint, 'G A T O');
    });
  });

  group('caso do dia', () {
    test('em 2 anos, todas as pistas juntas apontam só para o culpado', () {
      for (var i = 0; i < 730; i++) {
        final c = caseForDay(DateTime(2026, 1, 1 + i));
        expect(c.suspects.length, 5);
        expect(c.suspects.map((s) => s.name).toSet().length, 5);
        expect(c.suspects, contains(c.culprit));
        final left = c.suspects.where((s) => c.clues.every((k) => k.fits(s))).toList();
        expect(left, [c.culprit], reason: 'dia $i');
      }
    });

    test('toda pista é verdadeira sobre o culpado', () {
      for (var i = 0; i < 100; i++) {
        final c = caseForDay(DateTime(2026, 3, 1 + i));
        expect(c.clues.every((k) => k.fits(c.culprit)), isTrue);
      }
    });

    test('mesmo caso durante o dia', () {
      final a = caseForDay(DateTime(2026, 11, 3, 1));
      final b = caseForDay(DateTime(2026, 11, 3, 22));
      expect(a.culprit.name, b.culprit.name);
    });

    test('pontuação cai com as pistas e erro vale zero', () {
      final c = caseForDay(DateTime(2026, 11, 3));
      expect(c.score(0, true), 100);
      expect(c.score(2, true), 70);
      expect(c.score(5, true), 25);
      expect(c.score(1, false), 0);
    });
  });

  test('sequência de dias', () {
    final today = DateTime(2026, 11, 3);
    expect(nextStreak(0, null, today), 1);
    expect(nextStreak(4, '2026-11-02', today), 5);
    expect(nextStreak(4, '2026-11-03', today), 4);
    expect(nextStreak(4, '2026-10-30', today), 1);
  });

  group('carreira', () {
    CareerState start([Position p = Position.atacante]) => CareerState.start('Teste', p, Random(1));

    test('começa pela divisão mais baixa e com habilidades da posição', () {
      final s = start();
      expect(s.division, 0);
      expect(s.age, 17);
      expect(s.skill(Skill.finalizacao), greaterThan(s.skill(Skill.defesa)));
      final z = start(Position.zagueiro);
      expect(z.skill(Skill.defesa), greaterThan(z.skill(Skill.finalizacao)));
    });

    test('treino gasta energia e sobe habilidade até o limite', () {
      final s = start();
      final before = s.skill(Skill.passe);
      final gain = s.train(Skill.passe, Random(2));
      expect(s.skill(Skill.passe), before + gain);
      expect(s.energy, 75);
      s.skills[Skill.passe] = 99;
      s.train(Skill.passe, Random(2));
      expect(s.skill(Skill.passe), 99);
    });

    test('sem energia não treina; descanso recupera até 100', () {
      final s = start()..energy = 10;
      final before = s.skill(Skill.passe);
      expect(s.train(Skill.passe, Random(2)), 0);
      expect(s.skill(Skill.passe), before);
      s.rest();
      expect(s.energy, 50);
      s
        ..energy = 90
        ..rest();
      expect(s.energy, 100);
    });

    test('chance fica entre 5% e 95%, e risco e cansaço atrapalham', () {
      const easy = PlayOption('a', Skill.finalizacao, 0, '', '');
      const hard = PlayOption('b', Skill.finalizacao, 30, '', '');
      final s = start();
      expect(s.chance(easy), greaterThan(s.chance(hard)));
      final rested = s.chance(easy);
      s.energy = 10;
      expect(s.chance(easy), lessThan(rested));
      s.skills[Skill.finalizacao] = 99;
      expect(s.chance(easy), lessThanOrEqualTo(0.95));
      s
        ..skills[Skill.finalizacao] = 1
        ..division = 4;
      expect(s.chance(hard), 0.05);
    });

    test('toda posição tem lances com opções', () {
      for (final p in Position.values) {
        for (final scene in scenesFor(p)) {
          expect(scene.options.length, 3);
        }
      }
    });

    test('partida registra números, nota, salário e semana', () {
      final s = start();
      final r = s.finishMatch(opponent: 'X', goals: 2, assists: 1, plays: 2, successes: 2, random: Random(3));
      expect(r.playerGoals, 2);
      expect(r.goalsFor, greaterThanOrEqualTo(3));
      expect(r.rating, greaterThan(7));
      expect(s.totalGoals, 2);
      expect(s.week, 2);
      expect(s.money, s.salary);
      expect(s.energy, 85);
    });

    test('média alta sobe de divisão, média baixa cai', () {
      final s = start()
        ..seasonRatingSum = 80
        ..seasonMatches = 10;
      final up = s.closeSeason(Random(4));
      expect(up.movement, 1);
      expect(s.division, 1);
      expect(s.promotions, 1);
      expect(s.age, 18);
      expect(s.week, 1);
      expect(s.seasonMatches, 0);
      s
        ..seasonRatingSum = 40
        ..seasonMatches = 10;
      expect(s.closeSeason(Random(4)).movement, -1);
      expect(s.division, 0);
    });

    test('não cai abaixo da primeira nem sobe acima da última divisão', () {
      final low = start()
        ..seasonRatingSum = 10
        ..seasonMatches = 10;
      expect(low.closeSeason(Random(4)).movement, 0);
      final top = start()
        ..division = divisions.length - 1
        ..seasonRatingSum = 90
        ..seasonMatches = 10;
      expect(top.closeSeason(Random(4)).movement, 0);
    });

    test('envelhece, perde habilidade depois dos 32 e se aposenta aos 38', () {
      final s = start()..age = 33;
      final before = s.skill(Skill.fisico);
      s.closeSeason(Random(5));
      expect(s.skill(Skill.fisico), lessThan(before));
      s.age = 37;
      s.closeSeason(Random(5));
      expect(s.retired, isTrue);
    });

    test('JSON preserva a carreira e tolera campos ausentes', () {
      final s = start(Position.meia)
        ..totalGoals = 12
        ..division = 2
        ..seasonRatingSum = 21.5;
      final back = CareerState.fromJson(s.toJson());
      expect(back.position, Position.meia);
      expect(back.totalGoals, 12);
      expect(back.division, 2);
      expect(back.seasonRatingSum, 21.5);
      expect(back.skill(Skill.passe), s.skill(Skill.passe));
      expect(CareerState.fromJson({}).skills.length, 4);
      expect(CareerState.fromJson({'division': 99}).division, divisions.length - 1);
    });

    test('simulação de carreira inteira nunca quebra e termina', () {
      for (var seed = 0; seed < 20; seed++) {
        final r = Random(seed);
        final s = CareerState.start('Sim', Position.values[seed % 3], r);
        var guard = 0;
        while (!s.retired) {
          expect(guard++, lessThan(1000));
          if (s.seasonOver) {
            s.closeSeason(r);
            continue;
          }
          if (s.energy < 40) {
            s.rest();
          } else {
            s.train(Skill.values[r.nextInt(4)], r);
          }
          s.finishMatch(
            opponent: s.opponentName(r),
            goals: r.nextInt(2),
            assists: r.nextInt(2),
            plays: 2,
            successes: r.nextInt(3),
            random: r,
          );
          expect(s.skills.values.every((v) => v >= 1 && v <= 99), isTrue);
          expect(s.energy, inInclusiveRange(0, 100));
        }
        expect(s.careerScore, greaterThan(0));
      }
    });
  });
}
