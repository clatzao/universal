import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/json_store.dart';
import '../tools/vault.dart';

/// Dados que vão para o backup. Caches de notícias, clima e "Neste dia" ficam de fora:
/// voltam sozinhos da internet.
const backupStores = [
  'settings',
  'reminders',
  'habits',
  'notes',
  'finance',
  'games',
  'news_saved',
  'news_read',
  'news_alerts',
];

const backupMagic = 'universal-backup';
const backupVersion = 1;
const backupMinPassword = 8;

const _iterations = 600000;
const _minIterations = 100000;
const _maxIterations = 5000000;

/// O arquivo não é um backup válido deste app.
class BackupFormatError implements Exception {}

/// Senha errada ou arquivo alterado: a verificação da criptografia não distingue os dois.
class BackupPasswordError implements Exception {}

/// Não foi possível ler algum dado do aparelho. O backup não é gerado pela metade.
class BackupReadError implements Exception {}

/// A gravação falhou e os dados anteriores foram recolocados.
class BackupRestoreError implements Exception {}

class BackupContent {
  final DateTime createdAt;
  final Map<String, dynamic> stores;

  /// Conteúdo do cofre de senhas, quando incluído.
  final String? vault;

  const BackupContent({required this.createdAt, required this.stores, this.vault});

  bool get hasVault => vault != null;

  int _count(String store, [String? key]) {
    final v = stores[store];
    final list = key == null ? v : (v is Map ? v[key] : null);
    return list is List ? list.length : 0;
  }

  int get reminders => _count('reminders');
  int get habits => _count('habits');
  int get notes => _count('notes');
  int get transactions => _count('finance', 'txs');

  int get vaultEntries {
    try {
      return vault == null ? 0 : (jsonDecode(vault!) as List).length;
    } catch (_) {
      return 0;
    }
  }

  Map<String, dynamic> toJson() => {'createdAt': createdAt.toIso8601String(), 'stores': stores, 'vault': vault};

  factory BackupContent.fromJson(Map<String, dynamic> j) => BackupContent(
    createdAt: DateTime.parse(j['createdAt'] as String),
    stores: (j['stores'] as Map).cast<String, dynamic>(),
    vault: j['vault'] as String?,
  );
}

/// A derivação da chave é lenta de propósito (dificulta adivinhar a senha), por isso roda fora da tela.
Future<Uint8List> encryptBackup(BackupContent content, String password, {int iterations = _iterations}) =>
    Isolate.run(() => _encrypt(content.toJson(), password, iterations));

Future<BackupContent> decryptBackup(List<int> bytes, String password) async {
  final data = Uint8List.fromList(bytes);
  final json = await Isolate.run(() => _decrypt(data, password));
  return BackupContent.fromJson(json);
}

Future<SecretKey> _deriveKey(String password, List<int> salt, int iterations) => Pbkdf2(
  macAlgorithm: Hmac.sha256(),
  iterations: iterations,
  bits: 256,
).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

List<int> _header(int iterations, String salt, String nonce) =>
    utf8.encode('$backupMagic|$backupVersion|$iterations|$salt|$nonce');

Future<Uint8List> _encrypt(Map<String, dynamic> content, String password, int iterations) async {
  final cipher = AesGcm.with256bits();
  final salt = SecretKeyData.random(length: 16).bytes;
  final nonce = cipher.newNonce();
  final saltText = base64Encode(salt), nonceText = base64Encode(nonce);
  final box = await cipher.encrypt(
    gzip.encode(utf8.encode(jsonEncode(content))),
    secretKey: await _deriveKey(password, salt, iterations),
    nonce: nonce,
    aad: _header(iterations, saltText, nonceText),
  );
  return Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'format': backupMagic,
        'version': backupVersion,
        'iterations': iterations,
        'salt': saltText,
        'nonce': nonceText,
        'mac': base64Encode(box.mac.bytes),
        'data': base64Encode(box.cipherText),
      }),
    ),
  );
}

Future<Map<String, dynamic>> _decrypt(Uint8List bytes, String password) async {
  final int iterations;
  final String saltText, nonceText;
  final List<int> mac, cipherText, salt, nonce;
  try {
    final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (j['format'] != backupMagic || j['version'] != backupVersion) throw BackupFormatError();
    iterations = j['iterations'] as int;
    // Um arquivo adulterado não pode travar o aparelho com uma derivação sem fim.
    if (iterations < _minIterations || iterations > _maxIterations) throw BackupFormatError();
    saltText = j['salt'] as String;
    nonceText = j['nonce'] as String;
    salt = base64Decode(saltText);
    nonce = base64Decode(nonceText);
    mac = base64Decode(j['mac'] as String);
    cipherText = base64Decode(j['data'] as String);
  } catch (_) {
    throw BackupFormatError();
  }
  final List<int> plain;
  try {
    plain = await AesGcm.with256bits().decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: await _deriveKey(password, salt, iterations),
      aad: _header(iterations, saltText, nonceText),
    );
  } on SecretBoxAuthenticationError {
    throw BackupPasswordError();
  } catch (_) {
    throw BackupFormatError();
  }
  try {
    return jsonDecode(utf8.decode(gzip.decode(plain))) as Map<String, dynamic>;
  } catch (_) {
    throw BackupFormatError();
  }
}

class BackupService {
  final VaultBackend vaultBackend;

  const BackupService(this.vaultBackend);

  Future<BackupContent> collect({required bool includeVault, DateTime? now}) async {
    final stores = <String, dynamic>{};
    for (final name in backupStores) {
      final value = await JsonStore.read(name);
      // Arquivo existente que não se consegue ler não pode sumir do backup sem aviso.
      if (value == null && await JsonStore.exists(name)) throw BackupReadError();
      if (value != null) stores[name] = value;
    }
    String? vault;
    if (includeVault) {
      try {
        vault = await vaultBackend.read();
      } catch (_) {
        throw BackupReadError();
      }
    }
    return BackupContent(createdAt: now ?? DateTime.now(), stores: stores, vault: vault);
  }

  /// Substitui os dados pelos do backup, conferindo cada arquivo. Se algo falhar, recoloca os anteriores.
  /// O cofre só é alterado quando o backup o inclui.
  Future<void> restore(BackupContent content) async {
    final previous = <String, dynamic>{for (final n in backupStores) n: await JsonStore.read(n)};
    String? previousVault;
    if (content.hasVault) {
      try {
        previousVault = await vaultBackend.read();
      } catch (_) {
        throw BackupRestoreError();
      }
    }
    try {
      for (final name in backupStores) {
        await _put(name, content.stores[name]);
      }
      if (content.hasVault) await vaultBackend.write(content.vault!);
    } catch (_) {
      for (final name in backupStores) {
        await _putQuietly(name, previous[name]);
      }
      if (content.hasVault && previousVault != null) {
        try {
          await vaultBackend.write(previousVault);
        } catch (_) {}
      }
      throw BackupRestoreError();
    }
  }

  Future<void> _put(String name, dynamic value) async {
    if (value == null) {
      await JsonStore.delete(name);
      return;
    }
    await JsonStore.write(name, value);
    if (jsonEncode(await JsonStore.read(name)) != jsonEncode(value)) throw BackupRestoreError();
  }

  Future<void> _putQuietly(String name, dynamic value) async {
    try {
      await _put(name, value);
    } catch (_) {}
  }
}
