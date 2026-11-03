import 'dart:math';

enum Position {
  atacante('Atacante'),
  meia('Meia'),
  zagueiro('Zagueiro');

  final String label;

  const Position(this.label);
}

enum Skill {
  finalizacao('Finalização'),
  passe('Passe'),
  fisico('Físico'),
  defesa('Defesa');

  final String label;

  const Skill(this.label);
}

/// Divisões e clubes são todos fictícios.
const divisions = ['Liga Regional', 'Terceirona', 'Segundona', 'Primeirona', 'Liga Continental'];
const _salaries = [800, 2500, 9000, 40000, 180000];
const _strength = [35, 48, 60, 72, 84];
const _clubNames = [
  ['Vale Verde', 'Rio Claro do Sul', 'União da Serra', 'Pedra Azul', 'Atlético Sertanejo'],
  ['Porto Alegrete', 'Nova Aurora', 'Esporte Mirante', 'Ferroviário do Vale'],
  ['Real Cerrado', 'Unidos do Litoral', 'Grêmio Horizonte', 'Tupã Atlético'],
  ['Imperial', 'Estrela do Norte', 'Metropolitano', 'Atlântico'],
  ['Sporting Lusitano', 'Internacional de Vigo', 'Atlético do Reno', 'Royal Tâmisa'],
];

const seasonWeeks = 20;
const retireAge = 38;

/// Um lance da partida: a escolha usa uma habilidade e tem um risco próprio.
class PlayOption {
  final String label;
  final Skill skill;

  /// Quanto mais alto, mais difícil dar certo, mas maior a recompensa.
  final int risk;
  final String successText;
  final String failText;
  final bool goal;
  final bool assist;

  const PlayOption(
    this.label,
    this.skill,
    this.risk,
    this.successText,
    this.failText, {
    this.goal = false,
    this.assist = false,
  });
}

class PlayScene {
  final String text;
  final List<PlayOption> options;

  const PlayScene(this.text, this.options);
}

const _attackScenes = [
  PlayScene('Você recebe na entrada da área, com um zagueiro por perto.', [
    PlayOption('Chutar de primeira', Skill.finalizacao, 18, 'Bola no canto. Gol!', 'O chute sai por cima.', goal: true),
    PlayOption(
      'Tocar para o companheiro',
      Skill.passe,
      2,
      'Passe perfeito, e ele marca!',
      'O passe é interceptado.',
      assist: true,
    ),
    PlayOption('Proteger e sofrer a falta', Skill.fisico, -8, 'Falta cavada em boa posição.', 'Você perde a dividida.'),
  ]),
  PlayScene('Contra-ataque: você dispara pelo meio com espaço.', [
    PlayOption(
      'Bater de longe',
      Skill.finalizacao,
      28,
      'Que chute! Gol de fora da área!',
      'O goleiro defende fácil.',
      goal: true,
    ),
    PlayOption(
      'Correr até a área',
      Skill.fisico,
      12,
      'Você vence na corrida e fica cara a cara: gol!',
      'O zagueiro alcança e desarma.',
      goal: true,
    ),
    PlayOption(
      'Abrir na ponta',
      Skill.passe,
      6,
      'Cruzamento na medida, e sai o gol!',
      'A jogada acaba em lateral.',
      assist: true,
    ),
  ]),
];

const _midScenes = [
  PlayScene('Você domina no meio-campo e olha para frente.', [
    PlayOption(
      'Lançamento longo',
      Skill.passe,
      14,
      'Lançamento preciso: assistência!',
      'A bola passa direto.',
      assist: true,
    ),
    PlayOption(
      'Avançar conduzindo',
      Skill.fisico,
      2,
      'Você ganha metros e dá ritmo ao time.',
      'Você perde a bola no meio.',
    ),
    PlayOption(
      'Arriscar o chute',
      Skill.finalizacao,
      30,
      'De longe, no ângulo. Golaço!',
      'A bola vai para a arquibancada.',
      goal: true,
    ),
  ]),
  PlayScene('O adversário pressiona e seu time precisa sair jogando.', [
    PlayOption('Toque de primeira', Skill.passe, 4, 'Saída limpa, e o time respira.', 'O toque sai curto.'),
    PlayOption(
      'Dar um passe entre as linhas',
      Skill.passe,
      20,
      'Passe genial: assistência!',
      'A defesa corta o passe.',
      assist: true,
    ),
    PlayOption('Dar o combate', Skill.defesa, 6, 'Você recupera a bola.', 'Você faz falta perigosa.'),
  ]),
];

const _defenseScenes = [
  PlayScene('O atacante adversário vem em velocidade na sua direção.', [
    PlayOption('Dar o bote', Skill.defesa, 14, 'Desarme limpo!', 'Ele passa por você.'),
    PlayOption(
      'Acompanhar na corrida',
      Skill.fisico,
      4,
      'Você fecha o caminho e ele desiste.',
      'Ele ganha na velocidade.',
    ),
    PlayOption(
      'Sair jogando depois de roubar',
      Skill.passe,
      22,
      'Rouba e lança: assistência!',
      'O lançamento sai longo.',
      assist: true,
    ),
  ]),
  PlayScene('Escanteio a favor: você sobe para a área.', [
    PlayOption(
      'Cabecear no gol',
      Skill.finalizacao,
      20,
      'Cabeçada firme. Gol de zagueiro!',
      'A bola sai à direita.',
      goal: true,
    ),
    PlayOption('Ganhar no físico', Skill.fisico, 8, 'Você abre espaço e ajuda a jogada.', 'A defesa afasta.'),
    PlayOption(
      'Voltar para a cobertura',
      Skill.defesa,
      -6,
      'Boa leitura: nenhum perigo no contra-ataque.',
      'Mesmo assim, o contra-ataque assusta.',
    ),
  ]),
];

List<PlayScene> scenesFor(Position p) => switch (p) {
  Position.atacante => _attackScenes,
  Position.meia => _midScenes,
  Position.zagueiro => _defenseScenes,
};

class MatchReport {
  final String opponent;
  final int goalsFor;
  final int goalsAgainst;
  final int playerGoals;
  final int playerAssists;
  final double rating;

  const MatchReport(this.opponent, this.goalsFor, this.goalsAgainst, this.playerGoals, this.playerAssists, this.rating);

  bool get won => goalsFor > goalsAgainst;
}

class SeasonSummary {
  final int season;
  final String division;
  final String club;
  final double average;
  final int goals;
  final int assists;

  /// 1 = subiu, 0 = ficou, -1 = caiu.
  final int movement;
  final String newClub;

  const SeasonSummary(
    this.season,
    this.division,
    this.club,
    this.average,
    this.goals,
    this.assists,
    this.movement,
    this.newClub,
  );
}

class CareerState {
  String name;
  Position position;
  int age;
  Map<Skill, int> skills;
  int energy;
  int money;
  int division;
  String club;
  int season;
  int week;
  int seasonGoals;
  int seasonAssists;
  double seasonRatingSum;
  int seasonMatches;
  int totalGoals;
  int totalAssists;
  int totalMatches;
  int promotions;
  bool retired;

  CareerState({
    required this.name,
    required this.position,
    this.age = 17,
    required this.skills,
    this.energy = 100,
    this.money = 0,
    this.division = 0,
    required this.club,
    this.season = 1,
    this.week = 1,
    this.seasonGoals = 0,
    this.seasonAssists = 0,
    this.seasonRatingSum = 0,
    this.seasonMatches = 0,
    this.totalGoals = 0,
    this.totalAssists = 0,
    this.totalMatches = 0,
    this.promotions = 0,
    this.retired = false,
  });

  factory CareerState.start(String name, Position position, Random random) {
    final base = {
      Position.atacante: {Skill.finalizacao: 38, Skill.passe: 28, Skill.fisico: 32, Skill.defesa: 18},
      Position.meia: {Skill.finalizacao: 26, Skill.passe: 40, Skill.fisico: 30, Skill.defesa: 26},
      Position.zagueiro: {Skill.finalizacao: 18, Skill.passe: 26, Skill.fisico: 36, Skill.defesa: 40},
    }[position]!;
    return CareerState(
      name: name,
      position: position,
      skills: {...base},
      club: _clubNames[0][random.nextInt(_clubNames[0].length)],
    );
  }

  int skill(Skill s) => skills[s] ?? 1;

  int get overall => (skills.values.fold<int>(0, (a, b) => a + b) / skills.length).round();

  int get salary => _salaries[division];

  double get seasonAverage => seasonMatches == 0 ? 0 : seasonRatingSum / seasonMatches;

  /// Pontuação final da carreira, usada nos recordes.
  int get careerScore => totalGoals * 10 + totalAssists * 7 + promotions * 100 + totalMatches;

  /// Treino melhora uma habilidade, com ganho menor quanto mais alta ela estiver.
  int train(Skill s, Random random) {
    if (energy < 20) return 0;
    final current = skill(s);
    final gain = current < 50 ? 2 + random.nextInt(2) : (current < 75 ? 1 + random.nextInt(2) : random.nextInt(2));
    skills[s] = min(99, current + gain);
    energy = max(0, energy - 25);
    return gain;
  }

  void rest() => energy = min(100, energy + 40);

  /// Chance de 5% a 95%: habilidade contra a força da divisão e o risco do lance. Cansaço atrapalha.
  double chance(PlayOption o) {
    final tired = energy < 30 ? 10 : 0;
    final value = 55 + skill(o.skill) - _strength[division] - o.risk - tired;
    return value.clamp(5, 95) / 100;
  }

  String opponentName(Random random) {
    final others = _clubNames[division].where((c) => c != club).toList();
    return others[random.nextInt(others.length)];
  }

  /// Fecha a partida depois dos lances e devolve o placar e a nota.
  MatchReport finishMatch({
    required String opponent,
    required int goals,
    required int assists,
    required int plays,
    required int successes,
    required Random random,
  }) {
    final teamPower = 0.8 + overall / 90;
    final rivalPower = 0.6 + _strength[division] / 80;
    final extra = _poisson(teamPower, random);
    final against = _poisson(rivalPower, random);
    final rate = plays == 0 ? 0.0 : successes / plays;
    final rating = (5 + rate * 2.5 + goals * 1.1 + assists * 0.8 - (energy < 30 ? 0.5 : 0)).clamp(3.0, 10.0).toDouble();
    energy = max(0, energy - 15);
    seasonGoals += goals;
    seasonAssists += assists;
    seasonRatingSum += rating;
    seasonMatches++;
    totalGoals += goals;
    totalAssists += assists;
    totalMatches++;
    money += salary;
    final teamGoals = extra + goals + assists;
    week++;
    return MatchReport(opponent, teamGoals, against, goals, assists, rating);
  }

  bool get seasonOver => week > seasonWeeks;

  /// Sobe com média alta, cai com média baixa. A idade pesa depois dos 32 anos.
  SeasonSummary closeSeason(Random random) {
    final average = seasonAverage;
    final oldDivision = division, oldClub = club;
    var movement = 0;
    if (average >= 7.0 && division < divisions.length - 1) {
      movement = 1;
    } else if (average < 5.5 && division > 0) {
      movement = -1;
    }
    division += movement;
    if (movement > 0) promotions++;
    if (movement != 0) club = _clubNames[division][random.nextInt(_clubNames[division].length)];
    final summary = SeasonSummary(
      season,
      divisions[oldDivision],
      oldClub,
      average,
      seasonGoals,
      seasonAssists,
      movement,
      club,
    );
    age++;
    if (age > 32) {
      for (final s in Skill.values) {
        skills[s] = max(1, skill(s) - 1 - random.nextInt(2));
      }
    }
    season++;
    week = 1;
    energy = 100;
    seasonGoals = 0;
    seasonAssists = 0;
    seasonRatingSum = 0;
    seasonMatches = 0;
    if (age >= retireAge) retired = true;
    return summary;
  }

  int _poisson(double lambda, Random random) {
    final limit = exp(-lambda);
    var k = 0;
    var p = 1.0;
    do {
      k++;
      p *= random.nextDouble();
    } while (p > limit);
    return k - 1;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'position': position.name,
    'age': age,
    'skills': {for (final e in skills.entries) e.key.name: e.value},
    'energy': energy,
    'money': money,
    'division': division,
    'club': club,
    'season': season,
    'week': week,
    'seasonGoals': seasonGoals,
    'seasonAssists': seasonAssists,
    'seasonRatingSum': seasonRatingSum,
    'seasonMatches': seasonMatches,
    'totalGoals': totalGoals,
    'totalAssists': totalAssists,
    'totalMatches': totalMatches,
    'promotions': promotions,
    'retired': retired,
  };

  factory CareerState.fromJson(Map<String, dynamic> j) {
    int n(String k, int fallback) => (j[k] as num?)?.toInt() ?? fallback;
    final raw = (j['skills'] as Map?) ?? const {};
    return CareerState(
      name: j['name'] as String? ?? 'Jogador',
      position: Position.values.where((p) => p.name == j['position']).firstOrNull ?? Position.atacante,
      age: n('age', 17),
      skills: {for (final s in Skill.values) s: (raw[s.name] as num?)?.toInt() ?? 20},
      energy: n('energy', 100),
      money: n('money', 0),
      division: n('division', 0).clamp(0, divisions.length - 1),
      club: j['club'] as String? ?? _clubNames[0][0],
      season: n('season', 1),
      week: n('week', 1),
      seasonGoals: n('seasonGoals', 0),
      seasonAssists: n('seasonAssists', 0),
      seasonRatingSum: (j['seasonRatingSum'] as num?)?.toDouble() ?? 0,
      seasonMatches: n('seasonMatches', 0),
      totalGoals: n('totalGoals', 0),
      totalAssists: n('totalAssists', 0),
      totalMatches: n('totalMatches', 0),
      promotions: n('promotions', 0),
      retired: j['retired'] as bool? ?? false,
    );
  }
}
