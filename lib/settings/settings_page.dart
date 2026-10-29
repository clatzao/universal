import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../info/info_store.dart';
import '../news/news_page.dart';
import '../news/news_store.dart';
import '../notify/notifications.dart';
import '../reminders/holidays.dart';
import '../reminders/recurrence.dart';
import '../reminders/reminder.dart';
import '../reminders/reminder_editor.dart';
import '../core/format.dart';
import 'settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? notifOk;
  bool? exactOk;
  LocationPermission? locPerm;

  @override
  void initState() {
    super.initState();
    _refreshPerms();
  }

  Future<void> _refreshPerms() async {
    final n = await Notifications.enabled();
    final e = await Notifications.canScheduleExact();
    LocationPermission? l;
    try {
      l = await Geolocator.checkPermission();
    } catch (_) {}
    if (mounted) {
      setState(() {
        notifOk = n;
        exactOk = e;
        locPerm = l;
      });
    }
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(t, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );

  String _locLabel(LocationPermission? p) => switch (p) {
        LocationPermission.always => 'Permitido o tempo todo ✓',
        LocationPermission.whileInUse => 'Só durante o uso — lembretes por lugar precisam de "o tempo todo"',
        LocationPermission.denied => 'Negada',
        LocationPermission.deniedForever => 'Negada (abra as configurações do Android)',
        _ => 'Desconhecida',
      };

  Future<void> _addHoliday(SettingsStore store) async {
    final name = TextEditingController();
    DateTime? date;
    var yearly = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Feriado local'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome (ex.: Aniversário da cidade)')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(date == null ? 'Escolher data' : '${two(date!.day)}/${two(date!.month)}/${date!.year}'),
              onPressed: () async {
                final d = await showDatePicker(
                    context: c, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d != null) set(() => date = d);
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Repete todo ano'),
              value: yearly,
              onChanged: (v) => set(() => yearly = v ?? true),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Adicionar')),
          ],
        ),
      ),
    );
    if (ok != true || date == null) return;
    await store.update(
      (s) => s.localHolidays = [
        ...s.localHolidays,
        LocalHoliday(
          day: date!.day,
          month: date!.month,
          year: yearly ? null : date!.year,
          name: name.text.trim().isEmpty ? 'Feriado local' : name.text.trim(),
        ),
      ],
      replan: true,
    );
  }

  Future<void> _addKeyword(SettingsStore store) async {
    final c = TextEditingController();
    final k = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Palavra-chave'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Ex.: Flamengo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Adicionar')),
        ],
      ),
    );
    if (k == null || k.isEmpty) return;
    await store.update((s) => s.keywords = {...s.keywords, k}.toList());
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsStore>();
    final s = store.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        _header('Clima'),
        ListTile(
          leading: const Icon(Icons.location_city),
          title: Text(s.cityName ?? 'Nenhuma cidade definida'),
          subtitle: const Text('Toque para buscar'),
          onTap: () async {
            final p = await showCitySearch(context);
            if (p == null || !context.mounted) return;
            await store.update((x) {
              x.cityName = p.name.split(',').first;
              x.lat = p.lat;
              x.lon = p.lon;
              x.useGps = false;
            });
            if (context.mounted) context.read<InfoStore>().refresh(force: true);
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.my_location),
          title: const Text('Usar GPS'),
          subtitle: const Text('Usa sua localização atual em vez da cidade'),
          value: s.useGps,
          onChanged: (v) async {
            if (v) {
              final p = await Geolocator.requestPermission();
              if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
            }
            await store.update((x) {
              x.useGps = v;
              if (v) x.cityName = 'Minha localização';
            });
            if (context.mounted) context.read<InfoStore>().refresh(force: true);
            _refreshPerms();
          },
        ),
        _header('Feriados e dias úteis'),
        SwitchListTile(
          title: const Text('Carnaval conta como feriado'),
          subtitle: const Text('Ponto facultativo nacional'),
          value: s.countCarnival,
          onChanged: (v) => store.update((x) => x.countCarnival = v, replan: true),
        ),
        SwitchListTile(
          title: const Text('Corpus Christi conta como feriado'),
          subtitle: const Text('Ponto facultativo nacional'),
          value: s.countCorpusChristi,
          onChanged: (v) => store.update((x) => x.countCorpusChristi = v, replan: true),
        ),
        for (final h in s.localHolidays)
          ListTile(
            leading: const Icon(Icons.flag),
            title: Text(h.name),
            subtitle: Text('${two(h.day)}/${two(h.month)}${h.year == null ? ' (todo ano)' : '/${h.year}'}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => store.update((x) => x.localHolidays = [...x.localHolidays]..remove(h), replan: true),
            ),
          ),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Adicionar feriado local'),
          onTap: () => _addHoliday(store),
        ),
        _header('Curiosidade do dia'),
        SwitchListTile(
          title: const Text('Notificação diária'),
          value: s.factNotify,
          onChanged: (v) => store.update((x) => x.factNotify = v, replan: true),
        ),
        ListTile(
          enabled: s.factNotify,
          leading: const Icon(Icons.schedule),
          title: Text('Horário: ${s.factTime.format()}'),
          onTap: () async {
            final t = await showTimePicker(
                context: context, initialTime: TimeOfDay(hour: s.factTime.h, minute: s.factTime.m));
            if (t != null) await store.update((x) => x.factTime = HM(t.hour, t.minute), replan: true);
          },
        ),
        _header('Notícias'),
        SwitchListTile(
          title: const Text('Alertas por palavra-chave'),
          subtitle: const Text('Checado em segundo plano a cada ~30 min'),
          value: s.keywordAlerts,
          onChanged: (v) => store.update((x) => x.keywordAlerts = v),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            for (final k in s.keywords)
              InputChip(label: Text(k), onDeleted: () => store.update((x) => x.keywords = [...x.keywords]..remove(k))),
            ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Palavra'), onPressed: () => _addKeyword(store)),
          ]),
        ),
        ListTile(
          leading: const Icon(Icons.rss_feed),
          title: const Text('Fontes'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SourcesPage())),
        ),
        _header('Permissões'),
        ListTile(
          leading: const Icon(Icons.notifications_active),
          title: const Text('Notificações'),
          subtitle: Text(notifOk == true ? 'Permitidas ✓' : 'Toque para permitir'),
          onTap: () async {
            await Notifications.requestPermissions();
            _refreshPerms();
          },
        ),
        ListTile(
          leading: const Icon(Icons.alarm_on),
          title: const Text('Alarmes exatos'),
          subtitle: Text(exactOk == true ? 'Permitidos ✓' : 'Toque para permitir'),
          onTap: () async {
            await Notifications.requestExactAlarms();
            _refreshPerms();
          },
        ),
        ListTile(
          leading: const Icon(Icons.fullscreen),
          title: const Text('Alarme em tela cheia'),
          subtitle: const Text('Toque para revisar a permissão (Android 14+)'),
          onTap: Notifications.requestFullScreen,
        ),
        ListTile(
          leading: const Icon(Icons.location_on),
          title: const Text('Localização'),
          subtitle: Text(_locLabel(locPerm)),
          onTap: () async {
            var p = await Geolocator.checkPermission();
            if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
            if (p == LocationPermission.whileInUse) p = await Geolocator.requestPermission();
            if (p != LocationPermission.always) await Geolocator.openAppSettings();
            _refreshPerms();
          },
        ),
        _header('Testes'),
        ListTile(
          leading: const Icon(Icons.notifications),
          title: const Text('Testar notificação'),
          onTap: () async {
            await Notifications.requestPermissions();
            await Notifications.show(
              id: nidTest * 100,
              title: 'Teste do Universal',
              body: 'Se você está vendo isto, as notificações funcionam.',
              details: Notifications.reminderDetails(Category.pessoal),
              payload: const Payload('t', id: 'teste'),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.alarm),
          title: const Text('Testar alarme em tela cheia (10 s)'),
          subtitle: const Text('Bloqueie a tela para ver o alarme abrir'),
          onTap: () async {
            await Notifications.requestPermissions();
            final at = DateTime.now().add(const Duration(seconds: 10));
            await Notifications.schedule(
              id: nidTest * 100 + 1,
              at: at,
              title: 'Alarme de teste',
              body: 'Toque em Feito, Adiar ou Só silenciar',
              details: Notifications.reminderDetails(Category.pessoal, alarm: true),
              payload: Payload('t', id: 'teste', occurrence: at, alarm: true, title: 'Alarme de teste'),
              alarmClock: true,
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alarme em 10 segundos')));
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.newspaper),
          title: const Text('Testar alertas de notícias agora'),
          onTap: () async {
            await NewsService.checkKeywordAlerts(s, force: true);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Feito. Na primeira vez só marca as notícias existentes como vistas.')));
            }
          },
        ),
        _header('Atualização'),
        SwitchListTile(
          title: const Text('Atualização automática'),
          subtitle: const Text('Procura nova versão ao abrir o app (no máximo a cada 3 h)'),
          value: s.autoUpdate,
          onChanged: (v) => store.update((x) => x.autoUpdate = v),
        ),
        _header('Nuvem'),
        const ListTile(
          leading: Icon(Icons.cloud_sync),
          title: Text('Sincronização na nuvem'),
          subtitle: Text('Em breve. Por enquanto, tudo fica salvo só neste aparelho.'),
        ),
      ]),
    );
  }
}
