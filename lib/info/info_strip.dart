import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../settings/settings.dart';
import '../settings/settings_page.dart';
import 'info_store.dart';

final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _brl0 = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);

/// Faixa compacta com clima e cotações.
class InfoStrip extends StatelessWidget {
  const InfoStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final info = context.watch<InfoStore>();
    final s = context.watch<SettingsStore>().value;
    final w = info.weather;
    final q = info.quotes;
    final style = Theme.of(context).textTheme.bodySmall;

    Widget quote(String label, double? v, double? change, {bool noCents = false}) {
      if (v == null) return const SizedBox();
      final up = (change ?? 0) >= 0;
      return Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label ', style: style?.copyWith(fontWeight: FontWeight.bold)),
          Text((noCents ? _brl0 : _brl).format(v), style: style),
          if (change != null)
            Text(' ${up ? '▲' : '▼'}${change.abs().toStringAsFixed(2)}%',
                style: style?.copyWith(color: up ? AppTheme.positive : AppTheme.negative)),
        ]),
      );
    }

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: w == null
                  ? Text(s.hasLocation || s.useGps ? 'Clima…' : 'Defina sua cidade', style: style)
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(w.icon, size: 16),
                      const SizedBox(width: 4),
                      Text('${w.temp.round()}° · chuva ${w.rainToday}%', style: style),
                    ]),
            ),
          ),
          if (q != null) ...[
            quote('USD', q.usd, q.usdChange),
            quote('EUR', q.eur, q.eurChange),
            quote('BTC', q.btc, q.btcChange, noCents: true),
          ] else if (info.loading)
            Text('Carregando cotações…', style: style),
        ]),
      ),
    );
  }
}
