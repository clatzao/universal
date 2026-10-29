import 'dart:convert';

import 'package:http/http.dart' as http;

const userAgent = 'UniversalApp/1.0 (+https://github.com/clatzao/universal)';

class Net {
  static final client = http.Client();

  static Future<http.Response> get(String url, {Duration timeout = const Duration(seconds: 20)}) =>
      client.get(Uri.parse(url), headers: {'User-Agent': userAgent, 'Accept': '*/*'}).timeout(timeout);

  static Future<dynamic> json(String url) async {
    final r = await get(url);
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return jsonDecode(utf8.decode(r.bodyBytes));
  }
}
