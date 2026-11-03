import 'dart:convert';

import 'finance.dart';

class StatementFormatError implements Exception {}

/// Uma linha do extrato. Valor em centavos: negativo é saída.
class StatementLine {
  final DateTime date;
  final int amount;
  final String description;

  /// Identificador dado pelo banco, quando existe.
  final String? bankId;

  const StatementLine(this.date, this.amount, this.description, {this.bankId});
}

/// Extratos brasileiros costumam vir em Latin-1 quando não são UTF-8.
String decodeStatement(List<int> bytes) {
  String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    text = latin1.decode(bytes);
  }
  return text.startsWith('﻿') ? text.substring(1) : text;
}

/// Aceita OFX e CSV. Lança [StatementFormatError] se não encontrar lançamentos.
List<StatementLine> parseStatement(List<int> bytes) {
  final text = decodeStatement(bytes);
  final lines = RegExp('<STMTTRN>', caseSensitive: false).hasMatch(text) ? _parseOfx(text) : _parseCsv(text);
  if (lines.isEmpty) throw StatementFormatError();
  return lines;
}

// ---------- OFX ----------

List<StatementLine> _parseOfx(String text) {
  final out = <StatementLine>[];
  final blocks = RegExp(r'<STMTTRN>(.*?)(?:</STMTTRN>|(?=<STMTTRN>)|$)', caseSensitive: false, dotAll: true);
  for (final m in blocks.allMatches(text)) {
    final block = m.group(1)!;
    String? field(String tag) {
      final v = RegExp('<$tag>([^<\\r\\n]*)', caseSensitive: false).firstMatch(block)?.group(1)?.trim();
      return v == null || v.isEmpty ? null : v;
    }

    final rawDate = field('DTPOSTED');
    // O ponto é sempre o separador decimal no OFX, mas há bancos que usam vírgula.
    final value = double.tryParse((field('TRNAMT') ?? '').replaceAll(',', '.'));
    if (rawDate == null || rawDate.length < 8 || value == null || value == 0) continue;
    final date = DateTime.tryParse(rawDate.substring(0, 8));
    if (date == null) continue;
    out.add(
      StatementLine(
        date,
        (value * 100).round(),
        _unescape(field('MEMO') ?? field('NAME') ?? ''),
        bankId: field('FITID'),
      ),
    );
  }
  return out;
}

String _unescape(String s) =>
    s.replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll(RegExp(r'\s+'), ' ').trim();

// ---------- CSV ----------

List<String> _splitCsvLine(String line, String delimiter) {
  final out = <String>[];
  final b = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        b.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (ch == delimiter && !quoted) {
      out.add(b.toString().trim());
      b.clear();
    } else {
      b.write(ch);
    }
  }
  out.add(b.toString().trim());
  return out;
}

String _plain(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[áàâã]'), 'a')
    .replaceAll(RegExp('[éê]'), 'e')
    .replaceAll('í', 'i')
    .replaceAll(RegExp('[óôõ]'), 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ç', 'c');

int _column(List<String> header, List<String> names) {
  for (final name in names) {
    final i = header.indexWhere((h) => h == name);
    if (i >= 0) return i;
  }
  for (final name in names) {
    final i = header.indexWhere((h) => h.contains(name));
    if (i >= 0) return i;
  }
  return -1;
}

DateTime? _parseDate(String s) {
  final br = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})').firstMatch(s);
  if (br != null) {
    final year = int.parse(br.group(3)!);
    final month = int.parse(br.group(2)!), day = int.parse(br.group(1)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year < 100 ? 2000 + year : year, month, day);
  }
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  return iso == null ? null : DateTime(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
}

/// "-1.234,56", "R$ 10,00", "(10,00)" e "10,00 D" → centavos com sinal.
int? parseStatementAmount(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  var negative = false;
  final mark = RegExp(r'\s*([DC])$', caseSensitive: false).firstMatch(s);
  if (mark != null) {
    negative = mark.group(1)!.toUpperCase() == 'D';
    s = s.substring(0, mark.start);
  }
  if (s.startsWith('(') && s.endsWith(')')) {
    negative = true;
    s = s.substring(1, s.length - 1);
  }
  if (s.contains('-')) {
    negative = true;
    s = s.replaceAll('-', '');
  }
  s = s.replaceFirst('+', '');
  final cents = parseCents(s);
  if (cents == null) return null;
  return negative ? -cents : cents;
}

const _balanceWords = [
  'saldo do dia',
  'saldo anterior',
  'saldo final',
  'saldo inicial',
  'saldo em conta',
  'saldo total',
];

List<StatementLine> _parseCsv(String text) {
  final rows = const LineSplitter().convert(text).where((l) => l.trim().isNotEmpty).toList();
  // Alguns bancos colocam dados da conta antes do cabeçalho.
  for (var h = 0; h < rows.length && h < 20; h++) {
    for (final delimiter in const [';', ',', '\t']) {
      final header = _splitCsvLine(rows[h], delimiter).map(_plain).toList();
      if (header.length < 2) continue;
      final date = _column(header, const ['data', 'date']);
      final amount = _column(header, const ['valor', 'amount', 'value', 'quantia']);
      final debit = _column(header, const ['debito']);
      final credit = _column(header, const ['credito']);
      if (date < 0 || (amount < 0 && debit < 0 && credit < 0)) continue;
      final description = _column(header, const [
        'descricao',
        'title',
        'titulo',
        'historico',
        'lancamento',
        'estabelecimento',
        'memo',
        'description',
      ]);
      final id = _column(header, const ['identificador', 'id']);
      final out = <StatementLine>[];
      for (final row in rows.skip(h + 1)) {
        final cells = _splitCsvLine(row, delimiter);
        String cell(int i) => i >= 0 && i < cells.length ? cells[i] : '';
        final day = _parseDate(cell(date));
        var cents = amount >= 0 ? parseStatementAmount(cell(amount)) : null;
        if (cents == null) {
          final spent = parseStatementAmount(cell(debit));
          final received = parseStatementAmount(cell(credit));
          if (spent != null && spent != 0) {
            cents = -spent.abs();
          } else if (received != null) {
            cents = received.abs();
          }
        }
        final about = cell(description).replaceAll(RegExp(r'\s+'), ' ').trim();
        if (day == null || cents == null || cents == 0) continue;
        if (_balanceWords.any(_plain(about).contains)) continue;
        final bankId = cell(id);
        out.add(StatementLine(day, cents, about, bankId: bankId.isEmpty ? null : bankId));
      }
      return out;
    }
  }
  return const [];
}
