import '../core/text_norm.dart';
import 'recurrence.dart';

class ParsedReminder {
  final String title;
  final Recurrence recurrence;

  const ParsedReminder(this.title, this.recurrence);
}

const _wdNames = {
  'segunda': 1,
  'terca': 2,
  'quarta': 3,
  'quinta': 4,
  'sexta': 5,
  'sabado': 6,
  'domingo': 7,
};

const _monthNames = {
  'janeiro': 1,
  'fevereiro': 2,
  'marco': 3,
  'abril': 4,
  'maio': 5,
  'junho': 6,
  'julho': 7,
  'agosto': 8,
  'setembro': 9,
  'outubro': 10,
  'novembro': 11,
  'dezembro': 12,
};

const _wd = r'(segunda|terca|quarta|quinta|sexta|sabado|domingo)';
const _t = r'\d{1,2}(?:(?::|h)\d{2}|h)?';

/// Palavras de ligação removidas das pontas do título.
const _connectors = {
  'as', 'a', 'ao', 'de', 'do', 'da', 'dos', 'das', 'em', 'no', 'na', 'nos', 'nas', 'e', 'todo', 'toda',
  'todos', 'todas', 'para', 'pra', 'pro', 'ate', 'pelas', 'o', 'os', 'cada', 'que', 'me', 'lembrar', 'lembre',
  'lembra', 'lembrete', 'de:', '-', ',', ':', '.',
};

class _Scanner {
  final String original;
  final String norm;
  final List<bool> used;

  _Scanner(this.original)
      : norm = normalizeKeepLength(original),
        used = List.filled(original.length, false);

  bool _free(RegExpMatch m) {
    for (var i = m.start; i < m.end; i++) {
      if (used[i]) return false;
    }
    return true;
  }

  void _mark(RegExpMatch m) {
    for (var i = m.start; i < m.end; i++) {
      used[i] = true;
    }
  }

  RegExpMatch? take(RegExp re) {
    for (final m in re.allMatches(norm)) {
      if (m.end > m.start && _free(m)) {
        _mark(m);
        return m;
      }
    }
    return null;
  }

  List<RegExpMatch> takeAll(RegExp re) {
    final out = <RegExpMatch>[];
    for (final m in re.allMatches(norm)) {
      if (m.end > m.start && _free(m)) {
        _mark(m);
        out.add(m);
      }
    }
    return out;
  }

  String title() {
    final b = StringBuffer();
    for (var i = 0; i < original.length; i++) {
      b.write(used[i] ? ' ' : original[i]);
    }
    final words = b.toString().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    bool isConn(String w) => _connectors.contains(normalizeKeepLength(w));
    while (words.isNotEmpty && isConn(words.first)) {
      words.removeAt(0);
    }
    while (words.isNotEmpty && isConn(words.last)) {
      words.removeLast();
    }
    var s = words.join(' ').replaceAll(RegExp(r'^[,.;:\-\s]+|[,.;:\-\s]+$'), '');
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }
}

RegExp _re(String p) => RegExp(p);

/// Converte "9h", "9h30", "7:30", "15" em [HM]; aplica período ("da noite").
HM? _parseTime(String raw, [String? period]) {
  final m = RegExp(r'^(\d{1,2})(?:(?::|h)(\d{2})?)?$').firstMatch(raw.trim());
  if (m == null) return null;
  var h = int.parse(m.group(1)!);
  final min = m.group(2) == null ? 0 : int.parse(m.group(2)!);
  if (period != null) {
    if ((period == 'tarde' || period == 'noite') && h < 12) h += 12;
    if (period == 'madrugada' && h == 12) h = 0;
    if (period == 'manha' && h == 12) h = 0;
  }
  if (h > 23 || min > 59) return null;
  return HM(h, min);
}

int _ordinal(String s) {
  if (s.startsWith('ultim')) return -1;
  if (s.startsWith('primeir') || s.startsWith('1')) return 1;
  if (s.startsWith('segund') || s.startsWith('2')) return 2;
  if (s.startsWith('terceir') || s.startsWith('3')) return 3;
  if (s.startsWith('quart') || s.startsWith('4')) return 4;
  if (s.startsWith('quint') || s.startsWith('5')) return 5;
  return 1;
}

IntervalUnit _unit(String u) {
  if (u.startsWith('min')) return IntervalUnit.minutes;
  if (u.startsWith('h')) return IntervalUnit.hours;
  return IntervalUnit.days;
}

DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

/// Interpreta texto livre em português. Retorna nulo se não houver nenhuma
/// informação de data/hora/repetição.
ParsedReminder? parseReminder(String input, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final today = _d(clock);
  final s = _Scanner(input);

  // 1. "em 20 minutos", "daqui a 2 horas"
  final rel = s.take(_re(r'\b(?:em|daqui(?:\s+a)?|dentro\s+de)\s+(\d+)\s*(min|minutos?|h|horas?|dias?)\b'));
  if (rel != null) {
    final n = int.parse(rel.group(1)!);
    final u = _unit(rel.group(2)!);
    final at = switch (u) {
      IntervalUnit.minutes => clock.add(Duration(minutes: n)),
      IntervalUnit.hours => clock.add(Duration(hours: n)),
      IntervalUnit.days => DateTime(clock.year, clock.month, clock.day + n, clock.hour, clock.minute),
    };
    final title = s.title();
    return ParsedReminder(title, Recurrence(kind: RecKind.once, at: DateTime(at.year, at.month, at.day, at.hour, at.minute)));
  }

  // 2. Intervalo "a cada 1h" + janela "das 8h às 18h"
  final every = s.take(_re(r'\b(?:a\s+)?cada\s+(\d+)?\s*(min|minutos?|h|horas?|dias?|semanas?)\b'));
  final window = s.take(_re('\\b(?:das|de|entre)\\s+($_t)\\s*(?:as|a|ate|e)\\s+($_t)\\b'));
  final afterDone =
      s.take(_re(r'\b(?:depois|apos)\s+(?:de\s+|da\s+|do\s+)?(?:concluir|conclusao|concluido|concluida|feito|feita|fazer|terminar)\b'));

  // 3. "5 e 1 dias antes de 10/11"
  final relDate = s.take(_re(
      r'\b(\d+(?:\s*(?:,|e)\s*\d+)*)\s+dias?\s+(antes|depois)\s+(?:d[eoa]s?\s+)?(?:dia\s+)?(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?'));

  // 4. "última sexta do mês", "2ª terça do mês"
  final nth = s.take(_re(
      '\\b(?:n[ao]s?\\s+)?(?:tod[ao]s?\\s+(?:a\\s+|o\\s+)?)?(primeir[ao]|segund[ao]|terceir[ao]|quart[ao]|quint[ao]|ultim[ao]|[1-5][ao]?)\\s+$_wd(?:-feira)?\\s+(?:do|de\\s+cada|de\\s+todo)\\s+mes\\b'));

  // 5. "todo dia 5", "dia 5 de cada mês", "último dia do mês"
  RegExpMatch? monthDay = s.take(_re(r'\b(?:tod[oa]s?\s+(?:o\s+)?)?(?:ultimo)\s+dia\s+(?:do|de\s+cada|de\s+todo)\s+mes\b'));
  var monthDayValue = monthDay != null ? 31 : 0;
  if (monthDay == null) {
    monthDay = s.take(_re(r'\b(?:todo\s+mes\s+(?:no\s+)?dia|todo\s+dia|dia)\s+(\d{1,2})(?!\s*/|\d|h|:)(?:\s+(?:de\s+)?(?:cada|todo)\s+mes)?\b'));
    if (monthDay != null) {
      final raw = monthDay.group(0)!;
      final isMonthly = raw.startsWith('todo') || raw.contains('mes');
      final v = int.parse(monthDay.group(1)!);
      if (isMonthly && v >= 1 && v <= 31) {
        monthDayValue = v;
      } else {
        // "dia 15" sozinho: próxima data com esse dia (uma vez).
        monthDayValue = -v;
      }
    }
  }

  // 6. Anual
  final yearly = s.take(_re(r'\b(?:todo\s+ano|todos\s+os\s+anos|anualmente|cada\s+ano)\b'));

  // 7. Dias úteis / fim de semana / diário
  final business = s.take(_re(r'\b(?:(?:em|nos|de)\s+)?(?:tod[oa]s?\s+(?:os\s+)?)?dias?\s+uteis\b'));
  final weekend = s.take(_re(r'\b(?:(?:n[oa]s?|em|tod[oa]s?\s+(?:os\s+)?)\s+)?(?:fins?|finais?|fim)\s+de\s+semana\b'));
  final daily = s.take(_re(r'\b(?:todos\s+os\s+dias|todo\s+dia|diariamente|cada\s+dia)\b'));

  // 8. Dias da semana
  final wdList = s.take(_re(
      '\\b(?:(?:n[ao]s?|em|tod[ao]s?(?:\\s+(?:as|os))?|as|aos)\\s+)?$_wd(s?)(?:-feiras?)?(?:\\s*(?:,|e)\\s*$_wd(?:s?)(?:-feiras?)?)*\\b'));
  final weekdays = <int>{};
  var weekdayRecurring = false;
  if (wdList != null) {
    final txt = wdList.group(0)!;
    for (final m in RegExp(_wd).allMatches(txt)) {
      weekdays.add(_wdNames[m.group(1)]!);
    }
    weekdayRecurring = txt.startsWith('tod') ||
        RegExp('${_wd}s\\b').hasMatch(txt) ||
        RegExp('$_wd-feiras').hasMatch(txt) ||
        weekdays.length > 1;
  }

  // 9. Datas
  DateTime? date;
  if (s.take(_re(r'\bdepois\s+de\s+amanha\b')) != null) {
    date = today.add(const Duration(days: 2));
  } else if (s.take(_re(r'\bamanha\b')) != null) {
    date = DateTime(today.year, today.month, today.day + 1);
  } else if (s.take(_re(r'\bhoje\b')) != null) {
    date = today;
  }
  int? dm, dd, dy;
  final numDate = s.take(_re(r'\b(?:(?:em|no|dia|no\s+dia|de)\s+)?(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b'));
  if (numDate != null) {
    dd = int.parse(numDate.group(1)!);
    dm = int.parse(numDate.group(2)!);
    if (numDate.group(3) != null) {
      dy = int.parse(numDate.group(3)!);
      if (dy < 100) dy += 2000;
    }
  } else {
    final named = s.take(_re(
        r'\b(?:(?:em|no|dia|no\s+dia)\s+)?(\d{1,2})\s+de\s+(janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro)(?:\s+de\s+(\d{4}))?\b'));
    if (named != null) {
      dd = int.parse(named.group(1)!);
      dm = _monthNames[named.group(2)!];
      if (named.group(3) != null) dy = int.parse(named.group(3)!);
    }
  }

  // 10. Horários
  final times = <HM>[];
  for (final m in s.takeAll(_re(r'\b(?:(?:as|a|ao|pelas|pelo)\s+)?(meio[- ]dia|meia[- ]noite)\b'))) {
    times.add(m.group(1)!.startsWith('meio') ? const HM(12, 0) : const HM(0, 0));
  }
  final timeRe = _re(
      r'\b(?:(?:as|a|pelas|ao)\s+)?(\d{1,2}(?::\d{2}|h(?:\d{2})?))(?:\s*horas?)?(?:\s+(?:da|de)\s+(manha|tarde|noite|madrugada))?\b');
  for (final m in s.takeAll(timeRe)) {
    final t = _parseTime(m.group(1)!, m.group(2));
    if (t != null) times.add(t);
  }
  final bareRe = _re(r'\b(?:as|pelas)\s+(\d{1,2})(?:\s*horas?)?(?:\s+(?:da|de)\s+(manha|tarde|noite|madrugada))?\b');
  for (final m in s.takeAll(bareRe)) {
    final t = _parseTime(m.group(1)!, m.group(2));
    if (t != null) times.add(t);
  }
  final periodRe = _re(r'\b(\d{1,2})(?:\s*horas?)?\s+(?:da|de)\s+(manha|tarde|noite|madrugada)\b');
  for (final m in s.takeAll(periodRe)) {
    final t = _parseTime(m.group(1)!, m.group(2));
    if (t != null) times.add(t);
  }
  final hoursRe = _re(r'\b(\d{1,2})\s+horas\b');
  for (final m in s.takeAll(hoursRe)) {
    final t = _parseTime(m.group(1)!);
    if (t != null) times.add(t);
  }
  times.sort();
  final uniqueTimes = <HM>[];
  for (final t in times) {
    if (uniqueTimes.isEmpty || uniqueTimes.last != t) uniqueTimes.add(t);
  }

  final title = s.title();
  Recurrence? rec;

  if (every != null) {
    final n = every.group(1) == null ? 1 : int.parse(every.group(1)!);
    final rawUnit = every.group(2)!;
    var unit = _unit(rawUnit);
    var amount = n;
    if (rawUnit.startsWith('semana')) {
      unit = IntervalUnit.days;
      amount = n * 7;
    }
    if (afterDone != null) {
      rec = Recurrence(
        kind: RecKind.afterCompletion,
        every: amount,
        unit: unit,
        times: unit == IntervalUnit.days ? uniqueTimes.take(1).toList() : const [],
        anchor: clock,
      );
    } else {
      HM? ws, we;
      if (window != null) {
        ws = _parseTime(window.group(1)!);
        we = _parseTime(window.group(2)!);
      }
      final wds = <int>{
        ...weekdays,
        if (business != null) ...{1, 2, 3, 4, 5},
        if (weekend != null) ...{6, 7},
      };
      rec = Recurrence(
        kind: RecKind.interval,
        every: amount,
        unit: unit,
        windowStart: ws,
        windowEnd: we,
        weekdays: wds,
        times: unit == IntervalUnit.days ? uniqueTimes : const [],
        anchor: unit == IntervalUnit.days ? today : clock,
        businessRule: business != null ? BusinessRule.skip : BusinessRule.ignore,
      );
    }
  } else if (relDate != null) {
    final nums = RegExp(r'\d+').allMatches(relDate.group(1)!).map((m) => int.parse(m.group(0)!)).toList();
    final sign = relDate.group(2) == 'antes' ? -1 : 1;
    final day = int.parse(relDate.group(3)!);
    final month = int.parse(relDate.group(4)!);
    var year = relDate.group(5) == null ? today.year : int.parse(relDate.group(5)!);
    if (year < 100) year += 2000;
    var target = DateTime(year, month, day);
    if (relDate.group(5) == null && target.isBefore(today)) target = DateTime(year + 1, month, day);
    final offsets = nums.map((n) => n * sign).toSet().toList()..sort();
    rec = Recurrence(
      kind: RecKind.relativeDate,
      target: target,
      offsets: offsets,
      repeatYearly: yearly != null,
      times: uniqueTimes,
    );
  } else if (nth != null) {
    rec = Recurrence(
      kind: RecKind.monthlyNth,
      nth: _ordinal(nth.group(1)!),
      nthWeekday: _wdNames[nth.group(2)!]!,
      times: uniqueTimes,
    );
  } else if (monthDayValue > 0) {
    rec = Recurrence(kind: RecKind.monthlyDay, monthDay: monthDayValue, times: uniqueTimes);
  } else if (yearly != null && dd != null && dm != null) {
    rec = Recurrence(kind: RecKind.yearly, day: dd, month: dm, times: uniqueTimes);
  } else if (business != null) {
    rec = Recurrence(
      kind: RecKind.weekly,
      weekdays: {...weekdays, 1, 2, 3, 4, 5},
      times: uniqueTimes,
      businessRule: BusinessRule.skip,
    );
  } else if (weekend != null) {
    rec = Recurrence(kind: RecKind.weekly, weekdays: {...weekdays, 6, 7}, times: uniqueTimes);
  } else if (daily != null) {
    rec = Recurrence(kind: RecKind.weekly, weekdays: const {}, times: uniqueTimes);
  } else if (weekdays.isNotEmpty && weekdayRecurring) {
    rec = Recurrence(kind: RecKind.weekly, weekdays: weekdays, times: uniqueTimes);
  } else {
    // Uma vez.
    final t = uniqueTimes.isEmpty ? null : uniqueTimes.first;
    DateTime? day = date;
    if (day == null && dd != null && dm != null) {
      day = DateTime(dy ?? today.year, dm, dd);
      if (dy == null && day.isBefore(today)) day = DateTime(today.year + 1, dm, dd);
    }
    if (day == null && monthDayValue < 0) {
      final v = -monthDayValue;
      var cand = DateTime(today.year, today.month, v);
      if (cand.month != today.month || cand.isBefore(today)) cand = DateTime(today.year, today.month + 1, v);
      day = cand;
    }
    if (day == null && weekdays.isNotEmpty) {
      final wd = weekdays.first;
      var delta = (wd - today.weekday) % 7;
      final candidate = (t ?? const HM(9, 0)).on(DateTime(today.year, today.month, today.day + delta));
      if (!candidate.isAfter(clock)) delta += 7;
      day = DateTime(today.year, today.month, today.day + delta);
    }
    if (day == null && t != null) {
      day = t.on(today).isAfter(clock) ? today : DateTime(today.year, today.month, today.day + 1);
    }
    if (day == null) return null;
    final at = (t ?? const HM(9, 0)).on(day);
    rec = Recurrence(kind: RecKind.once, at: at);
  }

  return ParsedReminder(title, rec);
}
