import 'package:flutter/foundation.dart';

import '../core/format.dart';
import '../core/json_store.dart';
import 'career.dart';
import 'games_logic.dart';

class GameRecord {
  int best;
  int played;
  int streak;
  String? lastDay;

  GameRecord({this.best = 0, this.played = 0, this.streak = 0, this.lastDay});

  Map<String, dynamic> toJson() => {'best': best, 'played': played, 'streak': streak, 'lastDay': lastDay};

  factory GameRecord.fromJson(Map<String, dynamic> j) => GameRecord(
    best: (j['best'] as num?)?.toInt() ?? 0,
    played: (j['played'] as num?)?.toInt() ?? 0,
    streak: (j['streak'] as num?)?.toInt() ?? 0,
    lastDay: j['lastDay'] as String?,
  );
}

/// Recordes de todos os jogos, progresso dos jogos diários e a carreira em andamento.
class GamesStore extends ChangeNotifier {
  final Map<String, GameRecord> records = {};

  /// Partida diária por jogo: dia e dados necessários para reabrir sem jogar de novo.
  final Map<String, Map<String, dynamic>> daily = {};
  CareerState? career;

  Future<void> load() async {
    final j = await JsonStore.read('games');
    records.clear();
    daily.clear();
    career = null;
    if (j is Map) {
      try {
        records.clear();
        for (final e in ((j['records'] as Map?) ?? const {}).entries) {
          records[e.key as String] = GameRecord.fromJson((e.value as Map).cast<String, dynamic>());
        }
        daily.clear();
        for (final e in ((j['daily'] as Map?) ?? const {}).entries) {
          daily[e.key as String] = (e.value as Map).cast<String, dynamic>();
        }
        final c = j['career'];
        career = c is Map ? CareerState.fromJson(c.cast<String, dynamic>()) : null;
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> save() {
    notifyListeners();
    return JsonStore.write('games', {
      'records': {for (final e in records.entries) e.key: e.value.toJson()},
      'daily': daily,
      'career': career?.toJson(),
    });
  }

  GameRecord record(String game) => records[game] ?? GameRecord();

  /// Registra o resultado. Sequência de dias só em jogos diários e só com vitória.
  Future<void> addResult(String game, int score, {DateTime? dailyWin}) async {
    final r = records.putIfAbsent(game, GameRecord.new);
    r.played++;
    if (score > r.best) r.best = score;
    if (dailyWin != null) {
      r.streak = nextStreak(r.streak, r.lastDay, dailyWin);
      r.lastDay = dayKey(dailyWin);
    }
    await save();
  }

  Map<String, dynamic>? dailyFor(String game, DateTime day) {
    final d = daily[game];
    return d != null && d['day'] == dayKey(day) ? d : null;
  }

  Future<void> setDaily(String game, DateTime day, Map<String, dynamic> data) {
    daily[game] = {...data, 'day': dayKey(day)};
    return save();
  }

  Future<void> setCareer(CareerState? c) {
    career = c;
    return save();
  }
}
