import 'package:flutter/foundation.dart';

import '../core/format.dart';
import '../core/json_store.dart';
import 'finance.dart';

class BudgetStatus {
  final int limit;
  final int spent;

  const BudgetStatus(this.limit, this.spent);

  double get ratio => limit <= 0 ? 0 : spent / limit;
}

class FinanceStore extends ChangeNotifier {
  List<Account> accounts = [];
  List<Tx> txs = [];
  List<FixedBill> fixed = [];
  List<SavingsGoal> goals = [];
  Map<FinCategory, int> budgets = {};
  String? defaultAccountId;
  bool loaded = false;

  static int _seq = 0;
  static String newId() => '${DateTime.now().microsecondsSinceEpoch}${_seq++}';

  Future<void> load({DateTime? now}) async {
    final j = await JsonStore.read('finance');
    if (j is Map) {
      try {
        accounts = [for (final e in (j['accounts'] as List? ?? [])) Account.fromJson((e as Map).cast())];
        txs = [for (final e in (j['txs'] as List? ?? [])) Tx.fromJson((e as Map).cast())];
        fixed = [for (final e in (j['fixed'] as List? ?? [])) FixedBill.fromJson((e as Map).cast())];
        goals = [for (final e in (j['goals'] as List? ?? [])) SavingsGoal.fromJson((e as Map).cast())];
        budgets = {
          for (final e in ((j['budgets'] as Map?) ?? {}).entries)
            FinCategory.byName(e.key as String): (e.value as num).toInt(),
        };
        defaultAccountId = j['defaultAccountId'] as String?;
      } catch (_) {}
    }
    if (accounts.isEmpty) {
      accounts.add(Account(id: newId(), name: 'Carteira', type: AccountType.carteira));
    }
    loaded = true;
    if (generateFixed(now ?? DateTime.now()) > 0) {
      await _save();
    } else {
      notifyListeners();
    }
  }

  Future<void> _save() async {
    txs.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    await JsonStore.write('finance', {
      'accounts': [for (final a in accounts) a.toJson()],
      'txs': [for (final t in txs) t.toJson()],
      'fixed': [for (final f in fixed) f.toJson()],
      'goals': [for (final g in goals) g.toJson()],
      'budgets': {for (final e in budgets.entries) e.key.name: e.value},
      'defaultAccountId': defaultAccountId,
    });
  }

  Account? account(String? id) => accounts.where((a) => a.id == id).firstOrNull;

  Account get defaultAccount =>
      account(defaultAccountId) ?? accounts.firstWhere((a) => !a.isCard, orElse: () => accounts.first);

  Account? get firstCard => accounts.where((a) => a.isCard).firstOrNull;

  // ---------- Saldos ----------

  int _effect(Tx t, String accountId) {
    if (t.kind == TxKind.transfer) {
      if (t.accountId == accountId) return -t.amount;
      if (t.toAccountId == accountId) return t.amount;
      return 0;
    }
    if (t.accountId != accountId) return 0;
    return t.kind == TxKind.income ? t.amount : -t.amount;
  }

  /// Saldo até hoje (lançamentos futuros, como parcelas, ficam de fora).
  int balance(Account a, {DateTime? now}) {
    final end = dayOf(now ?? DateTime.now()).add(const Duration(days: 1));
    var v = a.initial;
    for (final t in txs) {
      if (t.date.isBefore(end)) v += _effect(t, a.id);
    }
    return v;
  }

  /// Dívida total do cartão, incluindo parcelas futuras (limite comprometido).
  int cardDebt(Account a) {
    var v = -a.initial;
    for (final t in txs) {
      v -= _effect(t, a.id);
    }
    return v;
  }

  int totalBalance({DateTime? now}) => accounts.where((a) => !a.isCard).fold(0, (s, a) => s + balance(a, now: now));

  // ---------- Mês ----------

  bool _inMonth(DateTime d, DateTime m) => d.year == m.year && d.month == m.month;

  List<Tx> monthTxs(DateTime m) => txs.where((t) => _inMonth(t.date, m)).toList();

  int expenses(DateTime m) =>
      txs.where((t) => t.kind == TxKind.expense && _inMonth(t.date, m)).fold(0, (s, t) => s + t.amount);

  int incomes(DateTime m) =>
      txs.where((t) => t.kind == TxKind.income && _inMonth(t.date, m)).fold(0, (s, t) => s + t.amount);

  Map<FinCategory, int> byCategory(DateTime m) {
    final out = <FinCategory, int>{};
    for (final t in txs) {
      if (t.kind == TxKind.expense && _inMonth(t.date, m)) out[t.category] = (out[t.category] ?? 0) + t.amount;
    }
    return Map.fromEntries(out.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  BudgetStatus? budget(FinCategory c, DateTime m) {
    final limit = budgets[c];
    if (limit == null || limit <= 0) return null;
    return BudgetStatus(limit, byCategory(m)[c] ?? 0);
  }

  // ---------- Cartão ----------

  List<Tx> invoiceTxs(Account card, DateTime month) => txs
      .where(
        (t) =>
            t.accountId == card.id &&
            t.kind != TxKind.transfer &&
            _inMonth(invoiceMonth(t.date, card.closingDay, card.dueDay), month),
      )
      .toList();

  int invoiceTotal(Account card, DateTime month) =>
      invoiceTxs(card, month).fold(0, (s, t) => s + (t.kind == TxKind.income ? -t.amount : t.amount));

  static String invoiceGroup(DateTime month) => 'fatura:${monthKey(month)}';

  int invoicePaid(Account card, DateTime month) => txs
      .where((t) => t.kind == TxKind.transfer && t.toAccountId == card.id && t.groupId == invoiceGroup(month))
      .fold(0, (s, t) => s + t.amount);

  /// Fatura em aberto mais próxima (a que vence a seguir).
  DateTime currentInvoice(Account card, {DateTime? now}) =>
      invoiceMonth(now ?? DateTime.now(), card.closingDay, card.dueDay);

  Future<void> payInvoice(Account card, DateTime month, Account from, int amount, {DateTime? date}) async {
    txs.add(
      Tx(
        id: newId(),
        kind: TxKind.transfer,
        amount: amount,
        date: date ?? DateTime.now(),
        category: FinCategory.outros,
        accountId: from.id,
        toAccountId: card.id,
        description: 'Pagamento fatura ${card.name}',
        groupId: invoiceGroup(month),
      ),
    );
    await _save();
  }

  // ---------- Lançamentos ----------

  /// Cria o lançamento; no cartão, parcelas viram um lançamento por mês.
  Future<List<Tx>> addTx({
    required TxKind kind,
    required int amount,
    required DateTime date,
    required FinCategory category,
    required String accountId,
    String? toAccountId,
    String description = '',
    int installments = 1,
  }) async {
    final n = kind == TxKind.expense ? installments.clamp(1, 48) : 1;
    final parts = splitInstallments(amount, n);
    final group = n > 1 ? newId() : null;
    final created = [
      for (var i = 0; i < n; i++)
        Tx(
          id: newId(),
          kind: kind,
          amount: parts[i],
          date: addMonths(date, i),
          category: category,
          accountId: accountId,
          toAccountId: kind == TxKind.transfer ? toAccountId : null,
          description: description,
          installment: i + 1,
          installments: n,
          groupId: group,
        ),
    ];
    txs.addAll(created);
    await _save();
    return created;
  }

  Future<void> updateTx(Tx t) async {
    final i = txs.indexWhere((e) => e.id == t.id);
    if (i >= 0) txs[i] = t;
    await _save();
  }

  Future<void> removeTx(Tx t, {bool wholeGroup = false}) async {
    if (wholeGroup && t.groupId != null) {
      txs.removeWhere((e) => e.groupId == t.groupId);
    } else {
      txs.removeWhere((e) => e.id == t.id);
    }
    await _save();
  }

  Future<void> restore(List<Tx> list) async {
    txs.addAll(list);
    await _save();
  }

  // ---------- Contas ----------

  Future<void> saveAccount(Account a) async {
    final i = accounts.indexWhere((e) => e.id == a.id);
    if (i < 0) {
      accounts.add(a);
    } else {
      accounts[i] = a;
    }
    await _save();
  }

  /// Só remove contas sem lançamentos.
  bool canRemoveAccount(Account a) =>
      accounts.length > 1 && !txs.any((t) => t.accountId == a.id || t.toAccountId == a.id);

  Future<void> removeAccount(Account a) async {
    if (!canRemoveAccount(a)) return;
    accounts.removeWhere((e) => e.id == a.id);
    fixed.removeWhere((f) => f.accountId == a.id);
    if (defaultAccountId == a.id) defaultAccountId = null;
    await _save();
  }

  Future<void> setDefaultAccount(Account a) async {
    defaultAccountId = a.id;
    await _save();
  }

  // ---------- Contas fixas ----------

  /// Lança as contas fixas dos meses que já chegaram ao dia. Retorna quantas criou.
  int generateFixed(DateTime now) {
    var count = 0;
    for (final f in fixed) {
      if (!f.active) continue;
      var m = f.lastMonth == null
          ? DateTime(now.year, now.month)
          : DateTime(int.parse(f.lastMonth!.split('-')[0]), int.parse(f.lastMonth!.split('-')[1]) + 1);
      while (!m.isAfter(DateTime(now.year, now.month))) {
        final date = DateTime(m.year, m.month, f.day.clamp(1, daysInMonth(m.year, m.month)), 9);
        if (date.isAfter(now)) break;
        txs.add(
          Tx(
            id: newId(),
            kind: TxKind.expense,
            amount: f.amount,
            date: date,
            category: f.category,
            accountId: f.accountId,
            description: f.description,
            fixedId: f.id,
          ),
        );
        f.lastMonth = monthKey(m);
        count++;
        m = DateTime(m.year, m.month + 1);
      }
    }
    return count;
  }

  /// Nova conta fixa começa a valer no próximo vencimento (não lança o mês se o dia já passou).
  Future<void> saveFixed(FixedBill f, {DateTime? now}) async {
    final n = now ?? DateTime.now();
    final i = fixed.indexWhere((e) => e.id == f.id);
    if (i < 0) {
      f.lastMonth ??= n.day >= f.day ? monthKey(n) : monthKey(DateTime(n.year, n.month - 1));
      fixed.add(f);
    } else {
      fixed[i] = f;
    }
    generateFixed(n);
    await _save();
  }

  Future<void> removeFixed(FixedBill f) async {
    fixed.removeWhere((e) => e.id == f.id);
    await _save();
  }

  int fixedMonthly() => fixed.where((f) => f.active).fold(0, (s, f) => s + f.amount);

  // ---------- Orçamentos e metas ----------

  Future<void> setBudget(FinCategory c, int cents) async {
    if (cents <= 0) {
      budgets.remove(c);
    } else {
      budgets[c] = cents;
    }
    await _save();
  }

  Future<void> saveGoal(SavingsGoal g) async {
    final i = goals.indexWhere((e) => e.id == g.id);
    if (i < 0) {
      goals.add(g);
    } else {
      goals[i] = g;
    }
    await _save();
  }

  Future<void> removeGoal(SavingsGoal g) async {
    goals.removeWhere((e) => e.id == g.id);
    await _save();
  }

  Future<void> deposit(SavingsGoal g, int cents) async {
    g.saved = (g.saved + cents).clamp(0, 1 << 52);
    await _save();
  }

  // ---------- Exportar ----------

  /// CSV com ";" e vírgula decimal (abre direto no Excel/Sheets em pt-BR).
  String toCsv() {
    String esc(String s) => '"${s.replaceAll('"', '""')}"';
    final b = StringBuffer('Data;Tipo;Descrição;Categoria;Conta;Destino;Parcela;Valor\n');
    for (final t in [...txs]..sort((a, b) => a.date.compareTo(b.date))) {
      final kind = switch (t.kind) {
        TxKind.expense => 'Gasto',
        TxKind.income => 'Entrada',
        TxKind.transfer => 'Transferência',
      };
      final signed = t.kind == TxKind.expense ? -t.amount : t.amount;
      b.writeln(
        [
          '${two(t.date.day)}/${two(t.date.month)}/${t.date.year}',
          kind,
          esc(t.description),
          t.kind == TxKind.transfer ? '' : t.category.label,
          esc(account(t.accountId)?.name ?? ''),
          esc(account(t.toAccountId)?.name ?? ''),
          t.installments > 1 ? '${t.installment}/${t.installments}' : '',
          (signed / 100).toStringAsFixed(2).replaceAll('.', ','),
        ].join(';'),
      );
    }
    return b.toString();
  }
}
