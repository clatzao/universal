import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../core/net.dart';

const repoOwner = 'clatzao';
const repoName = 'universal';
const downloadLink = 'https://github.com/$repoOwner/$repoName/releases/latest/download/UniversalApp.apk';

class UpdateInfo {
  final int build;
  final String tag;
  final String notes;
  final String apkUrl;

  const UpdateInfo(this.build, this.tag, this.notes, this.apkUrl);
}

/// "v1.0.42" → 42.
int? buildFromTag(String tag) {
  final m = RegExp(r'(\d+)\s*$').firstMatch(tag.trim());
  return m == null ? null : int.parse(m.group(1)!);
}

class Updater {
  static Future<PackageInfo> installed() => PackageInfo.fromPlatform();

  /// Retorna a atualização se houver uma versão mais nova que a instalada.
  static Future<UpdateInfo?> check() async {
    final r = await Net.client.get(
      Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest'),
      headers: {'User-Agent': userAgent, 'Accept': 'application/vnd.github+json'},
    ).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('GitHub respondeu ${r.statusCode}');
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final tag = j['tag_name'] as String? ?? '';
    final remote = buildFromTag(tag);
    final local = int.tryParse((await installed()).buildNumber) ?? 0;
    if (remote == null || remote <= local) return null;
    var url = downloadLink;
    for (final a in (j['assets'] as List? ?? const [])) {
      final m = a as Map<String, dynamic>;
      if ((m['name'] as String?)?.endsWith('.apk') ?? false) url = m['browser_download_url'] as String;
    }
    return UpdateInfo(remote, tag, (j['body'] as String?)?.trim() ?? '', url);
  }

  /// Baixa o APK informando o progresso (0..1, ou nulo se desconhecido).
  static Future<File> download(String url, void Function(double? p) onProgress) async {
    final req = http.Request('GET', Uri.parse(url))..headers['User-Agent'] = userAgent;
    final res = await Net.client.send(req);
    if (res.statusCode != 200) throw Exception('Download falhou (${res.statusCode})');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/UniversalApp.apk');
    final sink = file.openWrite();
    final total = res.contentLength;
    var got = 0;
    await for (final chunk in res.stream) {
      sink.add(chunk);
      got += chunk.length;
      onProgress(total == null || total == 0 ? null : got / total);
    }
    await sink.close();
    return file;
  }

  static Future<String?> install(File f) async {
    final r = await OpenFilex.open(f.path, type: 'application/vnd.android.package-archive');
    return r.type == ResultType.done ? null : r.message;
  }
}
