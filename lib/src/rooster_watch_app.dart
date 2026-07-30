part of '../main.dart';

class RoosterWatchApp extends StatefulWidget {
  const RoosterWatchApp({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  State<RoosterWatchApp> createState() => _RoosterWatchAppState();
}

class _RoosterWatchAppState extends State<RoosterWatchApp> {
  late final AppController _controller;
  bool _showStartup = true;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AppAlertEvent>? _alertSubscription;
  late AppThemePreference _themePreference;
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _controller = AppController(cameras: widget.cameras);
    _themePreference = _controller.themePreference;
    _locale = _controller.languageLocale;
    // Listen narrowly instead of wrapping MaterialApp in an AnimatedBuilder
    // tied to every controller notification: the controller also notifies
    // for unrelated background work (CCTV stream loads, ESP32 readings,
    // alerts, etc.), and rebuilding the whole MaterialApp — and therefore
    // remounting whatever route is on screen — while those land can knock
    // focus off a field the user is actively typing into, closing the
    // Android soft keyboard mid-word. Only rebuild when theme/locale, the
    // two things this widget actually renders from the controller, change.
    _controller.addListener(_handleControllerChanged);
    unawaited(_controller.loadPersistedLiveCctvStreams());
    _alertSubscription = _controller.alertEvents.listen(_handleAlertEvent);
    unawaited(_restoreRememberedSession());
  }

  void _handleControllerChanged() {
    final preference = _controller.themePreference;
    final locale = _controller.languageLocale;
    if (preference == _themePreference && locale == _locale) return;
    setState(() {
      _themePreference = preference;
      _locale = locale;
    });
  }

  // Deliberately navigates via the Navigator instead of swapping the
  // MaterialApp's `home` widget: this can resolve while the user has a
  // dialog open on LoginPage (e.g. "Forgot password?"). Swapping `home` out
  // from under an open dialog route tears down LoginPage's element while
  // the dialog above it still references it, which hits a framework
  // assertion ('_dependents.isEmpty': is not true). Routing through
  // pushAndRemoveUntil lets the Navigator tear down the dialog and
  // LoginPage the normal, supported way.
  Future<void> _restoreRememberedSession() async {
    final session = await _controller.restoreRememberedSession();
    if (!mounted || session == null) return;
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => AppShell(controller: _controller, session: session),
      ),
      (route) => false,
    );
  }

  void _finishStartup() {
    if (!_showStartup) return;
    setState(() => _showStartup = false);
  }

  void _handleAlertEvent(AppAlertEvent event) {
    final messenger = _messengerKey.currentState;
    if (messenger != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: event.severity == AlertSeverity.danger
                ? const Color(0xFFB92D49)
                : null,
            content: Text('${event.title} — ${event.message}'),
            duration: const Duration(seconds: 4),
          ),
        );
    }
    if (event.playSound) {
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
    if (event.vibrate) {
      unawaited(HapticFeedback.vibrate());
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    unawaited(_alertSubscription?.cancel());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Roostify',
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: _themePreference.themeMode,
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: _showStartup
          ? StartupPage(onFinished: _finishStartup)
          : LoginPage(controller: _controller, expectedRole: UserRole.user),
    );
  }
}
