import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../notify/notifications.dart';
import 'reminders_store.dart';

/// Tela própria do alarme em tela cheia.
class AlarmScreen extends StatelessWidget {
  final Payload payload;
  final int? notificationId;

  const AlarmScreen({super.key, required this.payload, this.notificationId});

  Future<void> _stopSound() async {
    if (notificationId != null) await Notifications.plugin.cancel(id: notificationId!);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<RemindersStore>();
    final r = store.byId(payload.id);
    final scheme = Theme.of(context).colorScheme;
    final title = r?.title ?? payload.title ?? 'Alarme';
    final when = payload.occurrence ?? DateTime.now();

    Future<void> snooze(Duration d) async {
      await _stopSound();
      if (r != null) await store.snooze(r, d);
      if (context.mounted) Navigator.pop(context);
    }

    return Scaffold(
      backgroundColor: scheme.primaryContainer,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.alarm, size: 96, color: scheme.onPrimaryContainer),
              const SizedBox(height: 16),
              Text(hm(when),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(color: scheme.onPrimaryContainer)),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: scheme.onPrimaryContainer)),
              if (r != null && r.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(r.notes, textAlign: TextAlign.center, style: TextStyle(color: scheme.onPrimaryContainer)),
                ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                icon: const Icon(Icons.check),
                label: const Text('Feito', style: TextStyle(fontSize: 20)),
                onPressed: () async {
                  await _stopSound();
                  if (r != null) await store.done(r, occurrence: payload.occurrence);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final (label, d) in [
                    ('10 min', const Duration(minutes: 10)),
                    ('30 min', const Duration(minutes: 30)),
                    ('1 h', const Duration(hours: 1)),
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                          onPressed: () => snooze(d),
                          child: Text('Adiar $label'),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                icon: const Icon(Icons.volume_off),
                label: const Text('Só silenciar'),
                onPressed: () async {
                  await _stopSound();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
