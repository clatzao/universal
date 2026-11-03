import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../settings/settings_page.dart';
import '../tools/tools_page.dart';
import '../update/update_ui.dart';
import '../update/updater.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.handyman_outlined),
              title: const Text('Ferramentas'),
              subtitle: const Text('Conversor, dividir conta, sorteio, QR code, cofre de senhas e mais'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ToolsPage())),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Configurações'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
                ),
                FutureBuilder(
                  future: Updater.installed(),
                  builder: (_, snap) => ListTile(
                    leading: const Icon(Icons.system_update),
                    title: const Text('Verificar atualização'),
                    subtitle: Text(
                      snap.hasData ? 'Instalada: ${snap.data!.version} (build ${snap.data!.buildNumber})' : '',
                    ),
                    onTap: () => UpdateUi.manualCheck(context),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Link de download'),
                  subtitle: const Text(downloadLink, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    tooltip: 'Copiar',
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: downloadLink));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copiado')));
                    },
                  ),
                  onTap: () => launchUrl(Uri.parse(downloadLink), mode: LaunchMode.externalApplication),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
