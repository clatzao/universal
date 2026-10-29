import '../core/net.dart';

class Quotes {
  final double? usd;
  final double? eur;
  final double? btc;
  final double? usdChange;
  final double? eurChange;
  final double? btcChange;
  final DateTime fetchedAt;

  const Quotes({this.usd, this.eur, this.btc, this.usdChange, this.eurChange, this.btcChange, required this.fetchedAt});

  Map<String, dynamic> toJson() => {
        'usd': usd,
        'eur': eur,
        'btc': btc,
        'usdChange': usdChange,
        'eurChange': eurChange,
        'btcChange': btcChange,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory Quotes.fromJson(Map<String, dynamic> j) => Quotes(
        usd: (j['usd'] as num?)?.toDouble(),
        eur: (j['eur'] as num?)?.toDouble(),
        btc: (j['btc'] as num?)?.toDouble(),
        usdChange: (j['usdChange'] as num?)?.toDouble(),
        eurChange: (j['eurChange'] as num?)?.toDouble(),
        btcChange: (j['btcChange'] as num?)?.toDouble(),
        fetchedAt: DateTime.parse(j['fetchedAt'] as String),
      );

  /// AwesomeAPI; reserva: open.er-api.com (USD/EUR) e CoinGecko (BTC).
  static Future<Quotes> fetch() async {
    double? usd, eur, btc, usdC, eurC, btcC;
    try {
      final j = await Net.json('https://economia.awesomeapi.com.br/json/last/USD-BRL,EUR-BRL,BTC-BRL') as Map;
      double? v(String k, String f) => double.tryParse('${(j[k] as Map?)?[f]}');
      usd = v('USDBRL', 'bid');
      eur = v('EURBRL', 'bid');
      btc = v('BTCBRL', 'bid');
      usdC = v('USDBRL', 'pctChange');
      eurC = v('EURBRL', 'pctChange');
      btcC = v('BTCBRL', 'pctChange');
    } catch (_) {}
    if (usd == null || eur == null) {
      try {
        final u = await Net.json('https://open.er-api.com/v6/latest/USD') as Map;
        usd ??= ((u['rates'] as Map)['BRL'] as num).toDouble();
        final e = await Net.json('https://open.er-api.com/v6/latest/EUR') as Map;
        eur ??= ((e['rates'] as Map)['BRL'] as num).toDouble();
      } catch (_) {}
    }
    if (btc == null) {
      try {
        final c = await Net.json('https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=brl') as Map;
        btc = ((c['bitcoin'] as Map)['brl'] as num).toDouble();
      } catch (_) {}
    }
    if (usd == null && eur == null && btc == null) throw Exception('Cotações indisponíveis');
    return Quotes(
        usd: usd, eur: eur, btc: btc, usdChange: usdC, eurChange: eurC, btcChange: btcC, fetchedAt: DateTime.now());
  }
}
