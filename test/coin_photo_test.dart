import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:universal/core/theme.dart';
import 'package:universal/tools/coin_flip.dart';
import 'package:universal/tools/photo_qr.dart';
import 'package:universal/tools/qr_page.dart';
import 'package:universal/tools/tools_page.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class _FixedRandom implements Random {
  final bool value;

  _FixedRandom(this.value);

  @override
  bool nextBool() => value;

  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => 0;
}

class _FakeHost extends PhotoHost {
  bool fail = false;
  int uploads = 0;
  int? lastHours;

  @override
  Future<Uint8List> prepare(Uint8List bytes) async => bytes;

  @override
  Future<Uri> upload(Uint8List png, int hours) async {
    if (fail) throw PhotoUploadError();
    uploads++;
    lastHours = hours;
    return Uri.parse('https://litter.catbox.moe/abc.png');
  }
}

Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(Offset.zero & Size(width.toDouble(), height.toDouble()), Paint()..color = Colors.red);
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('moeda', () {
    test('sempre termina deitada no lado sorteado', () {
      for (final from in [true, false]) {
        expect(cos(coinAngle(1, fromCara: from, toCara: true)), closeTo(1, 1e-9));
        expect(cos(coinAngle(1, fromCara: from, toCara: false)), closeTo(-1, 1e-9));
      }
    });

    test('começa no lado em que estava', () {
      expect(cos(coinAngle(0, fromCara: true, toCara: false)), closeTo(1, 1e-9));
      expect(cos(coinAngle(0, fromCara: false, toCara: true)), closeTo(-1, 1e-9));
    });

    test('sobe, cai e fica no chão', () {
      expect(coinHeight(0), 0);
      expect(coinHeight(0.41), closeTo(1, 1e-9));
      expect(coinHeight(1), closeTo(0, 1e-9));
    });

    Future<void> openCoin(WidgetTester tester, bool cara) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: DrawPage(random: _FixedRandom(cara)),
        ),
      );
      await tester.tap(find.text('Moeda'));
      await tester.pumpAndSettle();
    }

    for (final (cara, label) in [(true, 'Cara'), (false, 'Coroa')]) {
      testWidgets('o resultado $label só aparece depois de cair', (tester) async {
        await openCoin(tester, cara);
        await tester.tap(find.text('Jogar a moeda'));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('Girando…'), findsOneWidget);
        expect(find.text(label), findsNothing);
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
        expect(find.text(label.toUpperCase()), findsOneWidget);
        expect(find.text('Jogar a moeda'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('jogar de novo esconde o resultado anterior', (tester) async {
      await openCoin(tester, false);
      await tester.tap(find.text('Jogar a moeda'));
      await tester.pumpAndSettle();
      expect(find.text('Coroa'), findsOneWidget);
      await tester.tap(find.text('Jogar a moeda'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Coroa'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('sair do modo durante o giro não causa erro', (tester) async {
      await openCoin(tester, true);
      await tester.tap(find.text('Jogar a moeda'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Times'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('envio da foto', () {
    test('manda o prazo e devolve o link', () async {
      late String body;
      final host = PhotoHost(
        client: MockClient((r) async {
          body = r.body;
          expect(r.url.toString(), 'https://litterbox.catbox.moe/resources/internals/api.php');
          return http.Response('https://litter.catbox.moe/abc.png\n', 200);
        }),
      );
      final link = await host.upload(Uint8List.fromList([1, 2, 3]), 72);
      expect(link.toString(), 'https://litter.catbox.moe/abc.png');
      expect(body, contains('72h'));
      expect(body, contains('fileupload'));
      expect(body, contains('name="fileToUpload"'));
    });

    for (final (name, response) in [
      ('erro do servidor', http.Response('https://litter.catbox.moe/a.png', 500)),
      ('mensagem em vez de link', http.Response('Limite atingido', 200)),
      ('endereço de outro site', http.Response('https://exemplo.com/a.png', 200)),
      ('endereço sem https', http.Response('http://litter.catbox.moe/a.png', 200)),
    ]) {
      test('recusa $name', () {
        final host = PhotoHost(client: MockClient((_) async => response));
        expect(host.upload(Uint8List(1), 1), throwsA(isA<PhotoUploadError>()));
      });
    }

    test('falha de rede vira erro de envio', () {
      final host = PhotoHost(client: MockClient((_) async => throw Exception('sem rede')));
      expect(host.upload(Uint8List(1), 1), throwsA(isA<PhotoUploadError>()));
    });

    test('foto grande é reduzida mantendo a proporção', () async {
      final png = await const PhotoHost().prepare(await _png(3200, 1600));
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, PhotoHost.maxSide);
      expect(image.height, 800);
    });

    test('foto pequena mantém o tamanho e arquivo inválido é recusado', () async {
      final png = await const PhotoHost().prepare(await _png(20, 10));
      final image = (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;
      expect((image.width, image.height), (20, 10));
      await expectLater(const PhotoHost().prepare(Uint8List.fromList([1, 2, 3])), throwsA(isA<PhotoFormatError>()));
    });
  });

  group('aba Foto', () {
    const channel = MethodChannel('universal/system');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    String? askedType;

    setUp(() {
      askedType = null;
      messenger.setMockMethodCallHandler(channel, (call) async {
        askedType = (call.arguments as Map)['type'] as String?;
        return Uint8List.fromList(_pixel);
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    Future<void> open(WidgetTester tester, _FakeHost host) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: QrPage(host: host),
        ),
      );
      await tester.tap(find.text('Foto'));
      await tester.pumpAndSettle();
    }

    testWidgets('avisa antes e só envia depois de confirmar', (tester) async {
      final host = _FakeHost();
      await open(tester, host);
      expect(find.textContaining('ficará pública'), findsOneWidget);
      await tester.tap(find.text('72 h'));
      await tester.pump();
      await tester.tap(find.text('Escolher foto'));
      await tester.pumpAndSettle();
      expect(askedType, 'image/*');
      expect(host.uploads, 0);

      await tester.tap(find.text('Enviar e criar código'));
      await tester.pumpAndSettle();
      expect(host.uploads, 1);
      expect(host.lastHours, 72);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.textContaining('Funciona até'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Nova foto'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Escolher foto'), findsOneWidget);
    });

    testWidgets('falha no envio mantém a foto para tentar de novo', (tester) async {
      final host = _FakeHost()..fail = true;
      await open(tester, host);
      await tester.tap(find.text('Escolher foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar e criar código'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Não foi possível enviar'), findsOneWidget);
      expect(find.text('Enviar e criar código'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('cancelar o seletor não muda nada', (tester) async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      await open(tester, _FakeHost());
      await tester.tap(find.text('Escolher foto'));
      await tester.pumpAndSettle();
      expect(find.text('Escolher foto'), findsOneWidget);
      expect(find.text('Enviar e criar código'), findsNothing);
    });
  });
}
