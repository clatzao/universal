import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal/backup/backup.dart';
import 'package:universal/core/json_store.dart';
import 'package:universal/tools/vault.dart';

class _MemoryVault implements VaultBackend {
  String? value;
  bool failRead = false;
  bool failWrite = false;

  _MemoryVault([this.value]);

  @override
  Future<String?> read() async {
    if (failRead) throw Exception('sem acesso');
    return value;
  }

  @override
  Future<void> write(String v) async {
    if (failWrite) throw Exception('sem acesso');
    value = v;
  }
}

BackupContent _content({String? vault}) => BackupContent(
  createdAt: DateTime(2026, 11, 3, 10),
  stores: {
    'notes': [
      {'id': '1', 'title': 'Ação com acento'},
    ],
    'finance': {
      'txs': [1, 2, 3],
    },
  },
  vault: vault,
);

void main() {
  const fast = 100000;

  group('criptografia', () {
    test('ida e volta preserva tudo', () async {
      final bytes = await encryptBackup(_content(vault: '[{"id":"a"}]'), 'senha-forte', iterations: fast);
      final back = await decryptBackup(bytes, 'senha-forte');
      expect(back.createdAt, DateTime(2026, 11, 3, 10));
      expect(back.notes, 1);
      expect(back.transactions, 3);
      expect(back.vaultEntries, 1);
      expect(jsonEncode(back.stores), jsonEncode(_content().stores));
    });

    test('nada do conteúdo aparece no arquivo', () async {
      final bytes = await encryptBackup(_content(vault: 'minha-senha-secreta'), 'senha-forte', iterations: fast);
      final text = utf8.decode(bytes);
      expect(text, isNot(contains('minha-senha-secreta')));
      expect(text, isNot(contains('acento')));
      expect(text, isNot(contains('senha-forte')));
    });

    test('dois backups iguais geram arquivos diferentes', () async {
      final a = await encryptBackup(_content(), 'senha-forte', iterations: fast);
      final b = await encryptBackup(_content(), 'senha-forte', iterations: fast);
      expect(utf8.decode(a), isNot(utf8.decode(b)));
    });

    test('senha errada é recusada', () async {
      final bytes = await encryptBackup(_content(), 'senha-forte', iterations: fast);
      await expectLater(decryptBackup(bytes, 'outra-senha'), throwsA(isA<BackupPasswordError>()));
    });

    test('arquivo alterado é recusado', () async {
      final j = jsonDecode(
        utf8.decode(await encryptBackup(_content(), 'senha-forte', iterations: fast)),
      ) as Map<String, dynamic>;
      final data = base64Decode(j['data'] as String);
      data[0] ^= 1;
      j['data'] = base64Encode(data);
      await expectLater(decryptBackup(utf8.encode(jsonEncode(j)), 'senha-forte'), throwsA(isA<BackupPasswordError>()));
    });

    test('rebaixar a proteção do arquivo é recusado', () async {
      final j = jsonDecode(
        utf8.decode(await encryptBackup(_content(), 'senha-forte', iterations: fast)),
      ) as Map<String, dynamic>;
      j['iterations'] = 200000;
      await expectLater(decryptBackup(utf8.encode(jsonEncode(j)), 'senha-forte'), throwsA(isA<BackupPasswordError>()));
    });

    test('arquivos que não são backup', () async {
      await expectLater(decryptBackup(utf8.encode('olá'), 'x'), throwsA(isA<BackupFormatError>()));
      await expectLater(decryptBackup([0, 255, 3], 'x'), throwsA(isA<BackupFormatError>()));
      await expectLater(decryptBackup(utf8.encode('{"format":"outro"}'), 'x'), throwsA(isA<BackupFormatError>()));
      await expectLater(
        decryptBackup(utf8.encode(jsonEncode({'format': backupMagic, 'version': 99})), 'x'),
        throwsA(isA<BackupFormatError>()),
      );
      await expectLater(
        decryptBackup(
          utf8.encode(
            jsonEncode({
              'format': backupMagic,
              'version': 1,
              'iterations': 2000000000,
              'salt': '',
              'nonce': '',
              'mac': '',
              'data': '',
            }),
          ),
          'x',
        ),
        throwsA(isA<BackupFormatError>()),
      );
    });
  });

  group('coletar e restaurar', () {
    setUp(() => JsonStore.directory = Directory.systemTemp.createTempSync('backup'));

    test('inclui os dados do app e deixa caches de fora', () async {
      await JsonStore.write('notes', [
        {'id': '1'},
      ]);
      await JsonStore.write('news_cache', {'items': []});
      final c = await BackupService(_MemoryVault()).collect(includeVault: false);
      expect(c.stores.keys, ['notes']);
      expect(c.hasVault, isFalse);
    });

    test('cofre só entra quando pedido', () async {
      final vault = _MemoryVault('[{"id":"a"}]');
      expect((await BackupService(vault).collect(includeVault: false)).vault, isNull);
      expect((await BackupService(vault).collect(includeVault: true)).vaultEntries, 1);
    });

    test('dado ilegível impede o backup em vez de sumir dele', () async {
      await expectLater(
        BackupService(_MemoryVault()..failRead = true).collect(includeVault: true),
        throwsA(isA<BackupReadError>()),
      );
      await JsonStore.write('notes', [1]);
      final dir = Directory.systemTemp.createTempSync('backup2');
      JsonStore.directory = dir;
      File('${dir.path}${Platform.pathSeparator}notes.json').writeAsStringSync('{quebrado');
      await expectLater(BackupService(_MemoryVault()).collect(includeVault: false), throwsA(isA<BackupReadError>()));
    });

    test('restaurar substitui os dados e apaga o que não estava no backup', () async {
      await JsonStore.write('notes', [
        {'id': 'velha'},
      ]);
      await JsonStore.write('habits', [
        {'id': 'sobrando'},
      ]);
      await BackupService(_MemoryVault()).restore(_content());
      expect(await JsonStore.read('notes'), _content().stores['notes']);
      expect(await JsonStore.read('habits'), isNull);
    });

    test('backup sem cofre não mexe no cofre atual', () async {
      final vault = _MemoryVault('atual');
      await BackupService(vault).restore(_content());
      expect(vault.value, 'atual');
      await BackupService(vault).restore(_content(vault: 'novo'));
      expect(vault.value, 'novo');
    });

    test('falha ao gravar o cofre recoloca os dados anteriores', () async {
      await JsonStore.write('notes', [
        {'id': 'velha'},
      ]);
      final vault = _MemoryVault('atual')..failWrite = true;
      await expectLater(BackupService(vault).restore(_content(vault: 'novo')), throwsA(isA<BackupRestoreError>()));
      expect(await JsonStore.read('notes'), [
        {'id': 'velha'},
      ]);
      expect(vault.value, 'atual');
    });

    test('backup completo de ponta a ponta', () async {
      await JsonStore.write('reminders', [
        {'id': 'r'},
      ]);
      await JsonStore.write('finance', {
        'txs': [
          {'id': 't'},
        ],
      });
      final vault = _MemoryVault('[{"id":"v"}]');
      final service = BackupService(vault);
      final bytes = await encryptBackup(await service.collect(includeVault: true), 'senha-forte', iterations: fast);
      await JsonStore.delete('reminders');
      await JsonStore.write('finance', {'txs': []});
      vault.value = null;
      await service.restore(await decryptBackup(bytes, 'senha-forte'));
      expect(await JsonStore.read('reminders'), [
        {'id': 'r'},
      ]);
      expect((await JsonStore.read('finance'))['txs'], hasLength(1));
      expect(vault.value, '[{"id":"v"}]');
    });
  });
}
