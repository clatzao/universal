import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'background/background.dart';
import 'core/pixel_art.dart';
import 'core/system.dart';
import 'core/theme.dart';
import 'curiosities/curiosities_page.dart';
import 'finance/finance_page.dart';
import 'finance/finance_store.dart';
import 'games/games_page.dart';
import 'habits/habits_page.dart';
import 'habits/habits_store.dart';
import 'info/info_store.dart';
import 'more/more_page.dart';
import 'news/news_page.dart';
import 'news/news_reader.dart';
import 'news/news_store.dart';
import 'notes/note.dart';
import 'notes/notes_page.dart';
import 'notes/notes_store.dart';
import 'notify/actions.dart';
import 'notify/notifications.dart';
import 'reminders/alarm_screen.dart';
import 'reminders/reminder_editor.dart';
import 'reminders/reminders_page.dart';
import 'reminders/reminders_store.dart';
import 'search/search_page.dart';
import 'settings/settings.dart';
import 'today/today_page.dart';
import 'tools/qr_page.dart';
import 'workout/workout_page.dart';
import 'update/update_ui.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Posições das abas da barra inferior.
abstract final class Tabs {
  static const hoje = 0;
  static const lembretes = 1;
  static const habitos = 2;
  static const treinos = 3;
  static const notas = 4;
  static const noticias = 5;
  static const financas = 6;
  static const curiosidades = 7;
  static const jogos = 8;
  static const mais = 9;
}

/// Aba selecionada (permite trocar de aba a partir de outras telas).
final tabIndex = ValueNotifier<int>(Tabs.hoje);

class UniversalApp extends StatefulWidget {
  final NotificationResponse? launchResponse;

  const UniversalApp({super.key, this.launchResponse});

  @override
  State<UniversalApp> createState() => _UniversalAppState();
}

class _UniversalAppState extends State<UniversalApp> with WidgetsBindingObserver {
  final _openedAlarms = <String>{};
  Timer? _alarmTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Notifications.onForegroundResponse = _onResponse;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.launchResponse != null) _onResponse(widget.launchResponse!);
      _startup();
      _watchAlarms();
    });
  }

  void _watchAlarms() {
    _checkActiveAlarms();
    _alarmTimer?.cancel();
    _alarmTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkActiveAlarms());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _startup() async {
    SystemInfo.listenShortcuts(_openShortcut);
    final shortcut = await SystemInfo.takeShortcut();
    if (shortcut != null) _openShortcut(shortcut);
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final news = ctx.read<NewsStore>();
    final info = ctx.read<InfoStore>();
    unawaited(info.refresh());
    if (news.updatedAt == null || DateTime.now().difference(news.updatedAt!).inMinutes > 20) {
      unawaited(news.refresh());
    }
    unawaited(_foregroundJobs());
    await UpdateUi.autoCheck(ctx);
  }

  /// Atalhos de segurar o ícone do app (res/xml/shortcuts.xml).
  void _openShortcut(String name) {
    final nav = navigatorKey.currentState;
    final ctx = navigatorKey.currentContext;
    if (nav == null || ctx == null) return;
    final Widget? page = switch (name) {
      'reminder' => const ReminderEditor(),
      'note' => NoteEditorPage(noteId: ctx.read<NotesStore>().create(NoteKind.nota).id),
      'search' => const SearchPage(),
      'qr' => const QrPage(initialTab: QrPage.readTab),
      _ => null,
    };
    if (page != null) nav.push(MaterialPageRoute(builder: (_) => page));
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
    if (state != AppLifecycleState.resumed) {
      _alarmTimer?.cancel();
      _alarmTimer = null;
    }
    if (state == AppLifecycleState.resumed) {
      _watchAlarms();
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      ctx.read<RemindersStore>().load();
      ctx.read<HabitsStore>().load();
      ctx.read<FinanceStore>().load();
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
      _openAlarm(p, r.id);
    } else if (p.kind == 'n' && p.id != null) {
      // Alerta de palavra-chave: abre o resumo; sem a notícia em memória, abre o site.
      final ctx = navigatorKey.currentContext;
      final news = ctx?.read<NewsStore>();
      final item = news?.items.where((i) => i.link == p.id).firstOrNull;
      if (item != null) {
        news!.markRead(item);
        nav?.push(MaterialPageRoute(builder: (_) => NewsReaderPage(item: item)));
      } else {
        launchUrl(Uri.parse(p.id!), mode: LaunchMode.externalApplication);
      }
    } else if (p.kind == 'r') {
      tabIndex.value = Tabs.lembretes;
    } else if (p.kind == 'h') {
      tabIndex.value = Tabs.habitos;
    } else if (p.kind == 'f') {
      tabIndex.value = Tabs.curiosidades;
    }
  }

  void _openAlarm(Payload p, int? id) {
    if (!_openedAlarms.add('$id|${p.occurrence?.millisecondsSinceEpoch}')) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => AlarmScreen(payload: p, notificationId: id),
      ),
    );
  }

  /// O Android só abre a tela cheia sozinho com o aparelho bloqueado. Com o app aberto,
  /// ela é aberta aqui, assim que há um alarme tocando.
  Future<void> _checkActiveAlarms() async {
    try {
      final active = await Notifications.plugin.getActiveNotifications();
      final keys = <String>{};
      for (final n in active.where((n) => n.channelId == alarmChannel)) {
        final p = Payload.decode(n.payload);
        if (p == null || !p.alarm) continue;
        keys.add('${n.id}|${p.occurrence?.millisecondsSinceEpoch}');
        _openAlarm(p, n.id);
      }
      // Um alarme encerrado pode tocar de novo na próxima insistência ou adiamento.
      _openedAlarms.retainWhere(keys.contains);
    } catch (_) {}
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

class _TabInfo {
  final String label;
  final PixelSprite icon;
  final Widget page;

  const _TabInfo(this.label, this.icon, this.page);
}

/// Mesma ordem das constantes em [Tabs].
const _tabs = [
  _TabInfo('Hoje', PixelIcons.hoje, TodayPage()),
  _TabInfo('Lembretes', PixelIcons.lembretes, RemindersPage()),
  _TabInfo('Hábitos', PixelIcons.habitos, HabitsTab()),
  _TabInfo('Treinos', PixelIcons.treinos, WorkoutPage()),
  _TabInfo('Notas', PixelIcons.notas, NotesPage()),
  _TabInfo('Notícias', PixelIcons.noticias, NewsPage()),
  _TabInfo('Finanças', PixelIcons.financas, FinancePage()),
  _TabInfo('Curiosidades', PixelIcons.curiosidades, CuriositiesPage()),
  _TabInfo('Jogos', PixelIcons.jogos, GamesPage()),
  _TabInfo('Mais', PixelIcons.mais, MorePage()),
];

/// Abas: deslize para trocar; tocar na aba atual volta ao topo. O gesto de voltar
/// retorna ao Hoje e, de lá, só fecha o app se for repetido.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final PageController _pages = PageController(initialPage: tabIndex.value);
  final _scrolls = [for (final _ in _tabs) ScrollController()];
  DateTime? _lastBack;

  @override
  void initState() {
    super.initState();
    tabIndex.addListener(_syncPage);
  }

  @override
  void dispose() {
    tabIndex.removeListener(_syncPage);
    _pages.dispose();
    for (final s in _scrolls) {
      s.dispose();
    }
    super.dispose();
  }

  void _syncPage() {
    if (!_pages.hasClients) return;
    final current = _pages.page?.round() ?? tabIndex.value;
    if (current == tabIndex.value) return;
    if ((current - tabIndex.value).abs() == 1) {
      _pages.animateToPage(tabIndex.value, duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
    } else {
      _pages.jumpToPage(tabIndex.value);
    }
  }

  void _onTabTap(int i) {
    HapticFeedback.selectionClick();
    if (i != tabIndex.value) {
      tabIndex.value = i;
      return;
    }
    final s = _scrolls[i];
    // Com abas internas há mais de uma lista ligada: nesse caso não há "o" topo.
    if (s.positions.length == 1) {
      s.animateTo(0, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  void _onBack() {
    if (tabIndex.value != Tabs.hoje) {
      tabIndex.value = Tabs.hoje;
      return;
    }
    final now = DateTime.now();
    if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Volte de novo para sair'), duration: Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: PageView(
          controller: _pages,
          onPageChanged: (i) => tabIndex.value = i,
          children: [
            for (var i = 0; i < _tabs.length; i++)
              _KeepAlive(
                child: PrimaryScrollController(controller: _scrolls[i], child: _tabs[i].page),
              ),
          ],
        ),
        bottomNavigationBar: ValueListenableBuilder<int>(
          valueListenable: tabIndex,
          builder: (_, i, _) => _BottomBar(selected: i, onTap: _onTabTap),
        ),
      ),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;

  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Barra inferior rolável: cabem mais funções do que na barra padrão de 5 itens.
class _BottomBar extends StatefulWidget {
  final int selected;
  final ValueChanged<int> onTap;

  const _BottomBar({required this.selected, required this.onTap});

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  static const _itemWidth = 78.0;
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _center(animate: false));
  }

  @override
  void didUpdateWidget(_BottomBar old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _center();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _center({bool animate = true}) {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final target = (widget.selected * _itemWidth + _itemWidth / 2 - p.viewportDimension / 2).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    );
    if (animate) {
      _controller.animateTo(target, duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: AppTheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            itemCount: _tabs.length,
            itemExtent: _itemWidth,
            itemBuilder: (_, i) {
              final tab = _tabs[i];
              final on = i == widget.selected;
              final color = on ? AppTheme.text : AppTheme.textMuted;
              return InkWell(
                onTap: () => widget.onTap(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 52,
                      height: 30,
                      decoration: BoxDecoration(
                        color: on ? AppTheme.surfaceHighest : Colors.transparent,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(child: PixelArt(tab.icon, size: 20, color: color)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: t.labelSmall?.copyWith(
                        color: color,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
