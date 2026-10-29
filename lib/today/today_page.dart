import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../core/format.dart';
import '../core/theme.dart';
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

final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _brl0 = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);

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
    final todayCount = upcoming.where((o) => dayOf(o.at) == dayOf(now)).length;
    final habitsMet = habits.where((h) => h.metOn(now)).length;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final reminderTiles = [
      for (final o in pending) ReminderTile(reminder: o.reminder, when: o.at, pending: true),
      for (final o in upcoming.take(8)) ReminderTile(reminder: o.reminder, when: o.at),
    ];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([info.refresh(force: true), context.read<NewsStore>().refresh()]);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  longDate(now).toUpperCase(),
                  style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1.2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Text(_greeting(now), style: t.headlineMedium),
              ),
              if (holiday != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _Pill(icon: Icons.celebration_outlined, text: holiday),
                  ),
                ),
              _WeatherCard(info: info, hasCity: settings.hasLocation || settings.useGps, city: settings.cityName),
              _QuotesRow(info: info),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    _Stat(label: 'Atrasados', value: '${pending.length}', highlight: pending.isNotEmpty),
                    const SizedBox(width: 10),
                    _Stat(label: 'Hoje', value: '$todayCount'),
                    const SizedBox(width: 10),
                    _Stat(label: 'Hábitos', value: habits.isEmpty ? '—' : '$habitsMet/${habits.length}'),
                  ],
                ),
              ),
              _Section(title: 'Lembretes', onMore: () => tabIndex.value = 1),
              if (reminderTiles.isEmpty)
                const _Empty(icon: Icons.notifications_none, text: 'Nada nas próximas 36 horas.')
              else
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (var i = 0; i < reminderTiles.length; i++) ...[
                        if (i > 0) const Divider(indent: 72),
                        reminderTiles[i],
                      ],
                    ],
                  ),
                ),
              if (habits.isNotEmpty) ...[
                const _Section(title: 'Hábitos'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(children: [for (final h in habits) HabitCard(habit: h, compact: true)]),
                ),
              ],
              _Section(title: 'Curiosidade do dia', onMore: () => tabIndex.value = 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FactOfDayCard(fact: factOfDay(now)),
              ),
              _Section(title: 'Manchetes', onMore: () => tabIndex.value = 2),
              if (news.isEmpty) const _Empty(icon: Icons.newspaper, text: 'Carregando notícias…'),
              for (final n in news)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: NewsCard(item: n, dense: true),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;

  const _Section({required this.title, this.onMore});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 8, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: t.titleMedium)),
          if (onMore != null)
            TextButton(
              onPressed: onMore,
              style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Ver tudo'), Icon(Icons.chevron_right, size: 18)],
              ),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: const TextStyle(color: AppTheme.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _Stat({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: highlight ? AppTheme.surfaceHighest : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: highlight ? AppTheme.outlineStrong : AppTheme.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: t.titleLarge),
            const SizedBox(height: 2),
            Text(label, style: t.labelSmall?.copyWith(color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _QuotesRow extends StatelessWidget {
  final InfoStore info;

  const _QuotesRow({required this.info});

  @override
  Widget build(BuildContext context) {
    final q = info.quotes;
    if (q == null) return const SizedBox();
    final t = Theme.of(context).textTheme;

    Widget tile(String label, double? v, double? change, {bool noCents = false}) {
      final up = (change ?? 0) >= 0;
      return Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label, style: t.labelSmall?.copyWith(color: AppTheme.textMuted, letterSpacing: 0.8)),
                  const Spacer(),
                  if (change != null)
                    Text(
                      '${up ? '▲' : '▼'}${change.abs().toStringAsFixed(1)}%',
                      style: t.labelSmall?.copyWith(color: up ? AppTheme.positive : AppTheme.negative),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(v == null ? '—' : (noCents ? _brl0 : _brl).format(v), style: t.titleSmall),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          tile('DÓLAR', q.usd, q.usdChange),
          const SizedBox(width: 10),
          tile('EURO', q.eur, q.eurChange),
          const SizedBox(width: 10),
          tile('BITCOIN', q.btc, q.btcChange, noCents: true),
        ],
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
    const margin = EdgeInsets.fromLTRB(16, 20, 16, 0);
    if (!hasCity) {
      return Card(
        margin: margin,
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
        margin: margin,
        child: ListTile(
          leading: const Icon(Icons.cloud_queue),
          title: Text(info.loading ? 'Carregando clima…' : (info.error ?? 'Clima indisponível')),
        ),
      );
    }
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.surfaceHighest, AppTheme.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(city ?? 'Sua localização', style: t.labelLarge?.copyWith(color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    Text(
                      '${w.temp.round()}°',
                      style: t.displayMedium?.copyWith(fontWeight: FontWeight.w300, height: 1.0, letterSpacing: -2),
                    ),
                    const SizedBox(height: 4),
                    Text(w.description, style: t.titleSmall),
                  ],
                ),
              ),
              Icon(w.icon, size: 56, color: AppTheme.text),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(icon: Icons.thermostat, text: '${w.minToday.round()}° / ${w.maxToday.round()}°'),
              _Pill(icon: Icons.umbrella_outlined, text: 'Hoje ${w.rainToday}%'),
              _Pill(icon: Icons.event_outlined, text: 'Amanhã ${w.rainTomorrow}%'),
            ],
          ),
          const SizedBox(height: 10),
          Text('Atualizado ${ago(w.fetchedAt)}', style: t.labelSmall?.copyWith(color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}
