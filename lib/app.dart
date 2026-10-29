import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'background/background.dart';
import 'core/theme.dart';
import 'curiosities/curiosities_page.dart';
import 'habits/habits_store.dart';
import 'info/info_store.dart';
import 'more/more_page.dart';
import 'news/news_page.dart';
import 'news/news_store.dart';
import 'notify/actions.dart';
import 'notify/notifications.dart';
import 'reminders/alarm_screen.dart';
import 'reminders/reminders_page.dart';
import 'reminders/reminders_store.dart';
import 'settings/settings.dart';
import 'today/today_page.dart';
import 'update/update_ui.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Aba selecionada (permite trocar de aba a partir de outras telas).
final tabIndex = ValueNotifier<int>(0);

class UniversalApp extends StatefulWidget {
  final NotificationResponse? launchResponse;

  const UniversalApp({super.key, this.launchResponse});

  @override
  State<UniversalApp> createState() => _UniversalAppState();
}

class _UniversalAppState extends State<UniversalApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Notifications.onForegroundResponse = _onResponse;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.launchResponse != null) _onResponse(widget.launchResponse!);
      _startup();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _startup() async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final news = ctx.read<NewsStore>();
    final info = ctx.read<InfoStore>();
    unawaited(info.refresh());
    if (news.updatedAt == null || DateTime.now().difference(news.updatedAt!).inMinutes > 20) {
      unawaited(news.refresh());
    }
    unawaited(_foregroundJobs());
    await UpdateUi.autoCheck(ctx);
  }

  /// Ao abrir o app: condições, lugares e replanejamento.
  Future<void> _foregroundJobs() async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final reminders = ctx.read<RemindersStore>();
    final settings = ctx.read<SettingsStore>();
    try {
      await BackgroundJobs.checkTriggers(settings.value);
    } catch (_) {}
    await reminders.load();
    Replanner.request();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      ctx.read<RemindersStore>().load();
      ctx.read<HabitsStore>().load();
      ctx.read<InfoStore>().refresh();
      Replanner.request();
    }
  }

  void _onResponse(NotificationResponse r) {
    final p = Payload.decode(r.payload);
    if (r.actionId != null && r.actionId!.isNotEmpty) {
      NotificationActions.handle(r);
      return;
    }
    if (p == null) return;
    final nav = navigatorKey.currentState;
    if (p.alarm) {
      nav?.push(MaterialPageRoute(builder: (_) => AlarmScreen(payload: p, notificationId: r.id)));
    } else if (p.kind == 'n' && p.id != null) {
      launchUrl(Uri.parse(p.id!), mode: LaunchMode.externalApplication);
    } else if (p.kind == 'r' || p.kind == 'h') {
      tabIndex.value = 1;
    } else if (p.kind == 'f') {
      tabIndex.value = 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Universal',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _pages = [TodayPage(), RemindersPage(), NewsPage(), CuriositiesPage(), MorePage()];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: tabIndex,
      builder: (context, i, _) => Scaffold(
        body: IndexedStack(index: i, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => tabIndex.value = v,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny), label: 'Hoje'),
            NavigationDestination(
                icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Lembretes'),
            NavigationDestination(icon: Icon(Icons.newspaper_outlined), selectedIcon: Icon(Icons.newspaper), label: 'Notícias'),
            NavigationDestination(
                icon: Icon(Icons.lightbulb_outline), selectedIcon: Icon(Icons.lightbulb), label: 'Curiosidades'),
            NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'Mais'),
          ],
        ),
      ),
    );
  }
}
