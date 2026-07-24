part of '../../main.dart';

class StartupPage extends StatefulWidget {
  const StartupPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  static const _fallbackSplashAsset = 'assets/startup.jpeg';
  static const _splashVideoAsset = 'asset:///assets/splash.mp4';
  static const _staticFallbackDuration = Duration(milliseconds: 3600);
  static const _videoFallbackDuration = Duration(seconds: 5);

  FijkPlayer? _player;
  Timer? _fallbackTimer;
  bool _videoFailed = false;
  bool _finished = false;

  bool get _supportsVideoSplash {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  @override
  void initState() {
    super.initState();
    final supportsVideoSplash = _supportsVideoSplash;
    _fallbackTimer = Timer(
      supportsVideoSplash ? _videoFallbackDuration : _staticFallbackDuration,
      _finish,
    );

    if (supportsVideoSplash) {
      final player = FijkPlayer();
      player.addListener(_handlePlayerChanged);
      _player = player;
      unawaited(_playSplashVideo(player));
    }
  }

  Future<void> _playSplashVideo(FijkPlayer player) async {
    try {
      await player.setVolume(0);
      await player.setLoop(1);
      await player.setDataSource(_splashVideoAsset, autoPlay: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _videoFailed = true);
    }
  }

  void _handlePlayerChanged() {
    final player = _player;
    if (player == null || !mounted) return;
    if (player.value.completed) {
      _finish();
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _fallbackTimer?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    final player = _player;
    if (player != null) {
      player.removeListener(_handlePlayerChanged);
      unawaited(player.release().catchError((_) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final player = _player;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.backgroundGradientStart,
              colors.backgroundGradientMiddle,
              colors.backgroundGradientEnd,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SizedBox.expand(
          child: player != null && !_videoFailed
              ? FijkView(
                  player: player,
                  fit: FijkFit.cover,
                  fs: false,
                  color: Colors.black,
                  cover: const AssetImage(_fallbackSplashAsset),
                  panelBuilder: (_, _, _, _, _) => const SizedBox.shrink(),
                )
              : Image.asset(_fallbackSplashAsset, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key, required this.controller});

  final AppController controller;

  void _openLogin(BuildContext context, UserRole role) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(controller: controller, expectedRole: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _AuthImageBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _LandingLoginPanel(
                            onUserTap: () => _openLogin(context, UserRole.user),
                            onAdminTap: () =>
                                _openLogin(context, UserRole.admin),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: const [
                              AppPill(
                                icon: Icons.sensors_outlined,
                                label: 'Live Environment',
                              ),
                              AppPill(
                                icon: Icons.videocam_outlined,
                                label: 'YOLOv8 CCTV',
                              ),
                              AppPill(
                                icon: Icons.camera_alt_outlined,
                                label: 'Phone Camera Scan',
                              ),
                              AppPill(
                                icon: Icons.menu_book_outlined,
                                label: 'Care Guidelines',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.controller,
    required this.expectedRole,
  });

  final AppController controller;
  final UserRole expectedRole;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _loginOrange = Color(0xFFF08F3A);
  static const _loginRed = Color(0xFFE53935);

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _signingInWithGoogle = false;
  bool _signingInWithPassword = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _openSession(Session session) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) =>
            AppShell(controller: widget.controller, session: session),
      ),
      (route) => false,
    );
  }

  void _signInWithPassword() {
    setState(() {
      _error = null;
      _signingInWithPassword = true;
    });

    final session = widget.controller.signIn(
      username: _usernameController.text,
      password: _passwordController.text,
      expectedRole: widget.expectedRole,
    );

    if (!mounted) return;

    if (session == null) {
      setState(() {
        _error = widget.controller.lastError;
        _signingInWithPassword = false;
      });
      return;
    }

    _openSession(session);
  }

  Future<void> _signInWithGoogle() async {
    // Disable the button while the native Google account chooser is open.
    setState(() {
      _error = null;
      _signingInWithGoogle = true;
    });

    final session = await widget.controller.signInWithGoogle(
      expectedRole: widget.expectedRole,
    );

    if (!mounted) return;

    if (session == null) {
      setState(() {
        _error = widget.controller.lastError;
        _signingInWithGoogle = false;
      });
      return;
    }

    _openSession(session);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.expectedRole == UserRole.admin;
    return Scaffold(
      body: _AuthImageBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE8E5E0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: const Color(0xFF17191E),
                                tooltip: 'Back',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isAdmin ? 'Admin login' : 'User login',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF17191E),
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _usernameController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Username or email',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                                fillColor: Color(0xFFF6F5F2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _signingInWithPassword
                                  ? null
                                  : _signInWithPassword(),
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline_rounded),
                                fillColor: Color(0xFFF6F5F2),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3A1F2A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFFF8A98),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: _loginRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                  side: const BorderSide(color: _loginRed),
                                ),
                              ),
                              onPressed: _signingInWithPassword
                                  ? null
                                  : _signInWithPassword,
                              icon: _signingInWithPassword
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: Text(
                                _signingInWithPassword
                                    ? 'Signing in...'
                                    : isAdmin
                                    ? 'Log in'
                                    : 'Log in',
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: _loginOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                  side: const BorderSide(color: _loginOrange),
                                ),
                              ),
                              onPressed: _signingInWithGoogle
                                  ? null
                                  : _signInWithGoogle,
                              icon: _signingInWithGoogle
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.g_mobiledata_rounded,
                                      size: 28,
                                    ),
                              label: Text(
                                _signingInWithGoogle
                                    ? 'Opening Google...'
                                    : isAdmin
                                    ? 'Continue as Admin with Google'
                                    : 'Continue with Google',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller, required this.session});

  final AppController controller;
  final Session session;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.session.user.isAdmin;

    final pages = isAdmin
        ? [
            AdminOverviewPage(controller: widget.controller),
            AdminUsersPage(controller: widget.controller),
            AdminCctvPage(controller: widget.controller),
            SupportInboxPage(controller: widget.controller),
            ProfilePage(controller: widget.controller, session: widget.session),
          ]
        : [
            UserDashboardPage(
              controller: widget.controller,
              session: widget.session,
            ),
            UserCctvPage(
              controller: widget.controller,
              session: widget.session,
            ),
            UserManualCameraTabPage(
              controller: widget.controller,
              session: widget.session,
            ),
            UserGuidelinesPage(
              controller: widget.controller,
              session: widget.session,
            ),
            ProfilePage(controller: widget.controller, session: widget.session),
          ];

    final destinations = isAdmin
        ? const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: 'Users',
            ),
            NavigationDestination(
              icon: Icon(Icons.videocam_outlined),
              selectedIcon: Icon(Icons.videocam),
              label: 'CCTV',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: 'Inbox',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ]
        : const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.videocam_outlined),
              selectedIcon: Icon(Icons.videocam),
              label: 'CCTV',
            ),
            NavigationDestination(
              icon: Icon(Icons.camera_alt_outlined),
              selectedIcon: Icon(Icons.camera_alt),
              label: 'Scan',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Guides',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ];

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          body: pages[_index],
          floatingActionButton: isAdmin
              ? null
              : _SupportChatBubble(
                  controller: widget.controller,
                  session: widget.session,
                ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: NavigationBar(
            backgroundColor: Colors.white,
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: destinations,
          ),
        );
      },
    );
  }
}

class _SupportChatBubble extends StatelessWidget {
  const _SupportChatBubble({required this.controller, required this.session});

  final AppController controller;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final thread = controller.threadForUser(session.user.username);
    final messageCount = thread?.messages.length ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          heroTag: 'support-chat-bubble',
          tooltip: 'Chat admin',
          shape: const CircleBorder(),
          backgroundColor: _appAccent,
          foregroundColor: Colors.white,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    SupportChatPage(controller: controller, session: session),
              ),
            );
          },
          child: const Icon(Icons.chat_bubble_outline),
        ),
        if (messageCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF26C281),
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                messageCount > 99 ? '99+' : '$messageCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class UserDashboardPage extends StatelessWidget {
  const UserDashboardPage({
    super.key,
    required this.controller,
    required this.session,
  });

  final AppController controller;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final user = controller.userByUsername(session.user.username)!;
    final monitor = user.monitor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AlertsPage(alerts: monitor.alerts),
                ),
              );
            },
            icon: const Icon(Icons.notifications_active_outlined),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final temperatureAlerts = monitor.alerts
              .where(
                (alert) =>
                    alert.category == 'Temperature' ||
                    alert.category == 'Environment',
              )
              .toList();
          final humidityAlerts = monitor.alerts
              .where(
                (alert) =>
                    alert.category == 'Humidity' ||
                    alert.category == 'Environment',
              )
              .toList();
          final airAlerts = monitor.alerts
              .where(
                (alert) =>
                    alert.category == 'Air Pollution' ||
                    alert.category == 'Air Quality',
              )
              .toList();
          // Count each alert once even when it shows on two cards (the
          // combined heat-and-humidity warning appears on both).
          final activeWarnings = monitor.alerts
              .where((alert) => alert.severity != AlertSeverity.info)
              .length;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FarmOverviewCard(
                  cctvCount: user.cctvs.length,
                  alertCount: activeWarnings,
                ),
                const SizedBox(height: 12),
                const _DashboardSectionTitle(
                  title: 'Live Environment',
                  subtitle: 'Updated just now',
                  online: true,
                ),
                const SizedBox(height: 8),
                Esp32SensorConnectionCard(
                  controller: controller,
                  username: user.username,
                ),
                const SizedBox(height: 10),
                CircularSensorGauge(
                  title: 'Temperature',
                  value: monitor.temperature.toStringAsFixed(1),
                  unit: '°C',
                  progress: monitor.temperature / 45,
                  icon: Icons.thermostat_outlined,
                  status: monitor.temperatureStatus,
                  level: monitor.temperatureLevel,
                  alerts: temperatureAlerts,
                ),
                const SizedBox(height: 10),
                CircularSensorGauge(
                  title: 'Humidity',
                  value: monitor.humidity.toStringAsFixed(0),
                  unit: '%',
                  progress: monitor.humidity / 100,
                  icon: Icons.water_drop_outlined,
                  status: monitor.humidityStatus,
                  level: monitor.humidityLevel,
                  alerts: humidityAlerts,
                ),
                const SizedBox(height: 10),
                CircularSensorGauge(
                  title: 'Air Pollution',
                  value: '${monitor.airPpm}',
                  unit: 'ppm',
                  progress: monitor.airPpm / 50,
                  icon: Icons.air_outlined,
                  status: monitor.airStatus,
                  level: monitor.airLevel,
                  alerts: airAlerts,
                ),
                const SizedBox(height: 16),
                const _DashboardSectionTitle(
                  title: 'Farm status',
                  subtitle: 'Current monitoring summary',
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.appColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.appColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        activeWarnings == 0
                            ? Icons.verified_outlined
                            : Icons.warning_amber_outlined,
                        color: activeWarnings == 0
                            ? const Color(0xFF26C281)
                            : _appAccent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          activeWarnings == 0
                              ? 'Farm conditions look safe. Tap a sensor card to see its details.'
                              : 'Tap a sensor card with a badge to see its warnings. The Guides tab explains each warning.',
                          style: TextStyle(
                            color: context.appColors.mutedText,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SeverityTag(
                        label: activeWarnings == 0
                            ? 'ALL CLEAR'
                            : '$activeWarnings ACTIVE',
                        color: activeWarnings == 0
                            ? const Color(0xFF26C281)
                            : _appAccent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FarmOverviewCard extends StatelessWidget {
  const _FarmOverviewCard({required this.cctvCount, required this.alertCount});
  final int cctvCount;
  final int alertCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _OverviewMetric(value: '$cctvCount', label: 'CCTVs'),
              ),
              Expanded(
                child: _OverviewMetric(
                  value: '$alertCount',
                  label: 'Alerts today',
                ),
              ),
              const Expanded(
                child: _OverviewMetric(value: '28', label: 'Chickens'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: TextStyle(
          color: context.appColors.mutedText,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _DashboardSectionTitle extends StatelessWidget {
  const _DashboardSectionTitle({
    required this.title,
    required this.subtitle,
    this.online = false,
  });
  final String title;
  final String subtitle;
  final bool online;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: context.appColors.mutedText,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
      if (online)
        const Row(
          children: [
            Icon(Icons.circle, color: Color(0xFF23BF75), size: 8),
            SizedBox(width: 4),
            Text(
              'Online',
              style: TextStyle(
                color: Color(0xFF23BF75),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
    ],
  );
}

class UserManualCameraTabPage extends StatelessWidget {
  const UserManualCameraTabPage({
    super.key,
    required this.controller,
    required this.session,
  });

  final AppController controller;
  final Session session;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final user = controller.userByUsername(session.user.username)!;
        final colors = context.appColors;

        if (user.cameraAccessEnabled) {
          return ManualCameraPage(controller: controller, user: user);
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Manual Rooster Scan')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const SectionHeader(
                title: 'Manual Phone Camera Scan',
                subtitle:
                    'Admin access control decides who may use phone camera detection.',
              ),
              const SizedBox(height: 12),
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(
                            0xFFFF6B72,
                          ).withValues(alpha: 0.14),
                          foregroundColor: const Color(0xFFFF6B72),
                          child: const Icon(Icons.block_outlined),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Phone camera detection is disabled by admin.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Use CCTV monitoring for now or open the chat bubble to request manual scan access.',
                      style: TextStyle(color: colors.mutedText, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class UserCctvPage extends StatelessWidget {
  const UserCctvPage({
    super.key,
    required this.controller,
    required this.session,
  });

  final AppController controller;
  final Session session;

  void _openManageCameras(BuildContext context, AppUser user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CctvManagementSheet(controller: controller, user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final user = controller.userByUsername(session.user.username)!;
        final streams = user.liveCctvStreams;

        return Scaffold(
          appBar: AppBar(
            title: const Text('CCTV Monitoring'),
            actions: [
              if (streams.length >= 2)
                IconButton(
                  tooltip: 'View every connected camera at once',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            MultiCameraFullscreenPage(streams: streams),
                      ),
                    );
                  },
                  icon: const Icon(Icons.grid_view_outlined),
                ),
              IconButton(
                tooltip: 'Manage cameras',
                onPressed: () => _openManageCameras(context, user),
                icon: const Icon(Icons.tune_outlined),
              ),
            ],
          ),
          body: streams.isEmpty
              ? _CctvTabEmptyState(
                  onManage: () => _openManageCameras(context, user),
                )
              : _CctvFullscreenFeed(
                  controller: controller,
                  user: user,
                  streams: streams,
                ),
        );
      },
    );
  }
}

class _CctvTabEmptyState extends StatelessWidget {
  const _CctvTabEmptyState({required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_outlined, color: colors.mutedText, size: 46),
          const SizedBox(height: 14),
          const Text(
            'No CCTV stream connected',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan the local network or enter an RTSP URL to connect a camera.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.mutedText, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onManage,
            icon: const Icon(Icons.add_link_outlined),
            label: const Text('Add Camera'),
          ),
        ],
      ),
    );
  }
}

/// Fills the entire CCTV tab body with the connected live feed(s): one
/// camera fills the whole area, several share it in a grid — the same
/// layout used by [MultiCameraFullscreenPage], but with full YOLOv8
/// inspection and recording since this is the primary monitoring view.
class _CctvFullscreenFeed extends StatelessWidget {
  const _CctvFullscreenFeed({
    required this.controller,
    required this.user,
    required this.streams,
  });

  final AppController controller;
  final AppUser user;
  final List<LiveCctvStream> streams;

  @override
  Widget build(BuildContext context) {
    if (streams.length == 1) {
      return _CctvFeedTile(
        controller: controller,
        user: user,
        stream: streams[0],
        displayLabel: cctvStreamDisplayLabel(0, streams.length),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 16 / 9,
        ),
        itemCount: streams.length,
        itemBuilder: (context, index) => _CctvFeedTile(
          key: ValueKey(streams[index].id),
          controller: controller,
          user: user,
          stream: streams[index],
          displayLabel: cctvStreamDisplayLabel(index, streams.length),
        ),
      ),
    );
  }
}

class _CctvFeedTile extends StatelessWidget {
  const _CctvFeedTile({
    super.key,
    required this.controller,
    required this.user,
    required this.stream,
    required this.displayLabel,
  });

  final AppController controller;
  final AppUser user;
  final LiveCctvStream stream;
  final String displayLabel;

  @override
  Widget build(BuildContext context) {
    return LiveFeedCard(
      key: ValueKey(stream.id),
      expand: true,
      displayLabel: displayLabel,
      streamUrl: stream.streamUrl,
      recordingOwnerUsername: user.username,
      detections: stream.inspection.detections,
      onFrameCaptureStarted: () {
        controller.markCctvInspectionCapturing(user.username, stream.id);
      },
      onFrameReady: (frameBytes) {
        return controller.inspectCctvFrame(
          user.username,
          stream.id,
          frameBytes,
        );
      },
      onFrameCaptureFailed: (message) {
        controller.markCctvInspectionError(user.username, stream.id, message);
      },
    );
  }
}

class UserGuidelinesPage extends StatefulWidget {
  const UserGuidelinesPage({
    super.key,
    required this.controller,
    required this.session,
  });

  final AppController controller;
  final Session session;

  @override
  State<UserGuidelinesPage> createState() => _UserGuidelinesPageState();
}

class _UserGuidelinesPageState extends State<UserGuidelinesPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final colors = context.appColors;
        final query = _query.trim().toLowerCase();
        final guideItems = _guideGridItems
            .where((item) => query.isEmpty || item.matches(query))
            .toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Guidelines')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search guidelines...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 18),
              if (guideItems.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text('No guidelines found.', style: TextStyle(color: colors.mutedText)),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: .9,
                  ),
                  itemCount: guideItems.length,
                  itemBuilder: (context, index) => _GuideGridCard(item: guideItems[index]),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SystemBracketGuide {
  const _SystemBracketGuide({
    required this.title,
    required this.icon,
    required this.entries,
  });

  final String title;
  final IconData icon;
  final List<(String, String)> entries;
}

const _systemBracketGuides = [
  _SystemBracketGuide(
    title: 'Sensors',
    icon: Icons.sensors_outlined,
    entries: [
      (
        'Temperature',
        'Measures coop heat or cold. High readings can mean heat stress; low readings can mean cold stress.',
      ),
      (
        'Humidity',
        'Measures moisture in the air. High humidity makes it harder for chickens to cool down.',
      ),
      (
        'Air Pollution',
        'Measures unsafe air buildup, especially from waste. High ppm means the coop needs cleaning and ventilation.',
      ),
    ],
  ),
  _SystemBracketGuide(
    title: 'CCTV',
    icon: Icons.videocam_outlined,
    entries: [
      (
        'Camera model',
        'The camera model used by this app is V380 Pro. It provides the live CCTV feed that the app can monitor through a network stream.',
      ),
      (
        'V380 Pro setup',
        'Use the V380 Pro app or camera settings to connect the camera to Wi-Fi and enable RTSP/ONVIF when available. The app needs the camera IP address, stream path, and login details to preview the feed.',
      ),
      (
        'Online',
        'The V380 Pro camera feed is reachable and can be used for monitoring or YOLOv8 checking.',
      ),
      (
        'Offline',
        'The V380 Pro camera feed cannot be reached. Check power, Wi-Fi, RTSP link, and camera login details.',
      ),
      (
        'Blocked or blurry',
        'The app may miss chickens if the camera is covered, too dark, too far, or out of focus.',
      ),
    ],
  ),
  _SystemBracketGuide(
    title: 'YOLOv8 Detection',
    icon: Icons.center_focus_strong_outlined,
    entries: [
      (
        'What YOLOv8 does',
        'YOLOv8 is the computer vision model used by the app to inspect camera frames. It looks for chickens in the image and classifies the visible condition from what the model can see.',
      ),
      (
        'Frame-based result',
        'The result depends on the current frame quality. Lighting, blur, distance, camera angle, and blocked views can change what YOLOv8 detects.',
      ),
      (
        'No detection',
        'The model did not find a chicken in the frame. The bird may be hidden, blurred, or outside the view.',
      ),
      (
        'Normal detection',
        'The model found a chicken that appears to have acceptable posture and movement.',
      ),
      (
        'Abnormal detection',
        'The model found signs that need attention, such as unusual posture, weak balance, or repeated pacing.',
      ),
    ],
  ),
  _SystemBracketGuide(
    title: 'Chicken State',
    icon: Icons.health_and_safety_outlined,
    entries: [
      (
        'Posture-based state',
        'The chicken state mainly depends on visible posture and movement cues in the camera frame.',
      ),
      (
        'Normal',
        'The chicken posture appears balanced and natural, with no obvious abnormal pose or movement pattern.',
      ),
      (
        'Abnormal',
        'The chicken posture or movement appears unusual, such as weak balance, awkward stance, repeated pacing, or other visible abnormal behavior. Inspect it as soon as possible.',
      ),
    ],
  ),
];

List<_GuideGridItem> get _guideGridItems => [
  _GuideGridItem.system(_systemBracketGuides[0], 'Understand sensor readings and warnings.', Icons.shield_outlined, const Color(0xFFFF6B72)),
  _GuideGridItem.system(_systemBracketGuides[1], 'Camera setup and troubleshooting.', Icons.videocam_outlined, const Color(0xFFFF7A45)),
  _GuideGridItem.system(_systemBracketGuides[2], 'How detection works and confidence levels.', Icons.center_focus_strong_outlined, const Color(0xFFFF6B72)),
  _GuideGridItem.system(_systemBracketGuides[3], 'Posture and behavior explanations.', Icons.health_and_safety_outlined, const Color(0xFFFF6B72)),
  const _GuideGridItem.supplemental('Breeding Guide', 'How to breed healthy roosters.', Icons.egg_alt_outlined, Color(0xFF4A9FF5), [('Selecting a breeding rooster', 'Choose active, healthy birds with good balance and a calm temperament.'), ('Breeding setup', 'Keep breeding areas clean, spacious, and supplied with fresh water and feed.'), ('Egg care', 'Collect eggs regularly and keep them clean and protected before incubation.')]),
  const _GuideGridItem.supplemental('Care & Best Practices', 'Daily care tips for a healthy flock.', Icons.verified_user_outlined, Color(0xFF26C281), [('Daily check', 'Observe appetite, movement, droppings, and breathing every day.'), ('Clean living space', 'Remove waste, refresh bedding, and maintain dry, well-ventilated coops.'), ('Food and water', 'Provide balanced feed and clean water at all times.')]),
  const _GuideGridItem.supplemental('Diseases & Prevention', 'Common diseases and prevention.', Icons.health_and_safety_outlined, Color(0xFF9A62D8), [('Prevent spread', 'Separate birds showing signs of illness from the rest of the flock.'), ('Keep records', 'Track symptoms, treatments, and vaccinations for each flock.'), ('Ask a professional', 'Contact a veterinarian when symptoms are severe or persistent.')]),
];

class _GuideGridItem {
  const _GuideGridItem.system(this.systemGuide, this.description, this.icon, this.color) : title = null, entries = null;
  const _GuideGridItem.supplemental(this.title, this.description, this.icon, this.color, this.entries) : systemGuide = null;
  final _SystemBracketGuide? systemGuide;
  final String? title;
  final String description;
  final IconData icon;
  final Color color;
  final List<(String, String)>? entries;
  String get label => systemGuide?.title ?? title!;
  bool matches(String query) => label.toLowerCase().contains(query) || description.toLowerCase().contains(query);
}

class _GuideGridCard extends StatelessWidget {
  const _GuideGridCard({required this.item});
  final _GuideGridItem item;
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => item.label == 'Breeding Guide'
                ? const _BreedingGuidePage()
                : item.systemGuide != null
                ? _SystemBracketDetailPage(guide: item.systemGuide!)
                : _SupplementalGuidePage(item: item),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: item.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)), child: Icon(item.icon, color: item.color, size: 22)),
            const Spacer(),
            Text(item.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(item.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.mutedText, fontSize: 12, height: 1.35)),
          ]),
        ),
      ),
    );
  }
}

class _SupplementalGuidePage extends StatelessWidget {
  const _SupplementalGuidePage({required this.item});
  final _GuideGridItem item;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(item.label)), body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [Text(item.description, style: TextStyle(color: context.appColors.mutedText)), const SizedBox(height: 18), for (final (title, text) in item.entries!) _BracketEntryCard(label: title, explanation: text)]));
}

const _normalPostureGuides = [
  (
    'Standing Upright',
    'Rooster stands balanced on both legs with its head held high.',
  ),
  ('Walking Normally', 'Moves smoothly without limping or dragging its legs.'),
  (
    'Foraging/Scratching',
    'Scratches the ground while searching for food, showing natural behavior.',
  ),
  ('Eating', 'Pecking at feed with good appetite.'),
  ('Drinking Water', 'Drinks normally without difficulty.'),
  ('Alert Posture', 'Head raised, eyes open, aware of surroundings.'),
  (
    'Wing Stretching',
    'Briefly stretches one or both wings before returning to a relaxed posture.',
  ),
  ('Perching', 'Resting comfortably on a perch while maintaining balance.'),
  ('Preening', 'Cleaning feathers using its beak, a normal grooming behavior.'),
  (
    'Crowing',
    'Standing upright while crowing; common in healthy adult roosters.',
  ),
  ('Dust Bathing', 'Rolling or lying briefly in dry soil to clean feathers.'),
  (
    'Light Resting',
    'Sitting normally with head up and responding to nearby movement.',
  ),
];

const _abnormalPostureGuides = [
  ('Lying Flat on the Ground', 'Severe weakness or illness.'),
  ('Head Drooping', 'Fatigue, dehydration, or sickness.'),
  ('One-Wing Drooping', 'Wing injury or muscle weakness.'),
  ('Both Wings Hanging Down', 'Heat stress or serious illness.'),
  ('Unable to Stand', 'Leg injury or severe disease.'),
  ('Limping While Walking', 'Foot or leg injury.'),
  ('Twisted Neck', 'Possible neurological disorder or injury.'),
  ('Constant Sitting', 'Weakness or lack of energy.'),
  ('Panting with Open Beak', 'Heat stress or respiratory problem.'),
  ('Loss of Balance', 'Possible neurological problem or injury.'),
  ('Dragging One Leg', 'Injury or nerve damage.'),
  ('Isolating from Other Birds', 'Illness or stress.'),
  ('Collapsed Posture', 'Emergency condition requiring immediate attention.'),
  (
    'Head Tucked Under Wing for Long Periods',
    'Weakness or illness (outside normal sleeping).',
  ),
  ('Shaking or Trembling', 'Stress, fever, or neurological issues.'),
];

class _ChickenStateGuidePage extends StatelessWidget {
  const _ChickenStateGuidePage();

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).useMaterial3) return const _FunctionalChickenStateGuide();
    return Scaffold(
    appBar: AppBar(title: const Text('Chicken State')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: const [
        _GuideModeTabs(),
        SizedBox(height: 14),
        _ChickenStateCard(
          title: 'Normal (Healthy)',
          description: 'Roosters appear alert, balanced, and active with natural posture.',
          color: Color(0xFF26C281),
          cues: ['Standing upright', 'Walking normally', 'Foraging / scratching'],
        ),
        SizedBox(height: 12),
        _ChickenStateCard(
          title: 'Abnormal (Needs Attention)',
          description: 'Roosters show signs of discomfort, illness, or stress.',
          color: Color(0xFFFF4F3A),
          cues: ['Weak balance', 'Abnormal stance', 'Repeated pacing'],
          note: 'Inspect as soon as possible and provide proper care.',
        ),
      ],
    ),
    );
  }
}

class _GuideModeTabs extends StatelessWidget {
  const _GuideModeTabs();
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Container(alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 11), decoration: BoxDecoration(color: const Color(0xFFFFEEE9), borderRadius: BorderRadius.circular(22)), child: const Text('Posture-based State', style: TextStyle(color: _appAccent, fontWeight: FontWeight.w800, fontSize: 12)))),
    const SizedBox(width: 9),
    Expanded(child: Container(alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 11), decoration: BoxDecoration(color: const Color(0xFFFFF9F6), borderRadius: BorderRadius.circular(22)), child: const Text('Movement Cues', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)))),
  ]);
}

class _ChickenStateCard extends StatelessWidget {
  const _ChickenStateCard({required this.title, required this.description, required this.color, required this.cues, this.note});
  final String title;
  final String description;
  final Color color;
  final List<String> cues;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: colors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(width: 11, height: 11, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 9), Text(title, style: const TextStyle(fontWeight: FontWeight.w900))]),
        const SizedBox(height: 10),
        Text(description, style: TextStyle(color: colors.mutedText, height: 1.45)),
        const SizedBox(height: 15),
        for (final cue in cues) Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Icon(color == const Color(0xFF26C281) ? Icons.check_box_rounded : Icons.cancel_rounded, color: color, size: 20), const SizedBox(width: 10), Text(cue)])),
        if (note != null) ...[const SizedBox(height: 4), Text(note!, style: TextStyle(color: colors.mutedText, height: 1.45))],
      ]),
    );
  }
}

class _FunctionalChickenStateGuide extends StatefulWidget {
  const _FunctionalChickenStateGuide();
  @override
  State<_FunctionalChickenStateGuide> createState() => _FunctionalChickenStateGuideState();
}

class _FunctionalChickenStateGuideState extends State<_FunctionalChickenStateGuide> {
  bool _movementCues = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final normal = _movementCues
        ? const ['Active walking', 'Smooth, even steps', 'Regular foraging']
        : const ['Standing upright', 'Walking normally', 'Foraging / scratching'];
    final abnormal = _movementCues
        ? const ['Limping or dragging', 'Loss of balance', 'Repeated pacing']
        : const ['Weak balance', 'Abnormal stance', 'Repeated pacing'];
    return Scaffold(
      appBar: AppBar(title: const Text('Chicken State')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Row(children: [
            _StateTab(label: 'Posture-based State', selected: !_movementCues, onTap: () => setState(() => _movementCues = false)),
            const SizedBox(width: 9),
            _StateTab(label: 'Movement Cues', selected: _movementCues, onTap: () => setState(() => _movementCues = true)),
          ]),
          const SizedBox(height: 14),
          _FunctionalStateCard(title: 'Normal (Healthy)', description: _movementCues ? 'Healthy roosters move with purpose and stay engaged with their surroundings.' : 'Roosters appear alert, balanced, and active with natural posture.', color: const Color(0xFF26C281), cues: normal, imageAsset: 'assets/chickens/healthy_rooster.png'),
          const SizedBox(height: 12),
          _FunctionalStateCard(title: 'Abnormal (Needs Attention)', description: _movementCues ? 'Unusual movement can point to injury, illness, pain, or stress.' : 'Roosters show signs of discomfort, illness, or stress.', color: const Color(0xFFFF4F3A), cues: abnormal, note: 'Inspect as soon as possible and provide proper care.', imageAsset: 'assets/chickens/abnormal_rooster.png'),
          const SizedBox(height: 14),
          Text(_movementCues ? 'Watch a rooster over several moments before deciding a movement is abnormal.' : 'Posture is most useful when the full body is visible and the camera view is clear.', style: TextStyle(color: colors.mutedText, fontSize: 12, height: 1.45)),
        ],
      ),
    );
  }
}

class _StateTab extends StatelessWidget {
  const _StateTab({required this.label, required this.selected, required this.onTap});
  final String label; final bool selected; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Expanded(child: Material(color: selected ? _appAccent.withValues(alpha: .13) : colors.surfaceRaised, borderRadius: BorderRadius.circular(22), child: InkWell(borderRadius: BorderRadius.circular(22), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 11), child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: selected ? _appAccent : colors.mutedText, fontWeight: FontWeight.w800, fontSize: 12))))));
  }
}

class _FunctionalStateCard extends StatelessWidget {
  const _FunctionalStateCard({required this.title, required this.description, required this.color, required this.cues, this.note, this.imageAsset});
  final String title; final String description; final Color color; final List<String> cues; final String? note; final String? imageAsset;
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final showImage = imageAsset != null && Theme.of(context).brightness == Brightness.light;
    final content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 11, height: 11, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 9), Expanded(child: Text(title, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.text, fontWeight: FontWeight.w900)))]), const SizedBox(height: 10), Text(description, style: TextStyle(color: colors.mutedText, height: 1.45)), const SizedBox(height: 15), for (final cue in cues) Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Icon(color == const Color(0xFF26C281) ? Icons.check_box_rounded : Icons.cancel_rounded, color: color, size: 20), const SizedBox(width: 10), Expanded(child: Text(cue, style: TextStyle(color: colors.text)))])), if (note != null) Text(note!, style: TextStyle(color: colors.mutedText, height: 1.45))]);
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: colors.border)), child: Stack(children: [Padding(padding: EdgeInsets.only(right: showImage ? 116 : 0), child: content), if (showImage) Positioned(right: -20, bottom: 0, child: SizedBox(width: 144, height: 138, child: Image.asset(imageAsset!, fit: BoxFit.contain)))]));
  }
}

class _BreedingGuidePage extends StatelessWidget {
  const _BreedingGuidePage();
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const topics = [
      ('Selecting a Breeding Rooster', Icons.person_outline),
      ('Selecting Hens', Icons.group_outlined),
      ('Breeder Nutrition & Conditioning', Icons.restaurant_outlined),
      ('Breeding Setup', Icons.home_outlined),
      ('Mating Process', Icons.favorite_border),
      ('Egg Collection & Incubation', Icons.egg_alt_outlined),
      ('Hatching & Chick Care', Icons.egg_alt_outlined),
      ('Common Breeding Mistakes to Avoid', Icons.rule_outlined),
      ('Breeding Tips & Reminders', Icons.lightbulb_outline),
    ];
    return Scaffold(appBar: AppBar(title: const Text('Breeding Guide')), body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [Text('A complete walkthrough of breeding healthy, strong roosters: choosing parent stock, preparing a proper setup, and caring for eggs and chicks all the way to a healthy hatch.', style: TextStyle(color: colors.mutedText, height: 1.5)), const SizedBox(height: 18), Container(decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)), child: Column(children: [for (final (title, icon) in topics) _BreedingTopicRow(title: title, icon: icon)])), const SizedBox(height: 18), Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFFFF4E7), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFDFB8))), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.lightbulb_outline, color: Color(0xFFF0A22A), size: 27), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Tip', style: TextStyle(fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('Good breeding starts with healthy parents, a clean setup, and proper care from egg to chick.')]))]))]));
  }
}

class _BreedingTopicRow extends StatelessWidget {
  const _BreedingTopicRow({required this.title, required this.icon});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: ListTile(
      leading: Icon(icon, color: context.appColors.mutedText),
      title: Text(title, style: TextStyle(color: context.appColors.text, fontWeight: FontWeight.w700)),
      trailing: Icon(Icons.chevron_right_rounded, color: context.appColors.mutedText),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _BreedingTopicPage(topic: title, icon: icon))),
    ),
  );
}

class _BreedingTopicPage extends StatelessWidget {
  const _BreedingTopicPage({required this.topic, required this.icon});
  final String topic; final IconData icon;
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final details = _breedingTopicDetails[topic] ?? const ['Keep birds healthy, comfortable, and under regular observation.', 'Use clean housing, balanced feed, fresh water, and appropriate space.', 'Ask a poultry professional for help with illness or persistent breeding issues.'];
    return Scaffold(appBar: AppBar(title: Text(topic)), body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [Container(width: 50, height: 50, decoration: BoxDecoration(color: _appAccent.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: _appAccent)), const SizedBox(height: 16), Text('Practical guidance', style: TextStyle(color: colors.text, fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 10), for (var index = 0; index < details.length; index++) _BracketEntryCard(label: 'Step ${index + 1}', explanation: details[index]) ]));
  }
}

const _breedingTopicDetails = <String, List<String>>{
  'Selecting a Breeding Rooster': [
    'Choose an alert, active rooster with bright eyes, sound legs, and a natural, balanced stance.',
    'Avoid birds with persistent limping, breathing issues, or any visible illness.',
    'Pick a rooster whose traits (size, color, temperament) you want to carry into the next generation.',
    'Favor roosters that are at least 7-8 months old so they are fully mature before breeding.',
    'Rotate or rest a rooster that is overused to keep fertility and mating quality high.',
  ],
  'Selecting Hens': [
    'Choose healthy hens with a good appetite, normal movement, and clean, well-kept feathers.',
    'Avoid breeding hens that are weak, underweight, or recovering from illness.',
    'Keep the breeding group calm and avoid overcrowding, which raises stress and injury risk.',
    'Prefer hens already laying consistently, since irregular layers often produce fewer viable eggs.',
    'Match hen age and size to the rooster to reduce injury during mating.',
  ],
  'Breeder Nutrition & Conditioning': [
    'Feed a balanced breeder ration with higher protein and added vitamins A, D, and E for fertility.',
    'Provide calcium (oyster shell or limestone grit) so hens keep strong eggshells during heavy laying.',
    'Keep breeders at a healthy weight; both underweight and overweight birds have lower fertility.',
    'Offer fresh, clean water at all times, since dehydration quickly reduces egg and sperm quality.',
    'Start conditioning 2-3 weeks before breeding season so both rooster and hens are in peak health.',
  ],
  'Breeding Setup': [
    'Provide a clean, dry pen with shade, ventilation, nesting areas, and fresh water.',
    'Keep litter dry and remove waste often to reduce ammonia and disease risk.',
    'Give birds enough room to move away from each other and avoid constant close contact.',
    'Add one nesting box for every 4-5 hens to reduce crowding and egg damage.',
    'Separate breeding pens from the general flock to control which birds mate and avoid stress.',
  ],
  'Mating Process': [
    'Introduce breeding birds gradually and watch for aggression during the first few days.',
    'Observe the flock daily to ensure hens are not being over-mated or injured.',
    'Keep food and water available in more than one spot when possible to reduce competition.',
    'Pair one rooster with 8-10 hens as a general guide for balanced mating and fertility.',
    'Trim sharp spurs or claws if they are causing injuries to hens during mating.',
  ],
  'Egg Collection & Incubation': [
    'Collect eggs at least once daily and discard cracked, misshapen, or heavily soiled eggs.',
    'Store suitable eggs point-down in a cool, clean place before incubation, ideally within 7 days.',
    'Follow stable temperature, humidity, and turning guidance for the incubator (typically ~37.5°C).',
    'Turn eggs 3-5 times a day if not using an automatic turner, stopping a few days before hatch.',
    'Candle eggs around day 7-10 to check development and remove clearly infertile ones.',
  ],
  'Hatching & Chick Care': [
    'Prepare a warm, dry brooder before chicks hatch, with a heat source and non-slip flooring.',
    'Give chicks clean water, starter feed, and a safe, consistent heat source (around 32-35°C at first).',
    'Watch for piling, chilling, weakness, or poor eating, which often signal temperature or health issues.',
    'Let chicks fully dry and fluff up in the incubator before moving them to the brooder.',
    'Gradually lower brooder temperature by about 3°C per week as chicks feather out.',
  ],
  'Common Breeding Mistakes to Avoid': [
    'Breeding birds that are sick, stressed, injured, or under treatment, which lowers fertility and chick health.',
    'Overusing one rooster across too many hens, leading to fatigue and reduced fertility.',
    'Breeding closely related birds repeatedly, which can weaken the flock over generations.',
    'Skipping quarantine for new breeding stock before introducing them to the flock.',
    'Rushing the incubation or brooder setup instead of confirming stable temperature and humidity first.',
  ],
  'Breeding Tips & Reminders': [
    'Keep records of parent birds, hatch dates, health issues, and results to guide future pairings.',
    'Do not breed birds while they are sick, stressed, or under treatment.',
    'Prioritize bird health and welfare over rapid breeding results.',
    'Introduce new bloodlines occasionally to keep the flock genetically healthy.',
    'Review past hatch outcomes each season and adjust nutrition, setup, or pairings as needed.',
  ],
};

class _SensorsGuidePage extends StatelessWidget {
  const _SensorsGuidePage();
  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).useMaterial3) return const _FunctionalSensorsGuide();
    final colors = context.appColors;
    return Scaffold(appBar: AppBar(title: const Text('Sensors')), body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [Text('Environmental sensor explanations and safe levels.', style: TextStyle(color: colors.mutedText, height: 1.5)), const SizedBox(height: 18), _SensorRangeCard(title: 'Temperature (°C)', icon: Icons.thermostat_outlined, color: const Color(0xFFFF6B55), ranges: const [('OK\nNORMAL', '18 - 27 °C', 'Comfortable for roosters.', Color(0xFF26C281)), ('!\nCAUTION', '27 - 30 °C', 'Start prevention.', Color(0xFFE5A52C)), ('!\nDANGER', '> 30 °C', 'Strong cooling needed.', Color(0xFFFF4F3A))]), const SizedBox(height: 10), _SensorCollapsedRow(title: 'Humidity (%)', icon: Icons.water_drop_outlined, color: const Color(0xFF3BB7E8)), const SizedBox(height: 8), _SensorCollapsedRow(title: 'Air Pollution (ppm)', icon: Icons.air_outlined, color: const Color(0xFF4A9FF5)), const SizedBox(height: 18), Text('Tap any sensor to learn more about readings and recommendations.', style: TextStyle(color: colors.mutedText, fontSize: 12, height: 1.45))]));
  }
}

class _SensorRangeCard extends StatelessWidget {
  const _SensorRangeCard({required this.title, required this.icon, required this.color, required this.ranges});
  final String title; final IconData icon; final Color color; final List<(String, String, String, Color)> ranges;
  @override
  Widget build(BuildContext context) { final colors = context.appColors; return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: colors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: color), const SizedBox(width: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.w900))]), const SizedBox(height: 13), for (final (level, range, note, levelColor) in ranges) Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Container(width: 68, padding: const EdgeInsets.symmetric(vertical: 7), alignment: Alignment.center, decoration: BoxDecoration(color: levelColor.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)), child: Text(level, textAlign: TextAlign.center, style: TextStyle(color: levelColor, fontSize: 10, fontWeight: FontWeight.w900))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(range, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(note, style: TextStyle(color: colors.mutedText, fontSize: 12))]))]))])); }
}

class _SensorCollapsedRow extends StatelessWidget {
  const _SensorCollapsedRow({required this.title, required this.icon, required this.color}); final String title; final IconData icon; final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15), decoration: BoxDecoration(color: context.appColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.appColors.border)), child: Row(children: [Icon(icon, color: color), const SizedBox(width: 12), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))), Icon(Icons.keyboard_arrow_down_rounded, color: context.appColors.mutedText)]));
}

class _FunctionalSensorsGuide extends StatelessWidget {
  const _FunctionalSensorsGuide();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(title: const Text('Sensors')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('Environmental sensor explanations, safe levels, and recommended actions.', style: TextStyle(color: colors.mutedText, height: 1.5)),
          const SizedBox(height: 18),
          const _FunctionalSensorGuideCard(title: 'Temperature (°C)', icon: Icons.thermostat_outlined, color: Color(0xFFFF6B55), summary: 'Comfort, heat-stress, and emergency temperature ranges.', ranges: [('Normal', '18 - 26 °C', 'Good / comfortable'), ('Caution', '27 - 29 °C', 'Shade, water, and airflow'), ('Warning', '30 - 31 °C', 'Heat stress likely'), ('Danger', '32 °C+', 'Strong cooling needed')]),
          const SizedBox(height: 10),
          const _FunctionalSensorGuideCard(title: 'Humidity (%)', icon: Icons.water_drop_outlined, color: Color(0xFF3BB7E8), summary: 'Relative humidity levels that affect cooling and dust.', ranges: [('Normal', '45 - 70%', 'Good range'), ('Caution', '71 - 79%', 'Improve ventilation'), ('Warning', '80 - 89%', 'Risky, especially in heat'), ('Danger', '90%+', 'Very poor cooling condition')]),
          const SizedBox(height: 10),
          const _FunctionalSensorGuideCard(title: 'Air Pollution (ppm)', icon: Icons.air_outlined, color: Color(0xFF4A9FF5), summary: 'Ammonia air-quality limits for the poultry area.', ranges: [('Normal', '0 - 9 ppm', 'Good air'), ('Caution', '10 - 19 ppm', 'Improve ventilation'), ('Warning', '20 - 24 ppm', 'Air quality becoming unsafe'), ('Danger', '25+ ppm', 'Ventilate and clean immediately')]),
          const SizedBox(height: 18),
          Text('Tap a sensor to expand its reference chart and the action for each level.', style: TextStyle(color: colors.mutedText, fontSize: 12, height: 1.45)),
        ],
      ),
    );
  }
}

class _FunctionalSensorGuideCard extends StatelessWidget {
  const _FunctionalSensorGuideCard({required this.title, required this.icon, required this.color, required this.summary, required this.ranges});
  final String title; final IconData icon; final Color color; final String summary; final List<(String, String, String)> ranges;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: colors.border)),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.all(15),
            childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.mutedText, fontSize: 12, height: 1.35)),
            children: [
              for (final (level, range, action) in ranges)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.border)),
                  child: Row(children: [
                    Container(width: 68, padding: const EdgeInsets.symmetric(vertical: 6), alignment: Alignment.center, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)), child: Text(level, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(range, style: TextStyle(color: colors.text, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(action, style: TextStyle(color: colors.mutedText, fontSize: 12))])),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full page for one System Bracket so longer advice remains easy to read
/// and users can return to the Guide index with the standard back button.
class _SystemBracketDetailPage extends StatelessWidget {
  const _SystemBracketDetailPage({required this.guide});

  final _SystemBracketGuide guide;

  @override
  Widget build(BuildContext context) {
    if (guide.title == 'Chicken State') return const _ChickenStateGuidePage();
    if (guide.title == 'Sensors') return const _SensorsGuidePage();
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(title: Text(guide.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.accentSurface,
                foregroundColor: _appAccent,
                child: Icon(guide.icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  guide.title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final (label, explanation) in guide.entries)
            _BracketEntryCard(label: label, explanation: explanation),
          if (guide.title == 'Sensors') ...[
            const SizedBox(height: 8),
            const Text('Sensor Warning Explanations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Warning levels explain when a reading needs closer monitoring or action.', style: TextStyle(color: colors.mutedText, height: 1.45)),
            const SizedBox(height: 12),
            for (final warningGuide in _sensorWarningGuides)
              _SensorWarningGuideCard(guide: warningGuide),
          ],
          if (guide.title == 'Chicken State') ...[
            const SizedBox(height: 8),
            const _PostureGuideSection(
              title: 'Normal Postures (Healthy)',
              description: 'These postures indicate that the rooster appears healthy and behaves normally.',
              color: Color(0xFF26C281),
              entries: _normalPostureGuides,
            ),
            const SizedBox(height: 16),
            const _PostureGuideSection(
              title: 'Abnormal Postures (Possible Health Problems)',
              description: 'These postures may indicate illness, injury, weakness, or stress.',
              color: Color(0xFFFF6B72),
              entries: _abnormalPostureGuides,
            ),
          ],
        ],
      ),
    );
  }
}

class _BracketEntryCard extends StatelessWidget {
  const _BracketEntryCard({required this.label, required this.explanation});

  final String label;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(explanation, style: TextStyle(color: colors.mutedText, height: 1.45)),
        ],
      ),
    );
  }
}

class _PostureGuideSection extends StatelessWidget {
  const _PostureGuideSection({
    required this.title,
    required this.description,
    required this.color,
    required this.entries,
  });

  final String title;
  final String description;
  final Color color;
  final List<(String, String)> entries;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)))]),
        const SizedBox(height: 6),
        Text(description, style: TextStyle(color: colors.mutedText, height: 1.45)),
        const SizedBox(height: 10),
        for (final (posture, meaning) in entries)
          _PostureGuideRow(posture: posture, meaning: meaning, color: color),
      ],
    );
  }
}

class _SensorWarningGuide {
  const _SensorWarningGuide({
    required this.title,
    required this.icon,
    required this.entries,
  });

  final String title;
  final IconData icon;
  final List<(SensorWarningLevel, String, String)> entries;
}

const _sensorWarningGuides = [
  _SensorWarningGuide(
    title: 'Temperature (°C)',
    icon: Icons.thermostat_outlined,
    entries: [
      (
        SensorWarningLevel.normal,
        '18 - 27 °C',
        'Comfortable range for roosters.',
      ),
      (
        SensorWarningLevel.caution,
        '27 - 30 °C or 10 - 18 °C',
        'Start prevention: shade, fresh water, and airflow when warm; add safe warmth when cool.',
      ),
      (
        SensorWarningLevel.warning,
        '30 - 32 °C',
        'Heat stress is likely, especially when humid. Cool the pen and watch the birds.',
      ),
      (
        SensorWarningLevel.danger,
        '32 - 35 °C or 5 - 10 °C',
        'Dangerous heat needs strong cooling now; cold this low risks cold stress, so warm the area.',
      ),
      (
        SensorWarningLevel.critical,
        'Above 35 °C or below 5 °C',
        'Emergency condition. Act immediately to cool or warm the coop and check every bird.',
      ),
    ],
  ),
  _SensorWarningGuide(
    title: 'Humidity (%)',
    icon: Icons.water_drop_outlined,
    entries: [
      (
        SensorWarningLevel.normal,
        '45 - 71%',
        'Good range for comfort and dust control.',
      ),
      (
        SensorWarningLevel.caution,
        '71 - 80% or below 45%',
        'Watch closely and improve ventilation; very dry air raises dust risk.',
      ),
      (
        SensorWarningLevel.warning,
        '80 - 90%',
        'Risky, especially in heat. Improve airflow so the birds can cool themselves.',
      ),
      (
        SensorWarningLevel.danger,
        'Above 90%, or above 80% with 30 °C+ heat',
        'Cooling barely works in this humidity. Ventilate aggressively and cool the pen.',
      ),
    ],
  ),
  _SensorWarningGuide(
    title: 'Air Pollution (ppm)',
    icon: Icons.air_outlined,
    entries: [
      (SensorWarningLevel.normal, 'Below 10 ppm', 'Good air.'),
      (
        SensorWarningLevel.caution,
        '10 - 20 ppm',
        'Improve ventilation and check litter or manure buildup.',
      ),
      (
        SensorWarningLevel.warning,
        '20 - 25 ppm',
        'Air quality is becoming unsafe; clean and ventilate soon.',
      ),
      (
        SensorWarningLevel.danger,
        '25 - 50 ppm',
        'Ventilate and clean immediately; ammonia at this level harms the flock.',
      ),
      (
        SensorWarningLevel.critical,
        'Above 50 ppm',
        'Emergency. Remove the birds from the coop if possible while it airs out.',
      ),
    ],
  ),
];

class _SensorWarningGuideCard extends StatelessWidget {
  const _SensorWarningGuideCard({required this.guide});

  final _SensorWarningGuide guide;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(guide.icon, color: _appAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  guide.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (level, range, advice) in guide.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SensorLevelTag(level: level, compact: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          range,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          advice,
                          style: TextStyle(
                            color: colors.mutedText,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PostureGuideRow extends StatelessWidget {
  const _PostureGuideRow({
    required this.posture,
    required this.meaning,
    required this.color,
  });

  final String posture;
  final String meaning;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  posture,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meaning,
                  style: TextStyle(
                    color: colors.mutedText,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({
    super.key,
    required this.controller,
    required this.session,
  });

  final AppController controller;
  final Session session;

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final colors = context.appColors;
        final thread = widget.controller.threadForUser(
          widget.session.user.username,
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Chat Admin')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _GlassCard(
                  child: Text(
                    'Use this chatbox when you experience a bug, device problem, or app issue. You can also coordinate a troubleshooting or repair schedule here.',
                    style: TextStyle(color: colors.mutedText, height: 1.5),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  children: [
                    if (thread == null)
                      const EmptyCard(
                        title: 'No conversation yet',
                        subtitle:
                            'Send the first message to report a problem or request support scheduling.',
                      )
                    else
                      ...thread.messages.map(
                        (message) => ChatBubble(
                          message: message,
                          mine: message.senderRole == UserRole.user,
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (
                        var i = 0;
                        i < _supportIssueCategories.length;
                        i++
                      ) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _SupportCategoryButton(
                          category: _supportIssueCategories[i],
                          onMessageSelected: (message) {
                            widget.controller.sendUserSupportMessage(
                              username: widget.session.user.username,
                              text: message,
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              minLines: 1,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText:
                                    'Describe the bug or arrange support time',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _appAccent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: () {
                              widget.controller.sendUserSupportMessage(
                                username: widget.session.user.username,
                                text: _messageController.text,
                              );
                              _messageController.clear();
                            },
                            child: const Text('Send'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SupportIssueCategory {
  const _SupportIssueCategory({
    required this.label,
    required this.icon,
    required this.messages,
  });

  final String label;
  final IconData icon;
  final List<String> messages;
}

const _supportIssueCategories = <_SupportIssueCategory>[
  _SupportIssueCategory(
    label: 'Camera Issues',
    icon: Icons.videocam_outlined,
    messages: [
      "The camera won't connect.",
      'The RTSP stream keeps disconnecting.',
      "Scan Cameras isn't finding my camera.",
      'The live feed is blurry or frozen.',
      "The recording won't start or save.",
    ],
  ),
  _SupportIssueCategory(
    label: 'ESP32 Sensor Issues',
    icon: Icons.sensors_outlined,
    messages: [
      "The ESP32 sensor won't connect.",
      'Sensor readings look wrong or frozen.',
      'The sensor keeps disconnecting.',
    ],
  ),
  _SupportIssueCategory(
    label: 'Other Issues',
    icon: Icons.more_horiz_outlined,
    messages: [
      'I encountered a bug.',
      'I have a general question.',
      "I'd like to schedule a troubleshooting or repair visit.",
    ],
  ),
];

class _SupportCategoryButton extends StatelessWidget {
  const _SupportCategoryButton({
    required this.category,
    required this.onMessageSelected,
  });

  final _SupportIssueCategory category;
  final ValueChanged<String> onMessageSelected;

  void _showCategorySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = sheetContext.appColors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(category.icon, color: _appAccent),
                    const SizedBox(width: 10),
                    Text(
                      category.label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap a message to send it to the admin.',
                  style: TextStyle(color: colors.mutedText),
                ),
                const SizedBox(height: 8),
                for (final message in category.messages)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(message),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onMessageSelected(message);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showCategorySheet(context),
      icon: Icon(category.icon),
      label: Text(category.label),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.controller,
    required this.session,
  });

  final AppController controller;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final user = controller.userByUsername(session.user.username)!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'App settings',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (context) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: ThemePreferenceCard(controller: controller),
              ),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _ProfileSummaryCard(user: user, session: session),
          const SizedBox(height: 14),
          _ProfileMenuGroup(children: [
            _ProfileMenuRow(
              icon: Icons.person_outline,
              label: 'My Information',
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProfileEditPage(controller: controller, user: user))),
            ),
            _ProfileMenuRow(
              icon: Icons.key_outlined,
              label: 'Username & Password',
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CredentialsEditPage(controller: controller, user: user))),
            ),
            _ProfileMenuRow(
              icon: Icons.account_circle_outlined,
              label: 'Connected Accounts',
              trailing: const Icon(Icons.g_mobiledata_rounded, color: Color(0xFF4285F4), size: 30),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ConnectedAccountsPage(controller: controller))),
            ),
            _ProfileMenuRow(
              icon: Icons.video_library_outlined,
              label: user.isAdmin ? 'All Recordings' : 'My Recordings',
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RecordingsPage(currentUser: user))),
            ),
            _ProfileMenuRow(
              icon: Icons.notifications_none_rounded,
              label: 'Notification Preferences',
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationPreferencesPage())),
            ),
            _ProfileMenuRow(
              icon: Icons.settings_outlined,
              label: 'App Settings',
              onTap: () => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (context) => Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), child: ThemePreferenceCard(controller: controller))),
            ),
            _ProfileMenuRow(
              icon: Icons.help_outline_rounded,
              label: 'Help & Support',
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SupportChatPage(controller: controller, session: session))),
            ),
          ]),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await controller.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => LandingPage(controller: controller)), (route) => false);
            },
            icon: const Icon(Icons.logout_outlined),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

class ConnectedAccountsPage extends StatelessWidget {
  const ConnectedAccountsPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final session = controller.session;
        final connected = session?.email != null;
        final colors = context.appColors;
        return Scaffold(
          appBar: AppBar(title: const Text('Connected Accounts')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Text('Connect your Google account for faster login and cloud backup.', style: TextStyle(color: colors.mutedText, height: 1.5)),
              const SizedBox(height: 22),
              _ConnectedAccountCard(
                connected: connected,
                email: session?.email,
                onTap: () async {
                  if (connected) {
                    await controller.unlinkGoogleAccount();
                    return;
                  }
                  final linked = await controller.linkGoogleAccount();
                  if (!context.mounted || linked) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.lastError ?? 'Could not connect Google.')));
                },
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: colors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Benefits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 14),
                    const _AccountBenefit(text: 'Quick and secure login'),
                    const _AccountBenefit(text: 'Backup your recordings and settings'),
                    const _AccountBenefit(text: 'Sync across multiple devices'),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text('You can connect or disconnect Google anytime in Profile settings.', style: TextStyle(color: colors.mutedText, height: 1.45)),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectedAccountCard extends StatelessWidget {
  const _ConnectedAccountCard({required this.connected, required this.email, required this.onTap});

  final bool connected;
  final String? email;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
          child: Row(
            children: [
              const Icon(Icons.g_mobiledata_rounded, color: Color(0xFF4285F4), size: 38),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(connected ? 'Google connected' : 'Connect with Google', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), if (connected) ...[const SizedBox(height: 3), Text(email!, style: TextStyle(color: colors.mutedText, fontSize: 12))]])),
              if (connected) const Icon(Icons.check_circle, color: Color(0xFF26C281)) else Icon(Icons.chevron_right_rounded, color: colors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountBenefit extends StatelessWidget {
  const _AccountBenefit({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [const Icon(Icons.diamond, size: 13), const SizedBox(width: 11), Text(text)]));
}

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});
  @override
  State<NotificationPreferencesPage> createState() => _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends State<NotificationPreferencesPage> {
  static const _prefix = 'roostify.notification.';
  bool _enabled = true;
  final Map<String, bool> _preferences = {for (final item in _notificationOptions) item.key: true};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _enabled = prefs.getBool('${_prefix}enabled') ?? true;
      for (final item in _notificationOptions) {
        _preferences[item.key] = prefs.getBool('$_prefix${item.key}') ?? true;
      }
    });
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _enabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_prefix}enabled', value);
  }

  Future<void> _setPreference(String key, bool value) async {
    setState(() => _preferences[key] = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$key', value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
            child: SwitchListTile(title: const Text('Enable Notifications', style: TextStyle(fontWeight: FontWeight.w800)), value: _enabled, activeThumbColor: const Color(0xFF26C281), onChanged: _setEnabled),
          ),
          const SizedBox(height: 26),
          const Text('Notify me about', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
            child: Column(children: [for (final item in _notificationOptions) _NotificationOptionRow(option: item, value: _preferences[item.key]!, enabled: _enabled, onChanged: (value) => _setPreference(item.key, value))]),
          ),
        ],
      ),
    );
  }
}

class _NotificationOption {
  const _NotificationOption(this.key, this.label, this.icon, this.color);
  final String key;
  final String label;
  final IconData icon;
  final Color color;
}

const _notificationOptions = [
  _NotificationOption('high_temperature', 'High Temperature', Icons.thermostat_outlined, Color(0xFFFF6B55)),
  _NotificationOption('high_humidity', 'High Humidity', Icons.water_drop_outlined, Color(0xFF3BB7E8)),
  _NotificationOption('air_pollution', 'Air Pollution Warning', Icons.air_outlined, Color(0xFFE5A52C)),
  _NotificationOption('abnormal_behavior', 'Abnormal Behavior', Icons.close_rounded, Color(0xFFFF6B72)),
  _NotificationOption('camera_offline', 'Camera Offline', Icons.videocam_off_outlined, Color(0xFFFF6B72)),
  _NotificationOption('chick_alerts', 'Chick Alerts', Icons.egg_alt_outlined, Color(0xFFE79B47)),
  _NotificationOption('system_updates', 'System Updates', Icons.settings_suggest_outlined, Color(0xFF7B8799)),
];

class _NotificationOptionRow extends StatelessWidget {
  const _NotificationOptionRow({required this.option, required this.value, required this.enabled, required this.onChanged});
  final _NotificationOption option;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border.withValues(alpha: .7)))),
      child: SwitchListTile(
        secondary: Container(width: 34, height: 34, decoration: BoxDecoration(color: option.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)), child: Icon(option.icon, color: option.color, size: 19)),
        title: Text(option.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        value: value,
        activeThumbColor: const Color(0xFF26C281),
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.user, required this.session});

  final AppUser user;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _appAccent.withValues(alpha: .35), width: 2),
                ),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: colors.accentSurface,
                  backgroundImage: session.photoUrl == null ? null : NetworkImage(session.photoUrl!),
                  child: session.photoUrl == null ? Icon(user.isAdmin ? Icons.admin_panel_settings_outlined : Icons.person_outline, color: _appAccent, size: 32) : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(session.email ?? '@${user.username}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.mutedText, fontSize: 12)),
                    const SizedBox(height: 3),
                    Text(user.isAdmin ? 'Admin supervisor account' : 'Backyard rooster farm user', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.subtleText, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _ProfileStat(value: user.isAdmin ? 'Admin' : 'User', label: 'Role')),
                VerticalDivider(color: colors.border, width: 1),
                Expanded(child: _ProfileStat(value: '${user.cctvs.length}', label: 'CCTVs')),
                VerticalDivider(color: colors.border, width: 1),
                Expanded(child: _ProfileStat(value: '${user.monitor.alerts.length}', label: 'Alerts')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuGroup extends StatelessWidget {
  const _ProfileMenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({required this.icon, required this.label, this.onTap, this.trailing});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 55),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border.withValues(alpha: .75)))),
          child: Row(
            children: [
              Icon(icon, color: colors.mutedText, size: 22),
              const SizedBox(width: 18),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              if (trailing != null) trailing! else Icon(Icons.chevron_right_rounded, color: colors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({
    super.key,
    required this.controller,
    required this.user,
  });

  final AppController controller;
  final AppUser user;

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.user.displayName,
  );
  late final TextEditingController _contactController = TextEditingController(
    text: widget.user.contactNumber,
  );
  late final TextEditingController _addressController = TextEditingController(
    text: widget.user.address,
  );
  late final TextEditingController _facebookController = TextEditingController(
    text: widget.user.facebookContact,
  );

  @override
  void dispose() {
    // A full page (rather than a showDialog() modal) means there's no
    // barrier + fade/scale transition competing with the keyboard's own
    // show/hide animation for frame budget when a field is focused — that
    // race was the main source of the jank this used to have as a dialog.
    // Disposing here, from this widget's own dispose(), still matters: it
    // ties controller lifetime to the page's actual removal (after its
    // transition finishes) instead of whenComplete()-style early disposal.
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _facebookController.dispose();
    super.dispose();
  }

  void _save() {
    widget.controller.updateProfileDetails(
      widget.user.username,
      displayName: _nameController.text,
      contactNumber: _contactController.text,
      address: _addressController.text,
      facebookContact: _facebookController.text,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profiles')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              hintText: 'e.g. Juan Dela Cruz',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _contactController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact number',
              hintText: 'e.g. 0917 123 4567',
              prefixIcon: Icon(Icons.call_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _addressController,
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Address',
              hintText: 'e.g. Barangay, City, Province',
              prefixIcon: Icon(Icons.home_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _facebookController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Facebook contact',
              hintText: 'e.g. facebook.com/username',
              prefixIcon: Icon(Icons.facebook),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save Changes')),
        ],
      ),
    );
  }
}

class CredentialsEditPage extends StatefulWidget {
  const CredentialsEditPage({
    super.key,
    required this.controller,
    required this.user,
  });

  final AppController controller;
  final AppUser user;

  @override
  State<CredentialsEditPage> createState() => _CredentialsEditPageState();
}

class _CredentialsEditPageState extends State<CredentialsEditPage> {
  late final TextEditingController _usernameController = TextEditingController(
    text: widget.user.username,
  );
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  String? _error;

  @override
  void dispose() {
    // Disposing from this page's own dispose() (rather than a
    // showDialog().whenComplete()-style callback) ties controller lifetime
    // to the page's actual removal, after its transition finishes — see the
    // same note on ProfileEditPage's dispose().
    _usernameController.dispose();
    _passwordController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  void _save() {
    final result = widget.controller.updateCredentials(
      widget.user.username,
      newUsername: _usernameController.text,
      newPassword: _passwordController.text,
      currentPassword: _currentPasswordController.text,
    );
    if (result != null) {
      setState(() => _error = result);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Username & Password')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New password',
              hintText: 'Leave blank to keep current password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Current password',
              prefixIcon: Icon(Icons.password_outlined),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFFF6B72),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save Changes')),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: colors.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class AdminOverviewPage extends StatelessWidget {
  const AdminOverviewPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Overview')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Central supervision panel',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(
                  'The admin can manage registered users, decide who may use phone camera detection, review CCTV setup status, and answer troubleshooting concerns from the chat inbox.',
                  style: TextStyle(color: colors.mutedText, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 640;
              return GridView.count(
                crossAxisCount: compact ? 1 : 2,
                childAspectRatio: compact ? 2.4 : 1.7,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  SummaryPanel(
                    title: 'Registered Users',
                    value: '${controller.farmUsers.length}',
                    note: 'Active farm accounts',
                    accent: _appAccent,
                  ),
                  SummaryPanel(
                    title: 'Camera Access Enabled',
                    value:
                        '${controller.farmUsers.where((u) => u.cameraAccessEnabled).length}',
                    note: 'Users allowed to scan by phone',
                    accent: const Color(0xFF26C281),
                  ),
                  SummaryPanel(
                    title: 'Connected CCTVs',
                    value: '${controller.totalCctvCount}',
                    note: 'Visible surveillance setups',
                    accent: const Color(0xFF4DA1FF),
                  ),
                  SummaryPanel(
                    title: 'Open Support Threads',
                    value: '${controller.openSupportCount}',
                    note: 'Waiting for admin reply',
                    accent: const Color(0xFFFF6B72),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _addUser() {
    final ok = widget.controller.addUser(
      username: _usernameController.text,
      displayName: _displayNameController.text,
    );

    setState(() => _error = ok ? null : widget.controller.lastError);
    if (ok) {
      _usernameController.clear();
      _displayNameController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Manage Users')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Register new user',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_add_alt_1_outlined),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFFF6B72),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _appAccent,
                      ),
                      onPressed: _addUser,
                      child: const Text('Create User'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...widget.controller.farmUsers.map(
                (user) => AdminUserCard(
                  user: user,
                  onCameraToggle: () =>
                      widget.controller.toggleCameraAccess(user.username),
                  onRemove: () => widget.controller.removeUser(user.username),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AdminCctvPage extends StatelessWidget {
  const AdminCctvPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cctvEntries = controller.farmUsers
        .expand((user) => user.cctvs.map((camera) => (user, camera)))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('CCTV Monitoring')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          _GlassCard(
            child: Text(
              'All CCTV setups connected to the users can be reviewed here for monitoring and supervision.',
              style: TextStyle(color: colors.mutedText, height: 1.55),
            ),
          ),
          const SizedBox(height: 16),
          ...cctvEntries.map(
            (entry) => AdminCctvCard(user: entry.$1, feed: entry.$2),
          ),
        ],
      ),
    );
  }
}

class SupportInboxPage extends StatelessWidget {
  const SupportInboxPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Support Inbox')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              if (controller.supportThreads.isEmpty)
                const EmptyCard(
                  title: 'No support issues',
                  subtitle:
                      'User bug reports and repair schedules appear here.',
                )
              else
                ...controller.supportThreads.map(
                  (thread) => GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AdminThreadPage(
                            controller: controller,
                            threadId: thread.id,
                          ),
                        ),
                      );
                    },
                    child: SupportPreviewCard(thread: thread),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class AdminThreadPage extends StatefulWidget {
  const AdminThreadPage({
    super.key,
    required this.controller,
    required this.threadId,
  });

  final AppController controller;
  final String threadId;

  @override
  State<AdminThreadPage> createState() => _AdminThreadPageState();
}

class _AdminThreadPageState extends State<AdminThreadPage> {
  final TextEditingController _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final thread = widget.controller.threadById(widget.threadId);
        if (thread == null) {
          return const Scaffold(body: Center(child: Text('Thread not found.')));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(thread.username),
            actions: [
              TextButton(
                onPressed: () => widget.controller.resolveThread(thread.id),
                child: Text(thread.resolved ? 'Resolved' : 'Mark Resolved'),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  children: [
                    ...thread.messages.map(
                      (message) => ChatBubble(
                        message: message,
                        mine: message.senderRole == UserRole.admin,
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Reply or confirm a repair schedule',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _appAccent,
                        ),
                        onPressed: () {
                          widget.controller.sendAdminSupportMessage(
                            threadId: thread.id,
                            text: _replyController.text,
                          );
                          _replyController.clear();
                        },
                        child: const Text('Reply'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key, required this.alerts});

  final List<AlertItem> alerts;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Warning Alerts')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: alerts.map((alert) => AlertCard(alert: alert)).toList(),
      ),
    );
  }
}

class ManualCameraPage extends StatefulWidget {
  const ManualCameraPage({
    super.key,
    required this.controller,
    required this.user,
  });

  final AppController controller;
  final AppUser user;

  @override
  State<ManualCameraPage> createState() => _ManualCameraPageState();
}

class _ManualCameraPageState extends State<ManualCameraPage> {
  CameraController? _cameraController;
  Timer? _autoScanTimer;
  bool _initializing = true;
  bool _analyzing = false;
  String? _scanStatus;
  ManualScanResult? _result;

  @override
  void initState() {
    super.initState();
    unawaited(_setupCamera());
  }

  Future<void> _setupCamera() async {
    if (widget.controller.cameras.isEmpty) {
      setState(() => _initializing = false);
      unawaited(_runAnalysis());
      return;
    }

    final preferredCamera = widget.controller.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => widget.controller.cameras.first,
    );

    final controller = CameraController(
      preferredCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _initializing = false;
        _scanStatus = 'Starting automatic scan...';
      });
      _scheduleNextScan(immediate: true);
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _scanStatus = 'Camera preview unavailable';
      });
      unawaited(_runAnalysis());
    }
  }

  void _scheduleNextScan({bool immediate = false}) {
    _autoScanTimer?.cancel();
    _autoScanTimer = Timer(
      immediate ? Duration.zero : _defaultInspectionInterval(),
      () async {
        if (!mounted) return;
        await _runAnalysis();
        _scheduleNextScan();
      },
    );
  }

  String _statusForManualResult(ManualScanResult result) {
    if (result.condition == HealthState.abnormal) {
      return 'Abnormal rooster detected';
    }

    return result.detected ? 'Normal rooster detected' : 'No rooster detected';
  }

  Future<void> _runAnalysis() async {
    if (_analyzing) return;
    final cameraController = _cameraController;
    setState(() {
      _analyzing = true;
      if (_result == null) {
        _scanStatus = 'Running automatic scan...';
      }
    });
    try {
      final result =
          cameraController == null || !cameraController.value.isInitialized
          ? widget.controller.generateManualScan()
          : await widget.controller.inspectManualFrame(
              widget.user.username,
              await (await cameraController.takePicture()).readAsBytes(),
            );
      if (!mounted) return;
      setState(() {
        _result = result;
        _analyzing = false;
        _scanStatus = _statusForManualResult(result);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _result = ManualScanResult(
          condition: HealthState.abnormal,
          breed: '-',
          movement: 'Scan failed',
          note:
              'Could not inspect this phone frame with the on-device model: $error',
        );
        _analyzing = false;
        _scanStatus = 'Scan failed';
      });
    }
  }

  @override
  void dispose() {
    _autoScanTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Widget _buildFillingCameraPreview(CameraController controller) {
    // CameraPreview always wraps itself in an AspectRatio internally, which
    // normally means it can only ever "contain" or "cover" its box, never
    // stretch past its native ratio. FittedBox(fit: BoxFit.fill) sidesteps
    // that: it measures the child at its natural (aspect-locked) size, then
    // scales width and height independently to exactly fill the available
    // space, distorting the image so it fills the screen edge to edge.
    final aspectRatio = controller.value.aspectRatio;
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: 100,
        height: 100 / aspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCamera =
        _cameraController != null && _cameraController!.value.isInitialized;
    final resultColor = _result == null
        ? Colors.white70
        : _result!.condition == HealthState.abnormal
        ? HealthState.abnormal.color
        : const Color(0xFF43E39C);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Manual Rooster Scan')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_initializing)
            const Center(child: CircularProgressIndicator())
          else if (hasCamera) ...[
            _buildFillingCameraPreview(_cameraController!),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: ChickenDetectionPainter(
                    detections: _result?.detections ?? const [],
                  ),
                ),
              ),
            ),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Camera preview is unavailable on this device or emulator, but the scan flow remains connected for UI testing.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.5),
                ),
              ),
            ),
          if (_scanStatus != null)
            Positioned(
              top: 16,
              left: 16,
              child: SeverityTag(label: _scanStatus!, color: resultColor),
            ),
          const Positioned(
            top: 16,
            right: 16,
            child: SeverityTag(
              label: 'AUTO SCAN ACTIVE',
              color: Color(0xFFFFCE67),
            ),
          ),
          if (_result case final result?)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Theme(
                // SummaryMiniCard colors its text from the ambient theme; in
                // light mode that would be near-black and unreadable against
                // this dark overlay, so force dark colors regardless of the
                // app's actual theme setting (same trick used for the CCTV
                // fullscreen PTZ overlay).
                data: buildAppTheme(Brightness.dark),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: SummaryMiniCard(
                      title: 'Confidence',
                      value: result.confidenceLabel,
                      dark: true,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
