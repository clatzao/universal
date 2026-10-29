/// Feriados nacionais do Brasil (fixos e móveis) + feriados locais do usuário.
class Holiday {
  final DateTime date;
  final String name;

  /// Ponto facultativo (Carnaval, Corpus Christi): só conta como feriado
  /// se o usuário ativar.
  final bool optional;

  const Holiday(this.date, this.name, {this.optional = false});
}

class LocalHoliday {
  final int day;
  final int month;

  /// Nulo = repete todo ano.
  final int? year;
  final String name;

  const LocalHoliday({required this.day, required this.month, this.year, required this.name});

  bool matches(DateTime d) => d.day == day && d.month == month && (year == null || year == d.year);

  Map<String, dynamic> toJson() => {'day': day, 'month': month, 'year': year, 'name': name};

  factory LocalHoliday.fromJson(Map<String, dynamic> j) => LocalHoliday(
        day: j['day'] as int,
        month: j['month'] as int,
        year: j['year'] as int?,
        name: (j['name'] as String?) ?? 'Feriado local',
      );
}

DateTime _date(int y, int m, int d) => DateTime(y, m, d);

/// Domingo de Páscoa (algoritmo de Meeus/Jones/Butcher, calendário gregoriano).
DateTime easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return _date(year, month, day);
}

List<Holiday> nationalHolidays(int year) {
  final easter = easterSunday(year);
  DateTime rel(int days) => _date(easter.year, easter.month, easter.day + days);
  final list = <Holiday>[
    Holiday(_date(year, 1, 1), 'Confraternização Universal'),
    Holiday(rel(-48), 'Carnaval', optional: true),
    Holiday(rel(-47), 'Carnaval', optional: true),
    Holiday(rel(-2), 'Sexta-feira Santa'),
    Holiday(_date(year, 4, 21), 'Tiradentes'),
    Holiday(_date(year, 5, 1), 'Dia do Trabalho'),
    Holiday(rel(60), 'Corpus Christi', optional: true),
    Holiday(_date(year, 9, 7), 'Independência do Brasil'),
    Holiday(_date(year, 10, 12), 'Nossa Senhora Aparecida'),
    Holiday(_date(year, 11, 2), 'Finados'),
    Holiday(_date(year, 11, 15), 'Proclamação da República'),
    if (year >= 2024) Holiday(_date(year, 11, 20), 'Dia Nacional de Zumbi e da Consciência Negra'),
    Holiday(_date(year, 12, 25), 'Natal'),
  ];
  list.sort((a, b) => a.date.compareTo(b.date));
  return list;
}

class HolidayCalendar {
  final bool countCarnival;
  final bool countCorpusChristi;
  final List<LocalHoliday> local;

  const HolidayCalendar({this.countCarnival = false, this.countCorpusChristi = false, this.local = const []});

  static final Map<int, List<Holiday>> _cache = {};

  List<Holiday> _national(int year) => _cache.putIfAbsent(year, () => nationalHolidays(year));

  /// Nome do feriado (inclui pontos facultativos mesmo se não contarem).
  String? holidayName(DateTime d) {
    for (final h in _national(d.year)) {
      if (_same(h.date, d)) return h.optional && !_counts(h) ? '${h.name} (ponto facultativo)' : h.name;
    }
    for (final l in local) {
      if (l.matches(d)) return l.name;
    }
    return null;
  }

  bool _counts(Holiday h) {
    if (!h.optional) return true;
    if (h.name == 'Carnaval') return countCarnival;
    if (h.name == 'Corpus Christi') return countCorpusChristi;
    return false;
  }

  bool isHoliday(DateTime d) {
    for (final h in _national(d.year)) {
      if (_same(h.date, d) && _counts(h)) return true;
    }
    return local.any((l) => l.matches(d));
  }

  bool isBusinessDay(DateTime d) => d.weekday <= DateTime.friday && !isHoliday(d);

  static bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
