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
    final colors = context.appColors;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.backgroundGradientStart,
              colors.backgroundGradientMiddle,
              colors.backgroundGradientEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const _LandingBrand(),
              const SizedBox(height: 18),
              _LandingLoginPanel(
                onUserTap: () => _openLogin(context, UserRole.user),
                onAdminTap: () => _openLogin(context, UserRole.admin),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  AppPill(
                    icon: Icons.sensors_outlined,
                    label: 'Live Environment',
                  ),
                  AppPill(icon: Icons.videocam_outlined, label: 'YOLOv8 CCTV'),
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
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.expectedRole == UserRole.admin ? 'admin' : 'farmer1',
    );
    _passwordController = TextEditingController(
      text: widget.expectedRole == UserRole.admin ? 'admin123' : 'farm123',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _signIn() {
    final session = widget.controller.signIn(
      username: _usernameController.text,
      password: _passwordController.text,
      expectedRole: widget.expectedRole,
    );

    if (session == null) {
      setState(() => _error = widget.controller.lastError);
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) =>
            AppShell(controller: widget.controller, session: session),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.expectedRole == UserRole.admin;
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Text(
            isAdmin ? 'Admin access' : 'User access',
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            isAdmin
                ? 'Manage users, switch phone camera detection on or off, and monitor connected CCTV setups.'
                : 'Open the monitoring dashboard, review rooster health alerts, use manual scan, and contact the admin when something breaks.',
            style: TextStyle(color: colors.mutedText, height: 1.55),
          ),
          const SizedBox(height: 22),
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Demo account',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _appAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isAdmin
                      ? 'Username: admin\nPassword: admin123'
                      : 'Username: farmer1\nPassword: farm123',
                  style: TextStyle(color: colors.mutedText, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
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
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF3A1F2A),
                borderRadius: BorderRadius.circular(18),
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
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _appAccent,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            onPressed: _signIn,
            child: Text(isAdmin ? 'Login as Admin' : 'Login as User'),
          ),
        ],
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
            UserGuidelinesPage(guides: widget.controller.guides),
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
        title: const Text('User Dashboard'),
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
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Esp32SensorConnectionCard(
              controller: controller,
              username: user.username,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CircularSensorGauge(
                    title: 'Temp',
                    value: monitor.temperature.toStringAsFixed(1),
                    unit: '°C',
                    progress: monitor.temperature / 45,
                    icon: Icons.thermostat_outlined,
                    status: monitor.temperatureStatus,
                    level: monitor.temperatureLevel,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CircularSensorGauge(
                    title: 'Humidity',
                    value: monitor.humidity.toStringAsFixed(0),
                    unit: '%',
                    progress: monitor.humidity / 100,
                    icon: Icons.water_drop_outlined,
                    status: monitor.humidityStatus,
                    level: monitor.humidityLevel,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CircularSensorGauge(
                    title: 'Air',
                    value: '${monitor.airPpm}',
                    unit: 'ppm',
                    progress: monitor.airPpm / 50,
                    icon: Icons.air_outlined,
                    status: monitor.airStatus,
                    level: monitor.airLevel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Active Warnings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                SeverityTag(
                  label: monitor.alerts.isEmpty
                      ? 'ALL CLEAR'
                      : '${monitor.alerts.length} ACTIVE',
                  color: monitor.alerts.isEmpty
                      ? const Color(0xFF26C281)
                      : _appAccent,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: monitor.alerts.isEmpty
                  ? const _AllClearCard()
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        ...monitor.alerts.map(
                          (alert) => AlertCard(alert: alert),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllClearCard extends StatelessWidget {
  const _AllClearCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.verified_outlined,
            color: Color(0xFF26C281),
            size: 40,
          ),
          const SizedBox(height: 10),
          const Text(
            'Farm conditions look safe',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Alerts will appear here when a reading becomes unsafe.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.mutedText),
          ),
        ],
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final user = controller.userByUsername(session.user.username)!;
        final monitor = user.monitor;
        final colors = context.appColors;

        return Scaffold(
          appBar: AppBar(title: const Text('CCTV Monitoring')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const SectionHeader(
                title: 'CCTV Rooster Inspection',
                subtitle:
                    'Connect the RTSP camera, preview the live feed, and inspect rendered frames with the on-device YOLOv8 model.',
              ),
              const SizedBox(height: 12),
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Main Pen CCTV',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        SeverityTag(
                          label: monitor.cctvStatus.label,
                          color: monitor.cctvStatus.color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    CctvConnectionPanel(controller: controller, user: user),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              CctvInspectionResultCard(result: user.cctvInspection),
              const SizedBox(height: 14),
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monitor.cctvSummary,
                      style: TextStyle(color: colors.mutedText, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SummaryMiniCard(
                            title: 'Detected Breed',
                            value: monitor.detectedBreed,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SummaryMiniCard(
                            title: 'Movement',
                            value: monitor.movementLabel,
                          ),
                        ),
                      ],
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

class UserGuidelinesPage extends StatelessWidget {
  const UserGuidelinesPage({super.key, required this.guides});

  final List<GuidelineItem> guides;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(title: const Text('Care Guidelines')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          _GlassCard(
            child: Text(
              'This section gives users simple guidance for breeding, daily chick check-up, feeding, coop cleanliness, and quick response during dangerous farm conditions.',
              style: TextStyle(color: colors.mutedText, height: 1.55),
            ),
          ),
          const SizedBox(height: 16),
          ...guides.map((guide) => GuidelineCard(item: guide)),
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
                  child: Row(
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
                ),
              ),
            ],
          ),
        );
      },
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
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          _GlassCard(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _appAccent, width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: colors.accentSurface,
                    child: Icon(
                      session.user.isAdmin
                          ? Icons.admin_panel_settings_outlined
                          : Icons.person_outline,
                      color: _appAccent,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user.isAdmin
                      ? 'Admin supervisor account'
                      : 'Backyard rooster farm user account',
                  style: TextStyle(color: colors.mutedText),
                ),
                const SizedBox(height: 18),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _ProfileStat(
                          value: user.isAdmin ? 'Admin' : 'User',
                          label: 'Role',
                        ),
                      ),
                      VerticalDivider(color: colors.border, width: 1),
                      Expanded(
                        child: _ProfileStat(
                          value: '${user.cctvs.length}',
                          label: 'CCTVs',
                        ),
                      ),
                      VerticalDivider(color: colors.border, width: 1),
                      Expanded(
                        child: _ProfileStat(
                          value: '${user.monitor.alerts.length}',
                          label: 'Alerts',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ProfileInfoCard(
            icon: Icons.badge_outlined,
            title: 'Username',
            subtitle: user.username,
          ),
          ProfileInfoCard(
            icon: Icons.camera_alt_outlined,
            title: 'Manual camera access',
            subtitle: user.isAdmin
                ? 'Admin account'
                : user.cameraAccessEnabled
                ? 'Enabled by admin'
                : 'Disabled by admin',
          ),
          ProfileInfoCard(
            icon: Icons.support_agent_outlined,
            title: 'Support conversation',
            subtitle: user.isAdmin
                ? '${controller.openSupportCount} open issue threads'
                : controller.threadForUser(user.username) == null
                ? 'No issue reported'
                : 'Issue thread available',
          ),
          ThemePreferenceCard(controller: controller),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () {
              controller.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(
                  builder: (_) => LandingPage(controller: controller),
                ),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),
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
  bool _initializing = true;
  bool _analyzing = false;
  String? _scanStatus;
  ManualScanResult? _result;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    if (widget.controller.cameras.isEmpty) {
      setState(() => _initializing = false);
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
        _scanStatus = 'Ready for manual scan';
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _scanStatus = 'Camera preview unavailable';
      });
    }
  }

  String _statusForManualResult(ManualScanResult result) {
    if (result.condition == HealthState.abnormal) {
      return 'Abnormal rooster detected';
    }

    return result.detected ? 'Normal rooster detected' : 'No rooster detected';
  }

  Future<void> _runAnalysis() async {
    final cameraController = _cameraController;
    setState(() {
      _analyzing = true;
      _scanStatus = 'Running manual scan...';
    });
    try {
      final result =
          cameraController == null || !cameraController.value.isInitialized
          ? widget.controller.generateManualScan(widget.user.username)
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
          breed: widget.user.monitor.detectedBreed,
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
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasCamera =
        _cameraController != null && _cameraController!.value.isInitialized;

    return Scaffold(
      appBar: AppBar(title: const Text('Manual Rooster Scan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              height: 320,
              color: colors.surfaceRaised,
              child: _initializing
                  ? const Center(child: CircularProgressIndicator())
                  : hasCamera
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_cameraController!),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: ChickenDetectionPainter(
                                detections: _result?.detections ?? const [],
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Camera preview is unavailable on this device or emulator, but the scan flow remains connected for UI testing.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.text, height: 1.5),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (_scanStatus != null) ...[
            SeverityTag(
              label: _scanStatus!,
              color: _result?.condition == HealthState.abnormal
                  ? HealthState.abnormal.color
                  : colors.mutedText,
            ),
            const SizedBox(height: 16),
          ],
          _GlassCard(
            child: Text(
              'AI detection runs only when you capture the current camera view.',
              style: TextStyle(color: colors.mutedText, height: 1.55),
            ),
          ),
          const SizedBox(height: 16),
          const _LocalYoloModelStatus(),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF26C281),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            onPressed: _analyzing ? null : _runAnalysis,
            icon: const Icon(Icons.center_focus_strong_outlined),
            label: Text(_analyzing ? 'Analyzing...' : 'Capture Current View'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            ManualScanResultCard(result: _result!),
          ],
        ],
      ),
    );
  }
}
