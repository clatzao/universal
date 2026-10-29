import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../core/format.dart';
import '../curiosities/curiosities_page.dart';
import '../curiosities/facts.dart';
import '../habits/habits_page.dart';
import '../habits/habits_store.dart';
import '../info/info_store.dart';
import '../news/news_page.dart';
import '../news/news_store.dart';
import '../reminders/reminders_page.dart';
import '../reminders/reminders_store.dart';
import '../settings/settings.dart';
import '../settings/settings_page.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  String _greeting(DateTime n) {
    if (n.hour < 5) return 'Boa madrugada';
    if (n.hour < 12) return 'Bom dia';
    if (n.hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final settings = context.watch<SettingsStore>().value;
    final reminders = context.watch<RemindersStore>();
    final habits = context.watch<HabitsStore>().items;
    final info = context.watch<InfoStore>();
    final news = context.watch<NewsStore>().visible.take(4).toList();
    final holiday = settings.calendar.holidayName(now);
    final pending = reminders.pending();
    final upcoming = reminders.upcoming();
    final t = Theme.of(context).textTheme;

    Widget header(String text, {VoidCallback? more}) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Row(children: [
            Expanded(child: Text(text, style: t.titleMedium)),
            if (more != null) TextButton(onPressed: more, child: const Text('Ver tudo')),
          ]),
        );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([info.refresh(force: true), context.read<NewsStore>().refresh()]);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text('${_greeting(now)}!', style: t.headlineMedium),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(longDate(now), style: t.bodyLarge),
              ),
              if (holiday != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Chip(avatar: const Icon(Icons.celebration, size: 18), label: Text(holiday)),
                ),
              _WeatherCard(info: info, hasCity: settings.hasLocation || settings.useGps, city: settings.cityName),
              header('Lembretes', more: () => tabIndex.value = 1),
              if (pending.isEmpty && upcoming.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Nada nas próximas 36 horas.'),
                ),
              for (final o in pending) ReminderTile(reminder: o.reminder, when: o.at, pending: true),
              for (final o in upcoming.take(8)) ReminderTile(reminder: o.reminder, when: o.at),
              if (habits.isNotEmpty) ...[
                header('Hábitos'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(children: [for (final h in habits) HabitCard(habit: h, compact: true)]),
                ),
              ],
              header('Curiosidade do dia', more: () => tabIndex.value = 3),
              FactOfDayCard(fact: factOfDay(now)),
              header('Manchetes', more: () => tabIndex.value = 2),
              if (news.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Carregando notícias…')),
              for (final n in news) NewsCard(item: n, dense: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  final InfoStore info;
  final bool hasCity;
  final String? city;

  const _WeatherCard({required this.info, required this.hasCity, this.city});

  @override
  Widget build(BuildContext context) {
    final w = info.weather;
    final t = Theme.of(context).textTheme;
    if (!hasCity) {
      return Card(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: ListTile(
          leading: const Icon(Icons.location_city),
          title: const Text('Defina sua cidade para ver o clima'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
        ),
      );
    }
    if (w == null) {
      return Card(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: ListTile(
          leading: const Icon(Icons.cloud_queue),
          title: Text(info.loading ? 'Carregando clima…' : (info.error ?? 'Clima indisponível')),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(w.icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${w.temp.round()}°C · ${w.description}', style: t.titleMedium),
              Text('${city ?? 'Sua localização'} · mín ${w.minToday.round()}° máx ${w.maxToday.round()}°', style: t.bodySmall),
              const SizedBox(height: 4),
              Text('Chuva hoje: ${w.rainToday}% · amanhã: ${w.rainTomorrow}%', style: t.bodyMedium),
            ]),
          ),
          Text(ago(w.fetchedAt), style: t.labelSmall),
        ]),
      ),
    );
  }
}
