import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/format.dart';

/// Valores sempre em centavos (int) para não acumular erro de arredondamento.
String brl(int cents) => NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(cents / 100);

/// "85,90" / "1.234,5" / "1234.56" → centavos.
int? parseCents(String s) {
  var t = s.trim().replaceAll(RegExp(r'[R$\s]'), '');
  if (t.isEmpty) return null;
  final lastComma = t.lastIndexOf(','), lastDot = t.lastIndexOf('.');
  if (lastComma > lastDot) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (lastDot > lastComma && lastComma >= 0) {
    t = t.replaceAll(',', '');
  } else if (lastDot >= 0 && t.length - lastDot - 1 == 3 && !t.substring(lastDot + 1).contains('.')) {
    // "1.234" sem vírgula = milhar.
    t = t.replaceAll('.', '');
  }
  final v = double.tryParse(t);
  return v == null ? null : (v * 100).round();
}

enum AccountType {
  carteira('Carteira', Icons.account_balance_wallet_outlined),
  banco('Banco', Icons.account_balance_outlined),
  cartao('Cartão de crédito', Icons.credit_card);

  final String label;
  final IconData icon;

  const AccountType(this.label, this.icon);
}

enum FinCategory {
  mercado('Mercado', Icons.shopping_cart_outlined, Color(0xFF7FB77E)),
  alimentacao('Alimentação', Icons.restaurant_outlined, Color(0xFFE0A458)),
  transporte('Transporte', Icons.directions_car_outlined, Color(0xFF6FA8DC)),
  moradia('Moradia', Icons.home_outlined, Color(0xFFB08968)),
  contas('Contas da casa', Icons.receipt_long_outlined, Color(0xFF8E9AAF)),
  saude('Saúde', Icons.favorite_outline, Color(0xFFE07A7A)),
  lazer('Lazer', Icons.celebration_outlined, Color(0xFFC39BD3)),
  compras('Compras', Icons.shopping_bag_outlined, Color(0xFFE6A1C0)),
  educacao('Educação', Icons.school_outlined, Color(0xFF76C7C0)),
  assinaturas('Assinaturas', Icons.subscriptions_outlined, Color(0xFF9FA8DA)),
  outros('Outros', Icons.more_horiz, Color(0xFF9A9AA2)),
  salario('Salário', Icons.payments_outlined, Color(0xFF7FD1A0), income: true),
  extra('Renda extra', Icons.trending_up, Color(0xFFA5D6A7), income: true),
  outrasEntradas('Outras entradas', Icons.add_card, Color(0xFFB2DFDB), income: true);

  final String label;
  final IconData icon;
  final Color color;
  final bool income;

  const FinCategory(this.label, this.icon, this.color, {this.income = false});

  static List<FinCategory> forKind(TxKind k) => values.where((c) => c.income == (k == TxKind.income)).toList();

  static FinCategory byName(String? n) => values.where((c) => c.name == n).firstOrNull ?? outros;
}

enum TxKind { expense, income, transfer }

class Account {
  String id;
  String name;
  AccountType type;
  int initial;
  int closingDay;
  int dueDay;
  int limit;

  Account({
    required this.id,
    required this.name,
    required this.type,
    this.initial = 0,
    this.closingDay = 1,
    this.dueDay = 10,
    this.limit = 0,
  });

  bool get isCard => type == AccountType.cartao;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'initial': initial,
    'closingDay': closingDay,
    'dueDay': dueDay,
    'limit': limit,
  };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Conta',
    type: AccountType.values.where((e) => e.name == j['type']).firstOrNull ?? AccountType.carteira,
    initial: (j['initial'] as num?)?.toInt() ?? 0,
    closingDay: (j['closingDay'] as num?)?.toInt() ?? 1,
    dueDay: (j['dueDay'] as num?)?.toInt() ?? 10,
    limit: (j['limit'] as num?)?.toInt() ?? 0,
  );
}

class Tx {
  String id;
  TxKind kind;
  int amount;
  DateTime date;
  FinCategory category;
  String accountId;
  String? toAccountId;
  String description;

  /// Parcela atual (1..total) e id do grupo da compra parcelada.
  int installment;
  int installments;
  String? groupId;

  /// Gerado por uma conta fixa.
  String? fixedId;

  Tx({
    required this.id,
    required this.kind,
    required this.amount,
    required this.date,
    required this.category,
    required this.accountId,
    this.toAccountId,
    this.description = '',
    this.installment = 1,
    this.installments = 1,
    this.groupId,
    this.fixedId,
  });

  String get title {
    final base = description.isEmpty ? (kind == TxKind.transfer ? 'Transferência' : category.label) : description;
    return installments > 1 ? '$base ($installment/$installments)' : base;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'amount': amount,
    'date': date.toIso8601String(),
    'category': category.name,
    'accountId': accountId,
    'toAccountId': toAccountId,
    'description': description,
    'installment': installment,
    'installments': installments,
    'groupId': groupId,
    'fixedId': fixedId,
  };

  factory Tx.fromJson(Map<String, dynamic> j) => Tx(
    id: j['id'] as String,
    kind: TxKind.values.where((e) => e.name == j['kind']).firstOrNull ?? TxKind.expense,
    amount: (j['amount'] as num?)?.toInt() ?? 0,
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
    category: FinCategory.byName(j['category'] as String?),
    accountId: j['accountId'] as String? ?? '',
    toAccountId: j['toAccountId'] as String?,
    description: j['description'] as String? ?? '',
    installment: (j['installment'] as num?)?.toInt() ?? 1,
    installments: (j['installments'] as num?)?.toInt() ?? 1,
    groupId: j['groupId'] as String?,
    fixedId: j['fixedId'] as String?,
  );
}

/// Conta fixa: lançada automaticamente todo mês no dia escolhido.
class FixedBill {
  String id;
  String description;
  int amount;
  FinCategory category;
  String accountId;
  int day;
  bool active;

  /// Último mês já lançado ("2026-10").
  String? lastMonth;
  String? reminderId;

  FixedBill({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.accountId,
    required this.day,
    this.active = true,
    this.lastMonth,
    this.reminderId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'amount': amount,
    'category': category.name,
    'accountId': accountId,
    'day': day,
    'active': active,
    'lastMonth': lastMonth,
    'reminderId': reminderId,
  };

  factory FixedBill.fromJson(Map<String, dynamic> j) => FixedBill(
    id: j['id'] as String,
    description: j['description'] as String? ?? '',
    amount: (j['amount'] as num?)?.toInt() ?? 0,
    category: FinCategory.byName(j['category'] as String?),
    accountId: j['accountId'] as String? ?? '',
    day: (j['day'] as num?)?.toInt() ?? 1,
    active: j['active'] as bool? ?? true,
    lastMonth: j['lastMonth'] as String?,
    reminderId: j['reminderId'] as String?,
  );
}

class SavingsGoal {
  String id;
  String name;
  int target;
  int saved;
  DateTime? deadline;

  SavingsGoal({required this.id, required this.name, required this.target, this.saved = 0, this.deadline});

  double get progress => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'target': target,
    'saved': saved,
    'deadline': deadline?.toIso8601String(),
  };

  factory SavingsGoal.fromJson(Map<String, dynamic> j) => SavingsGoal(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Meta',
    target: (j['target'] as num?)?.toInt() ?? 0,
    saved: (j['saved'] as num?)?.toInt() ?? 0,
    deadline: DateTime.tryParse(j['deadline'] as String? ?? ''),
  );
}

// ---------- Datas e cartão ----------

String monthKey(DateTime d) => '${d.year}-${two(d.month)}';

DateTime monthStart(DateTime d) => DateTime(d.year, d.month);

int daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;

/// Soma meses mantendo o dia (31/01 + 1 mês = 28 ou 29/02).
DateTime addMonths(DateTime d, int n) {
  final first = DateTime(d.year, d.month + n);
  final day = d.day.clamp(1, daysInMonth(first.year, first.month));
  return DateTime(first.year, first.month, day, d.hour, d.minute);
}

/// Mês de vencimento da fatura em que uma compra do cartão cai.
/// Compras a partir do dia do fechamento vão para a fatura seguinte.
DateTime invoiceMonth(DateTime purchase, int closingDay, int dueDay) {
  final closeMonth = purchase.day < closingDay
      ? DateTime(purchase.year, purchase.month)
      : DateTime(purchase.year, purchase.month + 1);
  return dueDay > closingDay ? closeMonth : DateTime(closeMonth.year, closeMonth.month + 1);
}

/// Data de vencimento de uma fatura (mês de vencimento).
DateTime invoiceDue(DateTime month, int dueDay) =>
    DateTime(month.year, month.month, dueDay.clamp(1, daysInMonth(month.year, month.month)));

/// Divide um valor em parcelas; os centavos que sobram vão para a 1ª.
List<int> splitInstallments(int total, int n) {
  if (n <= 1) return [total];
  final base = total ~/ n;
  return [total - base * (n - 1), for (var i = 1; i < n; i++) base];
}

// ---------- Texto livre ----------

class ParsedTx {
  final TxKind kind;
  final int amount;
  final String description;
  final FinCategory category;
  final int installments;

  const ParsedTx(this.kind, this.amount, this.description, this.category, this.installments);
}

const _incomeWords = [
  'salario',
  'salário',
  'recebi',
  'recebido',
  'entrada',
  'pagamento recebido',
  'freela',
  'reembolso',
];

const _keywords = <FinCategory, List<String>>{
  FinCategory.mercado: ['mercado', 'supermercado', 'feira', 'atacad', 'hortifruti', 'açougue', 'acougue', 'padaria'],
  FinCategory.alimentacao: [
    'almoço',
    'almoco',
    'jantar',
    'lanche',
    'ifood',
    'restaurante',
    'pizza',
    'café',
    'cafe',
    'hamburguer',
    'delivery',
  ],
  FinCategory.transporte: [
    'uber',
    '99',
    'gasolina',
    'combustível',
    'combustivel',
    'ônibus',
    'onibus',
    'metrô',
    'metro',
    'estacionamento',
    'pedágio',
    'pedagio',
    'posto',
  ],
  FinCategory.moradia: ['aluguel', 'condomínio', 'condominio', 'iptu'],
  FinCategory.contas: ['luz', 'energia', 'água', 'agua', 'internet', 'gás', 'gas', 'telefone', 'celular'],
  FinCategory.saude: [
    'farmácia',
    'farmacia',
    'remédio',
    'remedio',
    'médico',
    'medico',
    'consulta',
    'exame',
    'dentista',
    'academia',
  ],
  FinCategory.lazer: ['cinema', 'show', 'bar', 'viagem', 'passeio', 'jogo', 'ingresso'],
  FinCategory.compras: ['roupa', 'tênis', 'tenis', 'presente', 'loja', 'amazon', 'shopee', 'mercado livre'],
  FinCategory.educacao: ['curso', 'livro', 'escola', 'faculdade', 'mensalidade'],
  FinCategory.assinaturas: ['netflix', 'spotify', 'prime', 'disney', 'youtube', 'assinatura', 'icloud', 'max'],
  FinCategory.salario: ['salario', 'salário'],
  FinCategory.extra: ['freela', 'extra', 'bico', 'venda', 'vendi'],
};

FinCategory guessCategory(String text, TxKind kind) {
  final t = ' ${text.toLowerCase()} ';
  for (final e in _keywords.entries) {
    if (e.key.income != (kind == TxKind.income)) continue;
    for (final w in e.value) {
      if (RegExp('(^|[^a-zà-ú0-9])${RegExp.escape(w)}').hasMatch(t)) return e.key;
    }
  }
  return kind == TxKind.income ? FinCategory.outrasEntradas : FinCategory.outros;
}

/// "mercado 85,90", "uber 23", "tênis 300 em 3x", "+ salário 3500".
ParsedTx? parseTx(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  var kind = TxKind.expense;
  if (s.startsWith('+')) {
    kind = TxKind.income;
    s = s.substring(1).trim();
  }
  var installments = 1;
  final inst = RegExp(r'(?:\bem\s+)?(\d{1,2})\s*x(?![\wÀ-ú])', caseSensitive: false).firstMatch(s);
  if (inst != null) {
    installments = int.parse(inst.group(1)!).clamp(1, 48);
    s = s.replaceRange(inst.start, inst.end, ' ');
  }
  final num = RegExp(
    r'(?:r\$\s*)?(\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?)',
    caseSensitive: false,
  ).allMatches(s).lastOrNull;
  if (num == null) return null;
  final amount = parseCents(num.group(1)!);
  if (amount == null || amount <= 0) return null;
  var desc = s.replaceRange(num.start, num.end, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  desc = desc.replaceAll(RegExp(r'^(de|no|na|em)\s+|\s+(de|no|na|em|reais)$', caseSensitive: false), '').trim();
  final low = desc.toLowerCase();
  if (kind == TxKind.expense && _incomeWords.any((w) => low.contains(w))) kind = TxKind.income;
  if (kind == TxKind.income) installments = 1;
  if (desc.isNotEmpty) desc = desc[0].toUpperCase() + desc.substring(1);
  return ParsedTx(kind, amount, desc, guessCategory(desc, kind), installments);
}
