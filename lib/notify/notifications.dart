import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../reminders/reminder.dart';
import 'actions.dart';

/// IDs reservados (nid): 1 = curiosidade do dia, 2 = testes, 3 = notícias, 4 = condições/lugares.
const nidFact = 1;
const nidTest = 2;
const nidNews = 3;
const nidTrigger = 4;

const actDone = 'done';
const actSnooze10 = 'snooze10';
const actSnooze60 = 'snooze60';
const actHabitAdd = 'habit_add';

const alarmChannel = 'alarme_v1';
const generalChannel = 'geral';
const habitChannel = 'habitos';

/// Conteúdo da notificação (payload JSON).
class Payload {
  /// r = lembrete, h = hábito, f = curiosidade, n = notícia, t = teste.
  final String kind;
  final String? id;
  final DateTime? occurrence;
  final bool alarm;
  final String? title;

  const Payload(this.kind, {this.id, this.occurrence, this.alarm = false, this.title});

  String encode() => jsonEncode({
        'k': kind,
        if (id != null) 'id': id,
        if (occurrence != null) 't': occurrence!.millisecondsSinceEpoch,
        if (alarm) 'a': true,
        if (title != null) 'ti': title,
      });

  static Payload? decode(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return Payload(
        j['k'] as String,
        id: j['id'] as String?,
        occurrence: j['t'] == null ? null : DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
        alarm: (j['a'] as bool?) ?? false,
        title: j['ti'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  await Notifications.init(background: true);
  await NotificationActions.handle(response, background: true);
}

class Notifications {
  static final plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Chamado no app aberto quando o usuário toca numa notificação.
  static void Function(NotificationResponse r)? onForegroundResponse;

  static AndroidFlutterLocalNotificationsPlugin? get android =>
      plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> initTimezone() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }
  }

  static Future<void> init({bool background = false}) async {
    if (_ready) return;
    await initTimezone();
    await plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_notify')),
      onDidReceiveNotificationResponse: (r) {
        if (onForegroundResponse != null) {
          onForegroundResponse!(r);
        } else {
          NotificationActions.handle(r);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    if (!background) await _createChannels();
    _ready = true;
  }

  static Future<void> _createChannels() async {
    final a = android;
    if (a == null) return;
    for (final c in Category.values) {
      await a.createNotificationChannel(AndroidNotificationChannel(
        c.channelId,
        'Lembretes · ${c.label}',
        description: 'Lembretes da categoria ${c.label}',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound(c.sound),
      ));
    }
    await a.createNotificationChannel(const AndroidNotificationChannel(
      alarmChannel,
      'Alarmes em tela cheia',
      description: 'Lembretes no modo alarme',
      importance: Importance.max,
      sound: UriAndroidNotificationSound('content://settings/system/alarm_alert'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ));
    await a.createNotificationChannel(const AndroidNotificationChannel(
      habitChannel,
      'Hábitos',
      description: 'Lembretes de hábitos',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('som_saude'),
    ));
    await a.createNotificationChannel(const AndroidNotificationChannel(
      generalChannel,
      'Geral',
      description: 'Curiosidade do dia, notícias e avisos',
      importance: Importance.defaultImportance,
    ));
  }

  static const _reminderActions = [
    AndroidNotificationAction(actDone, '✓ Feito', cancelNotification: true),
    AndroidNotificationAction(actSnooze10, 'Adiar 10 min', cancelNotification: true),
    AndroidNotificationAction(actSnooze60, 'Adiar 1 h', cancelNotification: true),
  ];

  static NotificationDetails reminderDetails(Category cat, {bool alarm = false, String? body}) {
    if (alarm) {
      return NotificationDetails(
        android: AndroidNotificationDetails(
          alarmChannel,
          'Alarmes em tela cheia',
          importance: Importance.max,
          priority: Priority.max,
          icon: 'ic_stat_notify',
          color: cat.color,
          sound: const UriAndroidNotificationSound('content://settings/system/alarm_alert'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          // FLAG_INSISTENT: o som repete até a notificação ser tratada.
          additionalFlags: Int32List.fromList(<int>[4]),
          autoCancel: false,
          visibility: NotificationVisibility.public,
          actions: _reminderActions,
        ),
      );
    }
    return NotificationDetails(
      android: AndroidNotificationDetails(
        cat.channelId,
        'Lembretes · ${cat.label}',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notify',
        color: cat.color,
        sound: RawResourceAndroidNotificationSound(cat.sound),
        category: AndroidNotificationCategory.reminder,
        styleInformation: body == null ? null : BigTextStyleInformation(body),
        actions: _reminderActions,
      ),
    );
  }

  static NotificationDetails habitDetails(String addLabel) => NotificationDetails(
        android: AndroidNotificationDetails(
          habitChannel,
          'Hábitos',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_notify',
          sound: const RawResourceAndroidNotificationSound('som_saude'),
          actions: [AndroidNotificationAction(actHabitAdd, addLabel, cancelNotification: true)],
        ),
      );

  static NotificationDetails generalDetails({String? body}) => NotificationDetails(
        android: AndroidNotificationDetails(
          generalChannel,
          'Geral',
          icon: 'ic_stat_notify',
          styleInformation: body == null ? null : BigTextStyleInformation(body),
        ),
      );

  static Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    String? body,
    required NotificationDetails details,
    required Payload payload,
    bool alarmClock = false,
  }) async {
    await plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: details,
      androidScheduleMode: alarmClock ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.exactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload.encode(),
    );
  }

  static Future<void> show({
    required int id,
    required String title,
    String? body,
    NotificationDetails? details,
    Payload? payload,
  }) =>
      plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details ?? generalDetails(body: body),
        payload: payload?.encode(),
      );

  /// Remove notificações exibidas (e pendentes) de um nid.
  static Future<void> cancelShown(int nid) async {
    try {
      final active = await plugin.getActiveNotifications();
      for (final n in active) {
        final id = n.id;
        if (id != null && id ~/ 100 == nid) await plugin.cancel(id: id);
      }
    } catch (_) {}
  }

  static Future<bool> requestPermissions() async {
    final a = android;
    if (a == null) return false;
    final ok = await a.requestNotificationsPermission() ?? false;
    return ok;
  }

  static Future<void> requestFullScreen() async => android?.requestFullScreenIntentPermission();

  static Future<void> requestExactAlarms() async => android?.requestExactAlarmsPermission();

  static Future<bool> canScheduleExact() async => await android?.canScheduleExactNotifications() ?? false;

  static Future<bool> enabled() async => await android?.areNotificationsEnabled() ?? false;
}
