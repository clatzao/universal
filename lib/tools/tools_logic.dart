import 'dart:math';

// ---------- Conversor de unidades ----------

class Unit {
  final String id;
  final String label;

  /// Fator para a unidade-base do grupo (ignorado em temperatura).
  final double factor;

  const Unit(this.id, this.label, this.factor);
}

class UnitGroup {
  final String label;
  final List<Unit> units;

  const UnitGroup(this.label, this.units);
}

const temperatureGroup = UnitGroup('Temperatura', [
  Unit('c', 'Celsius (°C)', 1),
  Unit('f', 'Fahrenheit (°F)', 1),
  Unit('k', 'Kelvin (K)', 1),
]);

const unitGroups = <UnitGroup>[
  UnitGroup('Distância', [
    Unit('mm', 'Milímetro (mm)', 0.001),
    Unit('cm', 'Centímetro (cm)', 0.01),
    Unit('m', 'Metro (m)', 1),
    Unit('km', 'Quilômetro (km)', 1000),
    Unit('in', 'Polegada (in)', 0.0254),
    Unit('ft', 'Pé (ft)', 0.3048),
    Unit('yd', 'Jarda (yd)', 0.9144),
    Unit('mi', 'Milha (mi)', 1609.344),
  ]),
  UnitGroup('Peso', [
    Unit('mg', 'Miligrama (mg)', 0.000001),
    Unit('g', 'Grama (g)', 0.001),
    Unit('kg', 'Quilo (kg)', 1),
    Unit('t', 'Tonelada (t)', 1000),
    Unit('oz', 'Onça (oz)', 0.028349523125),
    Unit('lb', 'Libra (lb)', 0.45359237),
  ]),
  temperatureGroup,
  UnitGroup('Área', [
    Unit('m2', 'Metro² (m²)', 1),
    Unit('km2', 'Quilômetro² (km²)', 1000000),
    Unit('ha', 'Hectare (ha)', 10000),
    Unit('alq', 'Alqueire paulista', 24200),
    Unit('ft2', 'Pé² (ft²)', 0.09290304),
  ]),
  UnitGroup('Volume', [
    Unit('ml', 'Mililitro (ml)', 0.001),
    Unit('l', 'Litro (l)', 1),
    Unit('m3', 'Metro³ (m³)', 1000),
    Unit('gal', 'Galão americano', 3.785411784),
    Unit('cup', 'Xícara (240 ml)', 0.24),
    Unit('tbsp', 'Colher de sopa (15 ml)', 0.015),
  ]),
  UnitGroup('Tempo', [
    Unit('s', 'Segundo', 1),
    Unit('min', 'Minuto', 60),
    Unit('h', 'Hora', 3600),
    Unit('d', 'Dia', 86400),
    Unit('w', 'Semana', 604800),
  ]),
  UnitGroup('Velocidade', [
    Unit('kmh', 'km/h', 1 / 3.6),
    Unit('ms', 'm/s', 1),
    Unit('mph', 'mph', 0.44704),
    Unit('kn', 'Nó', 0.514444),
  ]),
  UnitGroup('Dados', [
    Unit('kb', 'KB', 1000),
    Unit('mb', 'MB', 1000000),
    Unit('gb', 'GB', 1000000000),
    Unit('tb', 'TB', 1000000000000),
  ]),
];

double _toCelsius(double v, String id) => switch (id) {
  'f' => (v - 32) * 5 / 9,
  'k' => v - 273.15,
  _ => v,
};

double _fromCelsius(double c, String id) => switch (id) {
  'f' => c * 9 / 5 + 32,
  'k' => c + 273.15,
  _ => c,
};

double convertUnit(double value, UnitGroup group, Unit from, Unit to) {
  if (identical(group, temperatureGroup)) return _fromCelsius(_toCelsius(value, from.id), to.id);
  return value * from.factor / to.factor;
}

/// Reais por unidade de cada moeda. BRL vale 1.
double convertCurrency(double value, double fromInBrl, double toInBrl) => value * fromInBrl / toInBrl;

/// Até 6 casas decimais, sem zeros sobrando, com vírgula.
String formatNumber(double v) {
  if (v.isNaN || v.isInfinite) return '—';
  var s = v.toStringAsFixed(6);
  s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return (s.isEmpty || s == '-0' ? '0' : s).replaceAll('.', ',');
}

/// Aceita "1234,5", "1.234,5" e "1234.5".
double? parseNumber(String input) {
  var t = input.trim();
  if (t.isEmpty) return null;
  if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}

// ---------- Dividir conta ----------

/// Partes em centavos que somam exatamente o total. Os centavos que sobram vão para as primeiras.
List<int> splitEqually(int cents, int people) {
  if (people <= 0) return const [];
  final base = cents ~/ people;
  final rest = cents - base * people;
  return [for (var i = 0; i < people; i++) base + (i < rest ? 1 : 0)];
}

int addTip(int cents, double tipPercent) => cents + (cents * tipPercent / 100).round();

/// Cada pessoa paga o que consumiu mais a parte dela no valor compartilhado e na gorjeta,
/// proporcional ao consumo. O resultado soma exatamente o total com gorjeta.
List<int> splitByConsumption(List<int> consumed, int shared, double tipPercent) {
  if (consumed.isEmpty) return const [];
  final sharedParts = splitEqually(shared, consumed.length);
  final bases = [for (var i = 0; i < consumed.length; i++) consumed[i] + sharedParts[i]];
  final subtotal = bases.fold<int>(0, (s, v) => s + v);
  final total = addTip(subtotal, tipPercent);
  if (subtotal == 0) return splitEqually(total, consumed.length);
  final out = [for (final b in bases) (b * total / subtotal).floor()];
  var missing = total - out.fold<int>(0, (s, v) => s + v);
  for (var i = 0; missing > 0; i = (i + 1) % out.length, missing--) {
    out[i]++;
  }
  return out;
}

// ---------- Porcentagem ----------

double percentOf(double percent, double value) => value * percent / 100;

double applyIncrease(double value, double percent) => value * (1 + percent / 100);

double applyDiscount(double value, double percent) => value * (1 - percent / 100);

/// Quantos por cento [part] é de [whole].
double? whatPercent(double part, double whole) => whole == 0 ? null : part / whole * 100;

/// Variação percentual de [from] para [to].
double? percentChange(double from, double to) => from == 0 ? null : (to - from) / from * 100;

// ---------- Juros e parcelas ----------

class CompoundResult {
  final double total;
  final double invested;

  const CompoundResult(this.total, this.invested);

  double get interest => total - invested;
}

/// Juros compostos com aporte no fim de cada mês. Taxa em % ao mês.
CompoundResult compound({
  required double initial,
  required double monthlyRate,
  required int months,
  double monthly = 0,
}) {
  final i = monthlyRate / 100;
  final factor = pow(1 + i, months).toDouble();
  final total = i == 0 ? initial + monthly * months : initial * factor + monthly * (factor - 1) / i;
  return CompoundResult(total, initial + monthly * months);
}

/// Parcela fixa de um financiamento (tabela Price). Taxa em % ao mês.
double installmentValue({required double principal, required double monthlyRate, required int months}) {
  if (months <= 0) return 0;
  final i = monthlyRate / 100;
  if (i == 0) return principal / months;
  return principal * i / (1 - pow(1 + i, -months));
}

/// Taxa mensal embutida (%) quando [principal] à vista vira [months] parcelas de [installment].
double? impliedMonthlyRate({required double principal, required double installment, required int months}) {
  if (principal <= 0 || installment <= 0 || months <= 0) return null;
  if (installment * months < principal) return null;
  if ((installment * months - principal).abs() < 0.005) return 0;
  var low = 0.0, high = 10.0;
  for (var k = 0; k < 200; k++) {
    final mid = (low + high) / 2;
    if (installmentValue(principal: principal, monthlyRate: mid * 100, months: months) > installment) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return (low + high) / 2 * 100;
}

/// Quanto valem hoje [months] parcelas de [installment] se o dinheiro rende [monthlyReturn]% ao mês.
/// Se o resultado for menor que o preço à vista, parcelar compensa.
double presentValue({required double installment, required int months, required double monthlyReturn}) {
  final i = monthlyReturn / 100;
  if (i == 0) return installment * months;
  return installment * (1 - pow(1 + i, -months)) / i;
}

// ---------- Sorteio ----------

/// Separa nomes de lista digitada por linhas ou vírgulas.
List<String> parseNames(String text) =>
    text.split(RegExp(r'[\n,;]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

int drawNumber(int min, int max, Random random) => min + random.nextInt(max - min + 1);

/// Sorteia [count] números sem repetir.
List<int> drawNumbers(int min, int max, int count, Random random) {
  final pool = [for (var i = min; i <= max; i++) i]..shuffle(random);
  return pool.take(count.clamp(0, pool.length)).toList();
}

/// Times com [perTeam] pessoas. Quem sobrar fica num último time menor, avisado na tela.
List<List<String>> drawTeams(List<String> people, int perTeam, Random random) {
  if (perTeam <= 0 || people.isEmpty) return const [];
  final shuffled = [...people]..shuffle(random);
  return [for (var i = 0; i < shuffled.length; i += perTeam) shuffled.sublist(i, min(i + perTeam, shuffled.length))];
}

// ---------- Senhas ----------

const _lower = 'abcdefghijkmnopqrstuvwxyz';
const _upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const _digits = '23456789';
const _symbols = '!@#\$%&*-_=+?';

/// Senha aleatória com ao menos um caractere de cada tipo escolhido. Sem caracteres parecidos (l, I, O, 0, 1).
String generatePassword({int length = 16, bool upper = true, bool digits = true, bool symbols = true, Random? random}) {
  final r = random ?? Random.secure();
  final groups = [_lower, if (upper) _upper, if (digits) _digits, if (symbols) _symbols];
  final size = max(length, groups.length);
  final all = groups.join();
  final chars = [
    for (final g in groups) g[r.nextInt(g.length)],
    for (var i = groups.length; i < size; i++) all[r.nextInt(all.length)],
  ]..shuffle(r);
  return chars.join();
}
