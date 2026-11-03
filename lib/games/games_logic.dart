import 'dart:math';

import '../core/format.dart';
import '../core/text_norm.dart';

/// Palavras por categoria, para a Forca e a Palavra do dia.
const wordBank = <String, List<String>>{
  'Animais': [
    'cachorro',
    'gato',
    'elefante',
    'girafa',
    'tartaruga',
    'jacaré',
    'capivara',
    'tucano',
    'arara',
    'onça',
    'macaco',
    'baleia',
    'golfinho',
    'coruja',
    'formiga',
    'borboleta',
    'cavalo',
    'coelho',
    'tubarão',
    'pinguim',
    'camelo',
    'raposa',
    'esquilo',
    'gaivota',
    'lagosta',
  ],
  'Comidas': [
    'feijoada',
    'brigadeiro',
    'coxinha',
    'pastel',
    'farofa',
    'tapioca',
    'pamonha',
    'moqueca',
    'acarajé',
    'pipoca',
    'lasanha',
    'macarrão',
    'abacaxi',
    'banana',
    'melancia',
    'goiabada',
    'mandioca',
    'bolacha',
    'canjica',
    'paçoca',
    'chocolate',
    'sanduíche',
    'torrada',
    'azeitona',
    'cebola',
  ],
  'Lugares': [
    'salvador',
    'manaus',
    'recife',
    'curitiba',
    'fortaleza',
    'gramado',
    'bonito',
    'paraty',
    'florianópolis',
    'belém',
    'argentina',
    'portugal',
    'japão',
    'egito',
    'itália',
    'méxico',
    'canadá',
    'noruega',
    'austrália',
    'marrocos',
  ],
  'Objetos': [
    'guarda-chuva',
    'geladeira',
    'travesseiro',
    'tesoura',
    'relógio',
    'escada',
    'martelo',
    'mochila',
    'caneta',
    'espelho',
    'cadeira',
    'lanterna',
    'bicicleta',
    'telefone',
    'panela',
    'chaveiro',
    'cortina',
    'vassoura',
    'carteira',
    'garrafa',
  ],
  'Profissões': [
    'médico',
    'professora',
    'bombeiro',
    'engenheiro',
    'advogado',
    'cozinheiro',
    'motorista',
    'jornalista',
    'carpinteiro',
    'enfermeira',
    'piloto',
    'dentista',
    'padeiro',
    'pedreiro',
    'eletricista',
    'fotógrafo',
    'marinheiro',
    'agricultor',
  ],
  'Natureza': [
    'cachoeira',
    'montanha',
    'floresta',
    'vulcão',
    'arco-íris',
    'relâmpago',
    'deserto',
    'oceano',
    'geleira',
    'furacão',
    'pantanal',
    'cerrado',
    'caatinga',
    'restinga',
    'nascente',
    'planeta',
    'cometa',
    'estrela',
  ],
  'Esportes': [
    'futebol',
    'basquete',
    'natação',
    'capoeira',
    'ciclismo',
    'atletismo',
    'handebol',
    'ginástica',
    'surfe',
    'judô',
    'xadrez',
    'skate',
    'vôlei',
    'remo',
    'esgrima',
  ],
};

class BankWord {
  final String word;
  final String category;

  const BankWord(this.word, this.category);
}

List<BankWord> get allWords => [
  for (final e in wordBank.entries)
    for (final w in e.value) BankWord(w, e.key),
];

int daysSinceEpoch(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2024, 1, 1)).inDays;

/// Só letras a-z, sem acentos.
String lettersOnly(String s) => normalizeKeepLength(s).replaceAll(RegExp(r'[^a-z]'), '');

// ---------- Forca ----------

class HangmanGame {
  static const maxErrors = 6;
  final BankWord target;
  final Set<String> guessed = {};

  HangmanGame(this.target);

  String get _normal => normalizeKeepLength(target.word);

  int get errors => guessed.where((l) => !_normal.contains(l)).length;

  bool get won => lettersOnly(target.word).split('').every(guessed.contains);

  bool get lost => errors >= maxErrors;

  bool get over => won || lost;

  /// Retorna true se a letra existe na palavra. Letra repetida ou jogo encerrado não muda nada.
  bool guess(String letter) {
    final l = normalizeKeepLength(letter);
    if (over || guessed.contains(l)) return _normal.contains(l);
    guessed.add(l);
    return _normal.contains(l);
  }

  /// Palavra com as letras descobertas. Hífen e espaço aparecem desde o início.
  String get masked {
    final n = _normal;
    final b = StringBuffer();
    for (var i = 0; i < target.word.length; i++) {
      final isLetter = RegExp(r'[a-z]').hasMatch(n[i]);
      final shown = !isLetter || guessed.contains(n[i]) || lost;
      b.write(shown ? target.word[i].toUpperCase() : '_');
      if (i < target.word.length - 1) b.write(' ');
    }
    return b.toString();
  }
}

// ---------- Palavra do dia ----------

/// Cada dia tem uma palavra, a mesma durante o dia inteiro. O passo primo evita repetir cedo.
BankWord wordOfDay(DateTime day) {
  final list = allWords.where((w) => !w.word.contains(RegExp(r'[\s-]'))).toList();
  return list[(daysSinceEpoch(day) * 61 % list.length + list.length) % list.length];
}

class GuessFeedback {
  final String guess;

  /// Letras certas no lugar certo.
  final int placed;

  /// Letras que existem na palavra, mas em outro lugar.
  final int present;

  const GuessFeedback(this.guess, this.placed, this.present);
}

GuessFeedback scoreGuess(String guess, String target) {
  final g = lettersOnly(guess), t = lettersOnly(target);
  var placed = 0;
  final restT = <String, int>{};
  final restG = <String, int>{};
  for (var i = 0; i < t.length; i++) {
    if (i < g.length && g[i] == t[i]) {
      placed++;
    } else {
      restT[t[i]] = (restT[t[i]] ?? 0) + 1;
      if (i < g.length) restG[g[i]] = (restG[g[i]] ?? 0) + 1;
    }
  }
  var present = 0;
  restG.forEach((l, n) => present += min(n, restT[l] ?? 0));
  return GuessFeedback(guess, placed, present);
}

class WordDayGame {
  static const maxTries = 8;
  final BankWord target;
  final List<GuessFeedback> tries = [];

  WordDayGame(this.target);

  int get length => lettersOnly(target.word).length;

  bool get won => tries.isNotEmpty && tries.last.placed == length;

  bool get over => won || tries.length >= maxTries;

  /// Uma letra revelada a cada 2 tentativas, sempre nas mesmas posições para a mesma palavra.
  Set<int> get revealed {
    final order = [for (var i = 0; i < length; i++) i]..shuffle(Random(lettersOnly(target.word).hashCodeStable));
    return order.take(min(tries.length ~/ 2, length - 1)).toSet();
  }

  String get hint {
    final t = target.word.toUpperCase();
    final open = revealed;
    return [for (var i = 0; i < length; i++) open.contains(i) || over ? t[i] : '_'].join(' ');
  }

  /// Retorna uma mensagem de erro, ou null se a tentativa foi aceita.
  String? submit(String input) {
    if (over) return 'O jogo de hoje já terminou';
    final g = lettersOnly(input);
    if (g.length != length) return 'A palavra tem $length letras';
    tries.add(scoreGuess(g, target.word));
    return null;
  }

  int get score => won ? (maxTries - tries.length + 1) * 10 : 0;
}

extension on String {
  /// O hashCode de String pode mudar entre execuções; este não muda.
  int get hashCodeStable => codeUnits.fold(7, (h, c) => (h * 31 + c) & 0x3fffffff);
}

// ---------- Caso do dia ----------

const _firstNames = [
  'Helena',
  'Otávio',
  'Marina',
  'Caetano',
  'Beatriz',
  'Rogério',
  'Lúcia',
  'Vicente',
  'Cecília',
  'Augusto',
  'Teresa',
  'Nestor',
  'Iolanda',
  'Rubens',
  'Dalva',
  'Hélio',
  'Yara',
  'Silvério',
];
const _jobs = [
  'jardineiro',
  'cozinheira',
  'motorista',
  'contadora',
  'professor',
  'fotógrafa',
  'médico',
  'arquiteta',
  'relojoeiro',
  'advogada',
  'músico',
  'florista',
];
const _crimes = [
  ('O colar de esmeraldas', 'sumiu do cofre do casarão'),
  ('O quadro mais caro da galeria', 'desapareceu antes da abertura'),
  ('A receita secreta da confeitaria', 'foi roubada da gaveta do dono'),
  ('O troféu do clube', 'sumiu da sala de honra'),
  ('O manuscrito raro', 'não está mais na biblioteca'),
  ('As joias da família', 'foram levadas durante o jantar'),
  ('O relógio de ouro do avô', 'sumiu da cristaleira'),
  ('A partitura inédita', 'desapareceu do conservatório'),
  ('O caixa do festival', 'estava vazio pela manhã'),
  ('O mapa antigo do museu', 'foi trocado por uma cópia'),
  ('A coleção de moedas raras', 'sumiu do escritório'),
  ('O vinho mais antigo da adega', 'não está mais na prateleira'),
  ('O diário do fundador', 'foi tirado do arquivo da cidade'),
  ('A escultura de bronze', 'sumiu do saguão do hotel'),
];
const _places = ['na cozinha', 'no jardim', 'na biblioteca', 'na garagem', 'no porão', 'na varanda'];
const _items = [
  'um casaco verde',
  'um chapéu preto',
  'luvas vermelhas',
  'óculos escuros',
  'um cachecol azul',
  'botas marrons',
];
const _hours = ['antes das 20h', 'entre 20h e 21h', 'depois das 21h'];
const _witnesses = ['A vizinha', 'O vigia', 'A faxineira', 'O entregador', 'A sobrinha', 'O porteiro'];

class Suspect {
  final String name;
  final String job;
  final int place;
  final int item;
  final int hour;

  const Suspect(this.name, this.job, this.place, this.item, this.hour);

  String get placeLabel => _places[place];
  String get itemLabel => _items[item];
  String get hourLabel => _hours[hour];
}

class CaseClue {
  final String witness;
  final String text;

  /// Devolve true se o suspeito é compatível com a pista.
  final bool Function(Suspect) fits;

  const CaseClue(this.witness, this.text, this.fits);
}

class DailyCase {
  final String title;
  final String description;
  final List<Suspect> suspects;
  final Suspect culprit;
  final List<CaseClue> clues;

  const DailyCase(this.title, this.description, this.suspects, this.culprit, this.clues);

  static const baseScore = 100;
  static const cluePenalty = 15;

  int score(int cluesUsed, bool correct) => correct ? max(10, baseScore - cluesUsed * cluePenalty) : 0;
}

/// Caso gerado a partir da data: todos veem o mesmo caso no mesmo dia, e as pistas
/// juntas sempre deixam um único suspeito possível.
DailyCase caseForDay(DateTime day) {
  final r = Random(daysSinceEpoch(day) * 7919 + 13);
  final crime = _crimes[r.nextInt(_crimes.length)];
  final names = [..._firstNames]..shuffle(r);
  final jobs = [..._jobs]..shuffle(r);
  final culprit = Suspect(
    names[0],
    jobs[0],
    r.nextInt(_places.length),
    r.nextInt(_items.length),
    r.nextInt(_hours.length),
  );
  final used = <String>{'${culprit.place}${culprit.item}${culprit.hour}'};
  final others = <Suspect>[];
  for (var i = 1; i < 5; i++) {
    int p, it, h;
    do {
      // Cada suspeito inocente divide ao menos uma característica com o culpado, para o caso não ser óbvio.
      p = r.nextBool() ? culprit.place : r.nextInt(_places.length);
      it = r.nextBool() ? culprit.item : r.nextInt(_items.length);
      h = r.nextBool() ? culprit.hour : r.nextInt(_hours.length);
    } while (!used.add('$p$it$h') || (p != culprit.place && it != culprit.item && h != culprit.hour));
    others.add(Suspect(names[i], jobs[i], p, it, h));
  }
  final suspects = [culprit, ...others]..shuffle(r);

  final wrongPlace =
      ([for (var i = 0; i < _places.length; i++) i]
            ..remove(culprit.place)
            ..shuffle(r))
          .first;
  final wrongItem =
      ([for (var i = 0; i < _items.length; i++) i]
            ..remove(culprit.item)
            ..shuffle(r))
          .first;
  final witnesses = [..._witnesses]..shuffle(r);
  final clues = <CaseClue>[
    CaseClue(
      witnesses[0],
      'Tenho certeza de que quem fez isso não estava ${_places[wrongPlace]}.',
      (s) => s.place != wrongPlace,
    ),
    CaseClue(witnesses[1], 'A pessoa que vi não usava ${_items[wrongItem]}.', (s) => s.item != wrongItem),
    CaseClue(witnesses[2], 'O movimento suspeito foi ${_hours[culprit.hour]}.', (s) => s.hour == culprit.hour),
    CaseClue(
      witnesses[3],
      'Vi alguém ${_places[culprit.place]} pouco antes do sumiço.',
      (s) => s.place == culprit.place,
    ),
    CaseClue(witnesses[4], 'Quem saiu correndo usava ${_items[culprit.item]}.', (s) => s.item == culprit.item),
  ];
  return DailyCase(crime.$1, crime.$2, suspects, culprit, clues);
}

// ---------- Datas das sequências ----------

/// Atualiza a sequência de dias seguidos jogados.
int nextStreak(int current, String? lastDayKey, DateTime today) {
  final key = dayKey(today);
  if (lastDayKey == key) return current;
  final yesterday = dayKey(DateTime(today.year, today.month, today.day - 1));
  return lastDayKey == yesterday ? current + 1 : 1;
}
