import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/system.dart';
import '../core/theme.dart';
import 'photo_qr.dart';

/// Só links web comuns ganham o botão de abrir: o conteúdo de um QR code não é confiável.
Uri? webLinkIn(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null || !uri.hasAuthority) return null;
  return uri.isScheme('http') || uri.isScheme('https') ? uri : null;
}

class QrPage extends StatelessWidget {
  static const readTab = 2;

  final PhotoHost host;
  final int initialTab;

  const QrPage({super.key, this.host = const PhotoHost(), this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('QR code'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Criar'),
              Tab(text: 'Foto'),
              Tab(text: 'Ler'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [const _Create(), _Photo(host), const _Read()],
        ),
      ),
    );
  }
}

/// PNG do código, com fundo branco e margem para qualquer leitor conseguir ler.
Future<Uint8List> qrPng(String data, {int size = 1024}) async {
  final margin = size / 16;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
  canvas.translate(margin, margin);
  QrPainter(data: data, version: QrVersions.auto, gapless: true).paint(canvas, Size.square(size - margin * 2));
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

class _QrFileButtons extends StatelessWidget {
  final String data;

  const _QrFileButtons(this.data);

  void _say(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save(BuildContext context) async {
    try {
      final saved = await SystemInfo.saveFile('qr-code.png', await qrPng(data), type: 'image/png');
      if (saved && context.mounted) _say(context, 'Imagem salva');
    } catch (_) {
      if (context.mounted) _say(context, 'Não foi possível salvar a imagem.');
    }
  }

  Future<void> _share(BuildContext context) async {
    try {
      final file = File('${(await getTemporaryDirectory()).path}/qr-code.png');
      await file.writeAsBytes(await qrPng(data));
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')]));
    } catch (_) {
      if (context.mounted) _say(context, 'Não foi possível compartilhar a imagem.');
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => _save(context),
          icon: const Icon(Icons.save_alt),
          label: const Text('Salvar'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => _share(context),
          icon: const Icon(Icons.share_outlined),
          label: const Text('Compartilhar'),
        ),
      ),
    ],
  );
}

class _Photo extends StatefulWidget {
  final PhotoHost host;

  const _Photo(this.host);

  @override
  State<_Photo> createState() => _PhotoState();
}

class _PhotoState extends State<_Photo> with AutomaticKeepAliveClientMixin {
  int hours = 24;
  Uint8List? photo;
  Uri? link;
  DateTime? expires;
  bool working = false;

  @override
  bool get wantKeepAlive => true;

  void _say(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pick() async {
    setState(() => working = true);
    try {
      final bytes = await SystemInfo.openFile(type: 'image/*');
      if (bytes == null) return;
      final prepared = await widget.host.prepare(bytes);
      if (mounted) setState(() => photo = prepared);
    } on PhotoFormatError {
      if (mounted) _say('Não foi possível ler essa imagem. Tente uma foto em JPG ou PNG.');
    } catch (_) {
      if (mounted) _say('Não foi possível abrir o arquivo.');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _send() async {
    setState(() => working = true);
    try {
      final url = await widget.host.upload(photo!, hours);
      if (!mounted) return;
      setState(() {
        link = url;
        expires = DateTime.now().add(Duration(hours: hours));
        photo = null;
      });
    } on PhotoUploadError {
      if (mounted) _say('Não foi possível enviar a foto. Confira a internet e tente de novo.');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: AppTheme.textMuted);
    final url = link;
    if (url != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(data: url.toString(), size: 240, backgroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Funciona até ${friendlyWhen(expires!)}. Depois disso, a foto é apagada e o código para de abrir.',
            textAlign: TextAlign.center,
            style: t.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text('Quem tiver o código ou o link consegue ver a foto.', textAlign: TextAlign.center, style: muted),
          const SizedBox(height: 16),
          _QrFileButtons(url.toString()),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => launchUrl(url, mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir foto'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url.toString()));
              _say('Link copiado');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar link'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => setState(() => link = null),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Nova foto'),
          ),
        ],
      );
    }
    final picked = photo;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Crie um código que abre uma foto no celular de quem ler.', style: t.bodyMedium),
        const SizedBox(height: 8),
        Text(
          'A foto será enviada para $photoHostName e ficará pública para quem tiver o link. '
          'Ela não pode ser apagada antes do prazo.',
          style: t.bodySmall?.copyWith(color: AppTheme.negative),
        ),
        const SizedBox(height: 16),
        Text('O código funciona por', style: t.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: [for (final h in photoLifetimes) ButtonSegment(value: h, label: Text('$h h'))],
          selected: {hours},
          showSelectedIcon: false,
          onSelectionChanged: working ? null : (s) => setState(() => hours = s.first),
        ),
        const SizedBox(height: 16),
        if (working) ...[const LinearProgressIndicator(), const SizedBox(height: 16)],
        if (picked != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(picked, height: 220, fit: BoxFit.contain),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: working ? null : _send,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Enviar e criar código'),
          ),
          const SizedBox(height: 8),
        ],
        (picked == null ? FilledButton.icon : OutlinedButton.icon)(
          onPressed: working ? null : _pick,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(picked == null ? 'Escolher foto' : 'Trocar foto'),
        ),
      ],
    );
  }
}

class _Create extends StatefulWidget {
  const _Create();

  @override
  State<_Create> createState() => _CreateState();
}

class _CreateState extends State<_Create> {
  final c = TextEditingController();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = c.text.trim();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: c,
          minLines: 1,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Texto ou link'),
        ),
        const SizedBox(height: 24),
        if (text.isNotEmpty) ...[
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              // O fundo fica branco para qualquer leitor conseguir ler o código.
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(data: text, size: 240, backgroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          _QrFileButtons(text),
        ] else
          Text(
            'Digite algo para gerar o código.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
      ],
    );
  }
}

class _Read extends StatefulWidget {
  const _Read();

  @override
  State<_Read> createState() => _ReadState();
}

class _ReadState extends State<_Read> with AutomaticKeepAliveClientMixin {
  MobileScannerController? controller;
  String? result;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _start() => setState(() {
    result = null;
    controller ??= MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  });

  void _onDetect(BarcodeCapture capture) {
    final value = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (value == null || result != null) return;
    HapticFeedback.mediumImpact();
    final old = controller;
    setState(() {
      result = value;
      controller = null;
    });
    old?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = Theme.of(context).textTheme;
    final value = result;
    if (value != null) {
      final link = webLinkIn(value);
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Conteúdo do código', style: t.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(value, style: t.bodyLarge),
            ),
          ),
          const SizedBox(height: 12),
          if (link != null) ...[
            Text(
              'Confira o endereço antes de abrir: ${link.host}',
              style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => launchUrl(link, mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir link'),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiado')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Ler outro'),
          ),
        ],
      );
    }
    final scanner = controller;
    if (scanner == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code_scanner, size: 56, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              Text(
                'A câmera só liga quando você tocar no botão.',
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Ler código'),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: MobileScanner(
            controller: scanner,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Permita o uso da câmera nas configurações do Android para ler códigos.'
                      : 'Não foi possível abrir a câmera.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: IconButton.filledTonal(
            tooltip: 'Lanterna',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: scanner.toggleTorch,
          ),
        ),
      ],
    );
  }
}
