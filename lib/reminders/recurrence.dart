import 'holidays.dart';

/// Hora e minuto de um dia.
class HM implements Comparable<HM> {
  final int h;
  final int m;

  const HM(this.h, this.m);

  int get minutes => h * 60 + m;

  factory HM.parse(String s) {
    final p = s.split(':');
    return HM(int.parse(p[0]), int.parse(p[1]));
  }

  String format() => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  DateTime on(DateTime day) => DateTime(day.year, day.month, day.day, h, m);

  @override
  String toString() => format();

  @override
  bool operator ==(Object other) => other is HM && other.h == h && other.m == m;

  @override
  int get hashCode => minutes;

  @override
  int compareTo(HM other) => minutes.compareTo(other.minutes);
}

enum RecKind {
  once,
  weekly,
  interval,
  monthlyDay,
  monthlyNth,
  yearly,
  afterCompletion,
  relativeDate,
  chain,
  location,
  condition,
}

enum IntervalUnit { minutes, hours, days }

/// O que fazer quando a data cai em fim de semana ou feriado.
enum BusinessRule { ignore, skip, next, previous }

enum ConditionType {
  rainToday,
  rainTomorrow,
  tempAbove,
  tempBelow,
  usdAbove,
  usdBelow,
  eurAbove,
  eurBelow,
  btcAbove,
  btcBelow,
}

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// Regra de repetição de um lembrete. Imutável e serializável em JSON.
class Recurrence {
  final RecKind kind;

  /// [RecKind.once]: data e hora.
  final DateTime? at;

  /// Horários do dia (vazio = 09:00).
  final List<HM> times;

  /// 1 = segunda … 7 = domingo. Vazio = todos os dias.
  final Set<int> weekdays;

  /// [RecKind.interval] / [RecKind.afterCompletion].
  final int every;
  final IntervalUnit unit;
  final HM? windowStart;
  final HM? windowEnd;

  /// Ponto de partida de intervalos contínuos.
  final DateTime? anchor;

  /// [RecKind.monthlyDay]: 1..31 (31 = último dia).
  final int monthDay;

  /// [RecKind.monthlyNth]: 1..5 ou -1 (último).
  final int nth;
  final int nthWeekday;

  /// [RecKind.yearly] e data-alvo anual.
  final int month;
  final int day;

  /// [RecKind.relativeDate]: data-alvo e deslocamentos em dias (negativos = antes).
  final DateTime? target;
  final List<int> offsets;
  final bool repeatYearly;

  /// [RecKind.chain]: id do lembrete A e atraso em minutos.
  final String? chainFrom;
  final int chainDelayMin;

  /// [RecKind.location]
  final double? lat;
  final double? lon;
  final int radiusM;
  final bool onEnter;
  final String? placeName;

  /// [RecKind.condition]
  final ConditionType? condition;
  final double threshold;

  final BusinessRule businessRule;

  const Recurrence({
    required this.kind,
    this.at,
    this.times = const [],
    this.weekdays = const {},
    this.every = 1,
    this.unit = IntervalUnit.hours,
    this.windowStart,
    this.windowEnd,
    this.anchor,
    this.monthDay = 1,
    this.nth = 1,
    this.nthWeekday = 1,
    this.month = 1,
    this.day = 1,
    this.target,
    this.offsets = const [],
    this.repeatYearly = false,
    this.chainFrom,
    this.chainDelayMin = 0,
    this.lat,
    this.lon,
    this.radiusM = 200,
    this.onEnter = true,
    this.placeName,
    this.condition,
    this.threshold = 0,
    this.businessRule = BusinessRule.ignore,
  });

  bool get isTimeBased => kind != RecKind.location && kind != RecKind.condition;

  List<HM> get effectiveTimes => times.isEmpty ? const [HM(9, 0)] : ([...times]..sort());

  int get unitMinutes => switch (unit) {
        IntervalUnit.minutes => every,
        IntervalUnit.hours => every * 60,
        IntervalUnit.days => every * 1440,
      };

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        if (at != null) 'at': at!.toIso8601String(),
        if (times.isNotEmpty) 'times': times.map((t) => t.format()).toList(),
        if (weekdays.isNotEmpty) 'weekdays': (weekdays.toList()..sort()),
        'every': every,
        'unit': unit.name,
        if (windowStart != null) 'ws': windowStart!.format(),
        if (windowEnd != null) 'we': windowEnd!.format(),
        if (anchor != null) 'anchor': anchor!.toIso8601String(),
        'monthDay': monthDay,
        'nth': nth,
        'nthWeekday': nthWeekday,
        'month': month,
        'day': day,
        if (target != null) 'target': target!.toIso8601String(),
        if (offsets.isNotEmpty) 'offsets': offsets,
        'repeatYearly': repeatYearly,
        if (chainFrom != null) 'chainFrom': chainFrom,
        'chainDelayMin': chainDelayMin,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        'radiusM': radiusM,
        'onEnter': onEnter,
        if (placeName != null) 'placeName': placeName,
        if (condition != null) 'condition': condition!.name,
        'threshold': threshold,
        'businessRule': businessRule.name,
      };

  factory Recurrence.fromJson(Map<String, dynamic> j) {
    DateTime? dt(String k) => j[k] == null ? null : DateTime.parse(j[k] as String);
    HM? hm(String k) => j[k] == null ? null : HM.parse(j[k] as String);
    return Recurrence(
      kind: _enum(RecKind.values, j['kind'], RecKind.once),
      at: dt('at'),
      times: ((j['times'] as List?) ?? const []).map((e) => HM.parse(e as String)).toList(),
      weekdays: ((j['weekdays'] as List?) ?? const []).map((e) => e as int).toSet(),
      every: (j['every'] as int?) ?? 1,
      unit: _enum(IntervalUnit.values, j['unit'], IntervalUnit.hours),
      windowStart: hm('ws'),
      windowEnd: hm('we'),
      anchor: dt('anchor'),
      monthDay: (j['monthDay'] as int?) ?? 1,
      nth: (j['nth'] as int?) ?? 1,
      nthWeekday: (j['nthWeekday'] as int?) ?? 1,
      month: (j['month'] as int?) ?? 1,
      day: (j['day'] as int?) ?? 1,
      target: dt('target'),
      offsets: ((j['offsets'] as List?) ?? const []).map((e) => e as int).toList(),
      repeatYearly: (j['repeatYearly'] as bool?) ?? false,
      chainFrom: j['chainFrom'] as String?,
      chainDelayMin: (j['chainDelayMin'] as int?) ?? 0,
      lat: (j['lat'] as num?)?.toDouble(),
      lon: (j['lon'] as num?)?.toDouble(),
      radiusM: (j['radiusM'] as int?) ?? 200,
      onEnter: (j['onEnter'] as bool?) ?? true,
      placeName: j['placeName'] as String?,
      condition: j['condition'] == null ? null : _enum(ConditionType.values, j['condition'], ConditionType.rainToday),
      threshold: (j['threshold'] as num?)?.toDouble() ?? 0,
      businessRule: _enum(BusinessRule.values, j['businessRule'], BusinessRule.ignore),
    );
  }
}

/// Estado do lembrete necessário para calcular ocorrências.
class EngineContext {
  final HolidayCalendar holidays;
  final DateTime createdAt;

  /// Última vez que o lembrete foi marcado como feito.
  final DateTime? lastCompleted;

  /// Ocorrências até este instante (inclusive) já foram concluídas.
  final DateTime? doneUntil;

  /// [RecKind.chain]: quando o lembrete A foi concluído pela última vez.
  final DateTime? chainSourceCompleted;

  const EngineContext({
    this.holidays = const HolidayCalendar(),
    required this.createdAt,
    this.lastCompleted,
    this.doneUntil,
    this.chainSourceCompleted,
  });
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n, d.hour, d.minute);
int _lastDay(int year, int month) => DateTime(year, month + 1, 0).day;

/// Diferença em dias de calendário, imune a horário de verão.
int _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Aplica a regra de dias úteis a uma data nominal. Nulo = pular.
DateTime? applyBusinessRule(DateTime day, BusinessRule rule, HolidayCalendar cal) {
  if (rule == BusinessRule.ignore || cal.isBusinessDay(day)) return day;
  if (rule == BusinessRule.skip) return null;
  final step = rule == BusinessRule.next ? 1 : -1;
  var d = day;
  for (var i = 0; i < 15; i++) {
    d = _addDays(d, step);
    if (cal.isBusinessDay(d)) return d;
  }
  return null;
}

/// Ocorrências em (from, to], em ordem, no máximo [limit].
List<DateTime> occurrencesBetween(Recurrence r, DateTime from, DateTime to, EngineContext ctx, {int limit = 1000}) {
  if (!to.isAfter(from)) return const [];
  final out = <DateTime>[];
  bool accept(DateTime t) =>
      t.isAfter(from) && !t.isAfter(to) && (ctx.doneUntil == null || t.isAfter(ctx.doneUntil!));

  switch (r.kind) {
    case RecKind.location:
    case RecKind.condition:
      return const [];

    case RecKind.once:
      final at = r.at;
      if (at != null && ctx.lastCompleted == null && accept(at)) out.add(at);
      break;

    case RecKind.chain:
      final src = ctx.chainSourceCompleted;
      if (src != null && (ctx.lastCompleted == null || ctx.lastCompleted!.isBefore(src))) {
        final t = src.add(Duration(minutes: r.chainDelayMin));
        if (accept(t)) out.add(t);
      }
      break;

    case RecKind.afterCompletion:
      final base = ctx.lastCompleted ?? r.anchor ?? ctx.createdAt;
      DateTime due;
      if (r.unit == IntervalUnit.days) {
        final t = r.times.isEmpty ? HM(base.hour, base.minute) : r.effectiveTimes.first;
        due = t.on(_addDays(_day(base), r.every));
      } else {
        due = base.add(Duration(minutes: r.unitMinutes));
      }
      // Se atrasar, lembra 1x por dia até concluir.
      var t = due;
      var guard = 0;
      while (!t.isAfter(from) && guard++ < 5000) {
        t = _addDays(t, 1);
      }
      while (!t.isAfter(to) && out.length < limit) {
        if (accept(t)) out.add(t);
        t = _addDays(t, 1);
      }
      break;

    case RecKind.interval:
      if (r.unit != IntervalUnit.days && r.windowStart == null) {
        _continuous(r, from, to, ctx, out, accept, limit);
      } else {
        _dayBased(r, from, to, ctx, out, accept, limit);
      }
      break;

    case RecKind.relativeDate:
      _relative(r, from, to, ctx, out, accept);
      break;

    case RecKind.weekly:
    case RecKind.monthlyDay:
    case RecKind.monthlyNth:
    case RecKind.yearly:
      _dayBased(r, from, to, ctx, out, accept, limit);
      break;
  }
  out.sort();
  final dedup = <DateTime>[];
  for (final t in out) {
    if (dedup.isEmpty || dedup.last != t) dedup.add(t);
  }
  return dedup.length > limit ? dedup.sublist(0, limit) : dedup;
}

bool _weekdayOk(Recurrence r, DateTime d) => r.weekdays.isEmpty || r.weekdays.contains(d.weekday);

void _continuous(Recurrence r, DateTime from, DateTime to, EngineContext ctx, List<DateTime> out,
    bool Function(DateTime) accept, int limit) {
  final anchor = r.anchor ?? ctx.createdAt;
  final step = Duration(minutes: r.unitMinutes < 1 ? 1 : r.unitMinutes);
  var t = anchor;
  if (from.isAfter(anchor)) {
    final k = from.difference(anchor).inMinutes ~/ step.inMinutes;
    t = anchor.add(step * k);
  }
  var guard = 0;
  while (!t.isAfter(to) && out.length < limit && guard++ < 100000) {
    if (_weekdayOk(r, t) &&
        (r.businessRule == BusinessRule.ignore || ctx.holidays.isBusinessDay(t)) &&
        accept(t)) {
      out.add(t);
    }
    t = t.add(step);
  }
}

/// Horários de um dia: janela de intervalo ou lista fixa.
List<HM> _timesFor(Recurrence r) {
  if (r.kind == RecKind.interval && r.unit != IntervalUnit.days && r.windowStart != null) {
    final start = r.windowStart!.minutes;
    final end = (r.windowEnd ?? const HM(23, 59)).minutes;
    final step = r.unitMinutes < 1 ? 1 : r.unitMinutes;
    return [for (var m = start; m <= end; m += step) HM(m ~/ 60, m % 60)];
  }
  return r.effectiveTimes;
}

bool _nominal(Recurrence r, DateTime d, EngineContext ctx) {
  switch (r.kind) {
    case RecKind.weekly:
      return _weekdayOk(r, d);
    case RecKind.monthlyDay:
      final last = _lastDay(d.year, d.month);
      return d.day == (r.monthDay > last ? last : r.monthDay);
    case RecKind.monthlyNth:
      if (d.weekday != r.nthWeekday) return false;
      if (r.nth < 0) return d.day + 7 > _lastDay(d.year, d.month);
      return (d.day - 1) ~/ 7 + 1 == r.nth;
    case RecKind.yearly:
      if (d.month != r.month) return false;
      final last = _lastDay(d.year, d.month);
      return d.day == (r.day > last ? last : r.day);
    case RecKind.interval:
      if (!_weekdayOk(r, d)) return false;
      if (r.unit != IntervalUnit.days) return true;
      final a = _day(r.anchor ?? ctx.createdAt);
      final diff = _daysBetween(a, d);
      return diff >= 0 && diff % (r.every < 1 ? 1 : r.every) == 0;
    default:
      return false;
  }
}

void _dayBased(Recurrence r, DateTime from, DateTime to, EngineContext ctx, List<DateTime> out,
    bool Function(DateTime) accept, int limit) {
  final times = _timesFor(r);
  // Margem para datas movidas por feriado entrarem na janela.
  final start = _addDays(_day(from), -10);
  final end = _addDays(_day(to), 10);
  final span = _daysBetween(start, end);
  // Para intervalos com janela, feriado sempre significa "pular".
  final rule = (r.kind == RecKind.interval && r.businessRule != BusinessRule.ignore) ? BusinessRule.skip : r.businessRule;
  for (var i = 0; i <= span; i++) {
    final d = _addDays(start, i);
    if (!_nominal(r, d, ctx)) continue;
    final actual = applyBusinessRule(d, rule, ctx.holidays);
    if (actual == null) continue;
    for (final t in times) {
      final dt = t.on(actual);
      if (accept(dt)) out.add(dt);
    }
    if (out.length > limit * 2) break;
  }
}

void _relative(Recurrence r, DateTime from, DateTime to, EngineContext ctx, List<DateTime> out,
    bool Function(DateTime) accept) {
  final target = r.target;
  if (target == null) return;
  final years = r.repeatYearly ? [for (var y = from.year - 1; y <= to.year + 1; y++) y] : [target.year];
  final offsets = r.offsets.isEmpty ? const [0] : r.offsets;
  for (final y in years) {
    final last = _lastDay(y, target.month);
    final base = DateTime(y, target.month, target.day > last ? last : target.day);
    for (final off in offsets) {
      final nominal = _addDays(base, off);
      final actual = applyBusinessRule(nominal, r.businessRule, ctx.holidays);
      if (actual == null) continue;
      for (final t in r.effectiveTimes) {
        final dt = t.on(actual);
        if (accept(dt)) out.add(dt);
      }
    }
  }
}

/// Próxima ocorrência estritamente depois de [after].
DateTime? nextOccurrence(Recurrence r, DateTime after, EngineContext ctx, {int horizonDays = 800}) {
  if (!r.isTimeBased) return null;
  const chunk = 45;
  for (var start = 0; start < horizonDays; start += chunk) {
    final from = start == 0 ? after : _addDays(after, start);
    final to = _addDays(after, start + chunk);
    final list = occurrencesBetween(r, from, to, ctx, limit: 1);
    if (list.isNotEmpty) return list.first;
    if (r.kind == RecKind.once || r.kind == RecKind.chain) {
      // Ocorrência única: basta uma busca ampla.
      final all = occurrencesBetween(r, after, _addDays(after, 365 * 50), ctx, limit: 1);
      return all.isEmpty ? null : all.first;
    }
  }
  return null;
}
