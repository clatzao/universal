import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VaultEntry {
  final String id;
  String name;
  String username;
  String password;
  String site;
  String notes;
  DateTime updatedAt;

  VaultEntry({
    required this.id,
    this.name = '',
    this.username = '',
    this.password = '',
    this.site = '',
    this.notes = '',
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'username': username,
    'password': password,
    'site': site,
    'notes': notes,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory VaultEntry.fromJson(Map<String, dynamic> j) => VaultEntry(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    username: j['username'] as String? ?? '',
    password: j['password'] as String? ?? '',
    site: j['site'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
    updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

abstract class VaultBackend {
  Future<String?> read();

  Future<void> write(String value);
}

/// Criptografia com chave guardada no Keystore do Android.
class SecureVaultBackend implements VaultBackend {
  static const _key = 'vault_v1';

  // resetOnError ligado apagaria todas as senhas ao primeiro erro de leitura.
  final _storage = const FlutterSecureStorage(aOptions: AndroidOptions(resetOnError: false));

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}

/// Não foi possível ler o cofre: nada pode ser gravado por cima.
class VaultReadError implements Exception {}

/// As senhas só ficam na memória enquanto o cofre está aberto.
class VaultStore extends ChangeNotifier {
  final VaultBackend backend;
  List<VaultEntry> entries = [];
  bool isOpen = false;

  static int _seq = 0;
  static String newId() => '${DateTime.now().microsecondsSinceEpoch}${_seq++}';

  VaultStore(this.backend);

  Future<void> open() async {
    final List<VaultEntry> loaded;
    try {
      final raw = await backend.read();
      loaded = raw == null
          ? []
          : [for (final e in jsonDecode(raw) as List) VaultEntry.fromJson((e as Map).cast<String, dynamic>())];
    } catch (_) {
      throw VaultReadError();
    }
    entries = loaded;
    isOpen = true;
    notifyListeners();
  }

  void lock() {
    entries = [];
    isOpen = false;
    notifyListeners();
  }

  List<VaultEntry> search(String query) {
    final q = query.trim().toLowerCase();
    final list =
        entries.where((e) => q.isEmpty || '${e.name} ${e.username} ${e.site}'.toLowerCase().contains(q)).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> _persist() => backend.write(jsonEncode([for (final e in entries) e.toJson()]));

  Future<void> save(VaultEntry entry) async {
    if (!isOpen) throw StateError('Cofre trancado');
    final previous = entries;
    entries = [...entries.where((e) => e.id != entry.id), entry];
    try {
      await _persist();
    } catch (_) {
      entries = previous;
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }

  Future<void> remove(VaultEntry entry) async {
    if (!isOpen) throw StateError('Cofre trancado');
    final previous = entries;
    entries = entries.where((e) => e.id != entry.id).toList();
    try {
      await _persist();
    } catch (_) {
      entries = previous;
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }
}

Timer? _clipboardTimer;

/// Copia um dado sensível e limpa a área de transferência depois de 30 s, se ele ainda estiver lá.
Future<void> copySensitive(String value) async {
  await Clipboard.setData(ClipboardData(text: value));
  _clipboardTimer?.cancel();
  _clipboardTimer = Timer(const Duration(seconds: 30), () async {
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    if (current?.text == value) await Clipboard.setData(const ClipboardData(text: ''));
  });
}
