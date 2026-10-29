import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'background/background.dart';
import 'curiosities/curiosities_store.dart';
import 'habits/habits_store.dart';
import 'info/info_store.dart';
import 'news/news_store.dart';
import 'notify/actions.dart';
import 'notify/notifications.dart';
import 'notify/planner.dart';
import 'reminders/reminders_store.dart';
import 'settings/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');
  await Notifications.init();

  final settings = SettingsStore();
  await settings.load();
  final reminders = RemindersStore(settings);
  final habits = HabitsStore(settings);
  final news = NewsStore(settings);
  final info = InfoStore(settings);
  final curiosities = CuriositiesStore();
  await Future.wait([reminders.load(), habits.load(), news.load(), info.load()]);

  settings.onReplan = () async => Replanner.request();
  NotificationActions.onChanged = () async {
    await reminders.load();
    await habits.load();
  };

  NotificationResponse? launch;
  try {
    final d = await Notifications.plugin.getNotificationAppLaunchDetails();
    if (d?.didNotificationLaunchApp ?? false) launch = d!.notificationResponse;
  } catch (_) {}

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: reminders),
      ChangeNotifierProvider.value(value: habits),
      ChangeNotifierProvider.value(value: news),
      ChangeNotifierProvider.value(value: info),
      ChangeNotifierProvider.value(value: curiosities),
    ],
    child: UniversalApp(launchResponse: launch),
  ));

  unawaited(Planner.replan());
  unawaited(BackgroundJobs.register().catchError((Object _) {}));
}
