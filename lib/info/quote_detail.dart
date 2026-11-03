import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/format.dart';
import '../core/net.dart';
import '../core/theme.dart';

enum Currency {
  usd('Dólar', 'USD-BRL', 'US\$', 'Dólar americano em reais'),
  eur('Euro', 'EUR-BRL', '€', 'Euro em reais'),
  btc('Bitcoin', 'BTC-BRL', '₿', 'Bitcoin em reais');

  final String label;
  final String pair;
  final String symbol;
  final String description;

  const Currency(this.label, this.pair, this.symbol, this.description);
}

class QuotePoint {
  final DateTime date;
  final double value;
  final double high;
  final double low;

  const QuotePoint(this.date, this.value, this.high, this.low);
}

/// Resposta da AwesomeAPI (mais recente primeiro) em ordem cronológica, um ponto por dia.
List<QuotePoint> parseQuoteHistory(List<dynamic> json) {
  final byDay = <String, QuotePoint>{};
  for (final e in json.reversed) {
    final m = e as Map;
    final ts = int.tryParse('${m['timestamp']}');
    final bid = double.tryParse('${m['bid']}');
    if (ts == null || bid == null) continue;
    final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    byDay[dayKey(d)] = QuotePoint(
      d,
      bid,
      double.tryParse('${m['high']}') ?? bid,
      double.tryParse('${m['low']}') ?? bid,
    );
  }
  return byDay.values.toList();
}

Future<List<QuotePoint>> fetchQuoteHistory(Currency c, int days) async {
  final j = await Net.json('https://economia.awesomeapi.com.br/json/daily/${c.pair}/$days');
  return parseQuoteHistory(j as List);
}

String _money(Currency c, double v) => NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
  decimalDigits: c == Currency.btc ? 0 : (v < 100 ? 4 : 2),
).format(v);

class QuoteDetailPage extends StatefulWidget {
  final Currency currency;

  const QuoteDetailPage({super.key, required this.currency});

  @override
  State<QuoteDetailPage> createState() => _QuoteDetailPageState();
}

class _QuoteDetailPageState extends State<QuoteDetailPage> {
  static const _ranges = [7, 30, 90, 360];
  late Currency currency = widget.currency;
  int days = 30;
  late Future<List<QuotePoint>> history = fetchQuoteHistory(currency, days);
  final amount = TextEditingController(text: '1');

  void _reload() => setState(() => history = fetchQuoteHistory(currency, days));

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cotações')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SegmentedButton<Currency>(
            segments: [for (final c in Currency.values) ButtonSegment(value: c, label: Text(c.label))],
            selected: {currency},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              currency = s.first;
              _reload();
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<QuotePoint>>(
            future: history,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final points = snap.data ?? const <QuotePoint>[];
              if (snap.hasError || points.isEmpty) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_off),
                    title: const Text('Não foi possível carregar o histórico'),
                    trailing: TextButton(onPressed: _reload, child: const Text('Tentar de novo')),
                  ),
                );
              }
              return _Content(
                currency: currency,
                points: points,
                days: days,
                ranges: _ranges,
                amount: amount,
                onRange: (d) {
                  days = d;
                  _reload();
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final Currency currency;
  final List<QuotePoint> points;
  final int days;
  final List<int> ranges;
  final TextEditingController amount;
  final ValueChanged<int> onRange;

  const _Content({
    required this.currency,
    required this.points,
    required this.days,
    required this.ranges,
    required this.amount,
    required this.onRange,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final last = points.last;
    final first = points.first;
    final change = first.value == 0 ? 0.0 : (last.value - first.value) / first.value * 100;
    final up = change >= 0;
    final color = up ? AppTheme.positive : AppTheme.negative;
    final high = points.map((p) => p.high).reduce((a, b) => a > b ? a : b);
    final low = points.map((p) => p.low).reduce((a, b) => a < b ? a : b);
    final minY = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) == 0 ? maxY * 0.01 : (maxY - minY) * 0.1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(currency.description, style: t.labelMedium?.copyWith(color: AppTheme.textMuted)),
        const SizedBox(height: 4),
        Text(
          _money(currency, last.value),
          style: t.displaySmall?.copyWith(fontWeight: FontWeight.w300, letterSpacing: -1),
        ),
        const SizedBox(height: 4),
        Text(
          '${up ? '▲' : '▼'} ${change.abs().toStringAsFixed(2)}% em $days dias',
          style: t.titleSmall?.copyWith(color: color),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            for (final r in ranges)
              ChoiceChip(
                label: Text(r == 360 ? '1 ano' : '$r dias'),
                selected: r == days,
                onSelected: (_) => onRange(r),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minY: minY - pad,
              maxY: maxY + pad,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: (points.length / 3).ceilToDouble().clamp(1, double.infinity),
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= points.length) return const SizedBox();
                      final d = points[i].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${two(d.day)}/${two(d.month)}',
                          style: t.labelSmall?.copyWith(color: AppTheme.textMuted),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppTheme.surfaceHighest,
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        '${_money(currency, s.y)}\n${two(points[s.x.toInt()].date.day)}/${two(points[s.x.toInt()].date.month)}',
                        const TextStyle(color: AppTheme.text, fontSize: 12),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].value)],
                  color: color,
                  barWidth: 2,
                  isCurved: points.length < 60,
                  preventCurveOverShooting: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _Stat('Máxima do período', _money(currency, high)),
            const SizedBox(width: 10),
            _Stat('Mínima do período', _money(currency, low)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _Stat('Máxima do dia', _money(currency, last.high)),
            const SizedBox(width: 10),
            _Stat('Mínima do dia', _money(currency, last.low)),
          ],
        ),
        const SizedBox(height: 20),
        Text('Converter', style: t.titleMedium),
        const SizedBox(height: 10),
        TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: InputDecoration(prefixText: '${currency.symbol} ', labelText: 'Quantidade'),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: amount,
          builder: (_, v, _) {
            final n = double.tryParse(v.text.replaceAll(',', '.')) ?? 0;
            return Text(
              '= ${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(n * last.value)}',
              style: t.titleLarge,
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Atualizado ${friendlyWhen(last.date)}. Fonte: AwesomeAPI.',
          style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.labelSmall?.copyWith(color: AppTheme.textMuted)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: t.titleSmall),
            ),
          ],
        ),
      ),
    );
  }
}
