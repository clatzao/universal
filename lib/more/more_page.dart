import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../settings/settings_page.dart';
import '../update/update_ui.dart';
import '../update/updater.dart';

class _Soon {
  final String title;
  final IconData icon;
  final List<String> items;

  const _Soon(this.title, this.icon, this.items);
}

const _soon = [
  _Soon('Joguinhos', Icons.sports_esports, [
    'Palavra do dia (estilo Termo)',
    'Forca',
    'Caça-palavras',
    'Snake',
    'Tetris',
    'Flappy',
    'Quiz com as curiosidades',
    'Jogo da memória',
    'Caso do dia (investigação curta)',
    'Escape room de texto',
    'Carreira de futebol (estilo New Star Soccer / Soccer Champs)',
    'Desafio diário, recordes e modo contra alguém',
  ]),
  _Soon('Finanças', Icons.account_balance_wallet, ['Gastos', 'Contas fixas', 'Assinaturas', 'Orçamento']),
  _Soon('Notas e listas', Icons.checklist, ['Notas rápidas', 'Listas de compras e tarefas']),
  _Soon('Ferramentas', Icons.build, ['Conversor', 'Pomodoro', 'Dividir conta', 'QR code']),
];

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
        Card(
          child: Column(children: [
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
                subtitle: Text(snap.hasData ? 'Instalada: ${snap.data!.version} (build ${snap.data!.buildNumber})' : ''),
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
          ]),
        ),
        const SizedBox(height: 8),
        for (final s in _soon)
          Card(
            child: ExpansionTile(
              leading: Icon(s.icon),
              title: Text(s.title),
              subtitle: const Text('Em breve'),
              children: [
                for (final i in s.items)
                  ListTile(dense: true, leading: const Icon(Icons.schedule, size: 18), title: Text(i)),
              ],
            ),
          ),
      ]),
    );
  }
}
