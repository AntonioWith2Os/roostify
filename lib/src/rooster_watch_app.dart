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

  @override
  void initState() {
    super.initState();
    _controller = AppController(cameras: widget.cameras);
    unawaited(_controller.loadPersistedLiveCctvStreams());
  }

  void _finishStartup() {
    if (!_showStartup) return;
    setState(() => _showStartup = false);
  }

  @override
  void dispose() {
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
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: _controller.themePreference.themeMode,
          home: _showStartup
              ? StartupPage(onFinished: _finishStartup)
              : LandingPage(controller: _controller),
        );
      },
    );
  }
}
