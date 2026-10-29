import 'package:intl/intl.dart';

import '../reminders/recurrence.dart';

const weekdayShort = ['', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
const weekdayLong = ['', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];

String two(int n) => n.toString().padLeft(2, '0');

String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String dayKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// "hoje 09:00", "amanhã 09:00", "sex 30/10 09:00".
String friendlyWhen(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = DateTime.utc(t.year, t.month, t.day).difference(DateTime.utc(n.year, n.month, n.day)).inDays;
  if (diff == 0) return 'hoje ${hm(t)}';
  if (diff == 1) return 'amanhã ${hm(t)}';
  if (diff == -1) return 'ontem ${hm(t)}';
  if (diff > 1 && diff < 7) return '${weekdayShort[t.weekday]} ${two(t.day)}/${two(t.month)} ${hm(t)}';
  return '${two(t.day)}/${two(t.month)}/${t.year} ${hm(t)}';
}

/// "há 5 min", "há 2 h", "há 3 dias".
String ago(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'agora';
  if (d.inMinutes < 60) return 'há ${d.inMinutes} min';
  if (d.inHours < 24) return 'há ${d.inHours} h';
  if (d.inDays == 1) return 'há 1 dia';
  return 'há ${d.inDays} dias';
}

String longDate(DateTime d) {
  final s = DateFormat("EEEE, d 'de' MMMM 'de' y", 'pt_BR').format(d);
  return s[0].toUpperCase() + s.substring(1);
}

String _times(List<HM> t) => (t.isEmpty ? const [HM(9, 0)] : t).map((e) => e.format()).join(', ');

String _weekdays(Set<int> w) {
  if (w.isEmpty || w.length == 7) return 'todo dia';
  final s = w.toList()..sort();
  if (s.length == 5 && s.every((d) => d <= 5)) return 'seg a sex';
  if (s.length == 2 && s.first == 6 && s.last == 7) return 'fins de semana';
  return s.map((d) => weekdayShort[d]).join(', ');
}

String _unit(IntervalUnit u, int n) => switch (u) {
      IntervalUnit.minutes => n == 1 ? 'minuto' : 'minutos',
      IntervalUnit.hours => n == 1 ? 'hora' : 'horas',
      IntervalUnit.days => n == 1 ? 'dia' : 'dias',
    };

const _conditionLabel = {
  ConditionType.rainToday: 'Chuva hoje ≥',
  ConditionType.rainTomorrow: 'Chuva amanhã ≥',
  ConditionType.tempAbove: 'Temperatura acima de',
  ConditionType.tempBelow: 'Temperatura abaixo de',
  ConditionType.usdAbove: 'Dólar acima de',
  ConditionType.usdBelow: 'Dólar abaixo de',
  ConditionType.eurAbove: 'Euro acima de',
  ConditionType.eurBelow: 'Euro abaixo de',
  ConditionType.btcAbove: 'Bitcoin acima de',
  ConditionType.btcBelow: 'Bitcoin abaixo de',
};

String conditionLabel(ConditionType c) => _conditionLabel[c]!;

String conditionSuffix(ConditionType c) => switch (c) {
      ConditionType.rainToday || ConditionType.rainTomorrow => '%',
      ConditionType.tempAbove || ConditionType.tempBelow => '°C',
      _ => '',
    };

String money(double v) => NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);

String describeRecurrence(Recurrence r) {
  final bd = switch (r.businessRule) {
    BusinessRule.ignore => '',
    BusinessRule.skip => ' (pula feriados)',
    BusinessRule.next => ' (feriado → próximo dia útil)',
    BusinessRule.previous => ' (feriado → dia útil anterior)',
  };
  switch (r.kind) {
    case RecKind.once:
      return r.at == null ? 'Uma vez' : 'Uma vez: ${friendlyWhen(r.at!)}';
    case RecKind.weekly:
      return '${_weekdays(r.weekdays)[0].toUpperCase()}${_weekdays(r.weekdays).substring(1)} às ${_times(r.times)}$bd';
    case RecKind.interval:
      var s = 'A cada ${r.every} ${_unit(r.unit, r.every)}';
      if (r.windowStart != null) s += ' das ${r.windowStart!.format()} às ${(r.windowEnd ?? const HM(23, 59)).format()}';
      if (r.unit == IntervalUnit.days) s += ' às ${_times(r.times)}';
      if (r.weekdays.isNotEmpty && r.weekdays.length < 7) s += ' (${_weekdays(r.weekdays)})';
      return s + bd;
    case RecKind.monthlyDay:
      return '${r.monthDay >= 31 ? 'Último dia' : 'Todo dia ${r.monthDay}'} do mês às ${_times(r.times)}$bd';
    case RecKind.monthlyNth:
      final ord = r.nth < 0 ? 'Última' : '${r.nth}ª';
      return '$ord ${weekdayLong[r.nthWeekday]} do mês às ${_times(r.times)}$bd';
    case RecKind.yearly:
      return 'Todo ano em ${two(r.day)}/${two(r.month)} às ${_times(r.times)}$bd';
    case RecKind.afterCompletion:
      return '${r.every} ${_unit(r.unit, r.every)} depois de concluir';
    case RecKind.relativeDate:
      final t = r.target;
      final parts = r.offsets.map((o) => o == 0 ? 'no dia' : (o < 0 ? '${-o} antes' : '$o depois')).join(', ');
      final date = t == null ? '' : '${two(t.day)}/${two(t.month)}${r.repeatYearly ? ' (todo ano)' : '/${t.year}'}';
      return 'Dias $parts de $date às ${_times(r.times)}$bd';
    case RecKind.chain:
      return '${r.chainDelayMin} min depois de concluir outro lembrete';
    case RecKind.location:
      return '${r.onEnter ? 'Ao chegar' : 'Ao sair'}: ${r.placeName ?? 'local'} (${r.radiusM} m)';
    case RecKind.condition:
      final c = r.condition ?? ConditionType.rainToday;
      final v = c.name.startsWith('rain') || c.name.startsWith('temp')
          ? r.threshold.toStringAsFixed(0)
          : money(r.threshold);
      return '${conditionLabel(c)} $v${conditionSuffix(c)}';
  }
}
