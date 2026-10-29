import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persistência em arquivos JSON no aparelho, com escrita atômica
/// (arquivo temporário + rename).
class JsonStore {
  static Directory? _dir;
  static final Map<String, Future<void>> _queue = {};

  /// Permite apontar para outra pasta (testes).
  static set directory(Directory d) => _dir = d;

  static Future<Directory> _base() async {
    if (_dir != null) return _dir!;
    final d = await getApplicationSupportDirectory();
    return _dir = d;
  }

  static Future<File> _file(String name) async => File('${(await _base()).path}${Platform.pathSeparator}$name.json');

  static Future<dynamic> read(String name) async {
    await _queue[name];
    final f = await _file(name);
    if (!await f.exists()) return null;
    try {
      return jsonDecode(await f.readAsString());
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String name, Object? data) {
    final prev = _queue[name] ?? Future.value();
    final next = prev.then((_) async {
      final f = await _file(name);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(data), flush: true);
      await tmp.rename(f.path);
    }).catchError((Object _) {});
    _queue[name] = next;
    return next;
  }
}
