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
  Session? _restoredSession;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<AppAlertEvent>? _alertSubscription;

  @override
  void initState() {
    super.initState();
    _controller = AppController(cameras: widget.cameras);
    unawaited(_controller.loadPersistedLiveCctvStreams());
    _alertSubscription = _controller.alertEvents.listen(_handleAlertEvent);
    unawaited(_restoreRememberedSession());
  }

  Future<void> _restoreRememberedSession() async {
    final session = await _controller.restoreRememberedSession();
    if (!mounted || session == null) return;
    setState(() => _restoredSession = session);
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
    unawaited(_alertSubscription?.cancel());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Roostify',
          scaffoldMessengerKey: _messengerKey,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: _controller.themePreference.themeMode,
          locale: _controller.languageLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: _showStartup
              ? StartupPage(onFinished: _finishStartup)
              : (_restoredSession != null
                    ? AppShell(
                        controller: _controller,
                        session: _restoredSession!,
                      )
                    : LoginPage(
                        controller: _controller,
                        expectedRole: UserRole.user,
                      )),
        );
      },
    );
  }
}
