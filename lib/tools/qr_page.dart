import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';

/// Só links web comuns ganham o botão de abrir: o conteúdo de um QR code não é confiável.
Uri? webLinkIn(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null || !uri.hasAuthority) return null;
  return uri.isScheme('http') || uri.isScheme('https') ? uri : null;
}

class QrPage extends StatelessWidget {
  const QrPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('QR code'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Criar'),
              Tab(text: 'Ler'),
            ],
          ),
        ),
        body: const TabBarView(physics: NeverScrollableScrollPhysics(), children: [_Create(), _Read()]),
      ),
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
        if (text.isNotEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              // O fundo fica branco para qualquer leitor conseguir ler o código.
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(data: text, size: 240, backgroundColor: Colors.white),
            ),
          )
        else
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
