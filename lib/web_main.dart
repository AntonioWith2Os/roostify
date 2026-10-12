import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Browser-first entry point for Roostify.
///
/// This intentionally does not import [main.dart]. The native app imports
/// device-only SDKs (BLE, RTSP, local inference, and phone camera APIs) that
/// are not available to browsers. This portal keeps the monitoring workflow
/// available on the web and provides clear browser-friendly placeholders for
/// the hardware features.
void main() {
  runApp(const RoostifyWebApp());
}

class RoostifyWebApp extends StatefulWidget {
  const RoostifyWebApp({super.key});

  @override
  State<RoostifyWebApp> createState() => _RoostifyWebAppState();
}

class _RoostifyWebAppState extends State<RoostifyWebApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _signedIn = false;
  bool _isAdmin = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roostify Web',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _webTheme(Brightness.light),
      darkTheme: _webTheme(Brightness.dark),
      home: _signedIn
          ? WebPortal(
              isAdmin: _isAdmin,
              onThemeChanged: (isDark) {
                setState(
                  () => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light,
                );
              },
              onSignOut: () => setState(() => _signedIn = false),
            )
          : WebWelcome(
              onContinue: (isAdmin) {
                setState(() {
                  _isAdmin = isAdmin;
                  _signedIn = true;
                });
              },
            ),
    );
  }
}

ThemeData _webTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFE86839),
    brightness: brightness,
    surface: dark ? const Color(0xFF171B31) : Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF0C1020)
        : const Color(0xFFF6F7FB),
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: dark ? const Color(0xFFF2F4FF) : const Color(0xFF17213A),
      displayColor: dark ? const Color(0xFFF2F4FF) : const Color(0xFF17213A),
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF171D35) : Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: dark ? const Color(0xFF2A3458) : const Color(0xFFE2E6EE),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF222943) : const Color(0xFFF3F5F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: dark ? const Color(0xFF303A60) : const Color(0xFFDDE3EC),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFE86839),
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: dark
            ? const Color(0xFFEAF0FF)
            : const Color(0xFF17213A),
        side: BorderSide(
          color: dark ? const Color(0xFF3A456B) : const Color(0xFFD5DCE8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        shape: const StadiumBorder(),
      ),
    ),
  );
}

class WebWelcome extends StatefulWidget {
  const WebWelcome({super.key, required this.onContinue});

  final ValueChanged<bool> onContinue;

  @override
  State<WebWelcome> createState() => _WebWelcomeState();
}

class _WebWelcomeState extends State<WebWelcome> {
  bool _admin = false;
  bool _hidePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _WelcomeBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1050),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 780;
                      final intro = const _WelcomeIntro();
                      final signIn = _SignInCard(
                        admin: _admin,
                        hidePassword: _hidePassword,
                        onRoleChanged: (value) =>
                            setState(() => _admin = value),
                        onPasswordVisibilityChanged: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        onContinue: () => widget.onContinue(_admin),
                      );
                      return compact
                          ? Column(
                              children: [
                                intro,
                                const SizedBox(height: 26),
                                signIn,
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: intro),
                                const SizedBox(width: 64),
                                SizedBox(width: 405, child: signIn),
                              ],
                            );
                    },
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

class _WelcomeBackdrop extends StatelessWidget {
  const _WelcomeBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B1020), Color(0xFF121A34), Color(0xFF332117)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -190,
            right: -100,
            child: _Glow(color: const Color(0x33EC8A5C), size: 470),
          ),
          Positioned(
            bottom: -200,
            left: -90,
            child: _Glow(color: const Color(0x243E77F4), size: 460),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 90, spreadRadius: 38)],
      ),
    );
  }
}

class _WelcomeIntro extends StatelessWidget {
  const _WelcomeIntro();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BrandMark(large: true),
        const SizedBox(height: 36),
        Text(
          'A clearer view\nof every coop.',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            height: 1.04,
            letterSpacing: -1.3,
          ),
        ),
        const SizedBox(height: 18),
        const SizedBox(
          width: 490,
          child: Text(
            'Roostify brings live environmental readings, AI-assisted behavior checks, and CCTV monitoring together in one practical farm workspace.',
            style: TextStyle(
              color: Color(0xFFC0C9E9),
              fontSize: 17,
              height: 1.58,
            ),
          ),
        ),
        const SizedBox(height: 34),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _FeatureChip(
              icon: Icons.sensors_outlined,
              label: 'Live environment',
            ),
            _FeatureChip(icon: Icons.videocam_outlined, label: 'CCTV insights'),
            _FeatureChip(
              icon: Icons.health_and_safety_outlined,
              label: 'Flock wellbeing',
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x17FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x2EFFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFFB096), size: 19),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({
    required this.admin,
    required this.hidePassword,
    required this.onRoleChanged,
    required this.onPasswordVisibilityChanged,
    required this.onContinue,
  });

  final bool admin;
  final bool hidePassword;
  final ValueChanged<bool> onRoleChanged;
  final VoidCallback onPasswordVisibilityChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xF7181F37),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome back',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Sign in to your farm workspace.',
              style: TextStyle(color: Color(0xFFB3BEDD)),
            ),
            const SizedBox(height: 25),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.agriculture_outlined),
                  label: Text('Farm user'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  label: Text('Admin'),
                ),
              ],
              selected: {admin},
              onSelectionChanged: (value) => onRoleChanged(value.first),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(Colors.white),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? const Color(0xFFE86839)
                      : const Color(0xFF242D4D),
                ),
                side: WidgetStateProperty.all(
                  const BorderSide(color: Color(0xFF3A4569)),
                ),
              ),
            ),
            const SizedBox(height: 19),
            const TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Username',
                labelStyle: TextStyle(color: Color(0xFFB8C1DC)),
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: Color(0xFFE86839),
                ),
              ),
            ),
            const SizedBox(height: 13),
            TextField(
              obscureText: hidePassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(color: Color(0xFFB8C1DC)),
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFFE86839),
                ),
                suffixIcon: IconButton(
                  tooltip: hidePassword ? 'Show password' : 'Hide password',
                  onPressed: onPasswordVisibilityChanged,
                  icon: Icon(
                    hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFFB8C1DC),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Open web workspace'),
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Demo mode: this browser portal uses sample readings until it is connected to your production data source.',
              style: TextStyle(
                color: Color(0xFF8F9ABA),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum PortalSection { overview, cameras, scan, alerts, guides, support, profile }

extension PortalSectionLabel on PortalSection {
  String get label => switch (this) {
    PortalSection.overview => 'Overview',
    PortalSection.cameras => 'Cameras',
    PortalSection.scan => 'Manual scan',
    PortalSection.alerts => 'Alerts',
    PortalSection.guides => 'Guides',
    PortalSection.support => 'Support',
    PortalSection.profile => 'Profile',
  };

  IconData get icon => switch (this) {
    PortalSection.overview => Icons.grid_view_rounded,
    PortalSection.cameras => Icons.videocam_outlined,
    PortalSection.scan => Icons.document_scanner_outlined,
    PortalSection.alerts => Icons.notifications_none_rounded,
    PortalSection.guides => Icons.menu_book_outlined,
    PortalSection.support => Icons.forum_outlined,
    PortalSection.profile => Icons.person_outline_rounded,
  };
}

class WebAlert {
  WebAlert({
    required this.title,
    required this.detail,
    required this.severity,
    required this.time,
    this.dismissed = false,
  });
  final String title;
  final String detail;
  final AlertSeverity severity;
  final String time;
  bool dismissed;
}

enum AlertSeverity { attention, caution, info }

class WebCamera {
  WebCamera({
    required this.name,
    required this.location,
    required this.status,
    required this.detail,
    this.aiEnabled = true,
  });
  final String name;
  final String location;
  final String status;
  final String detail;
  bool aiEnabled;
}

class WebPortal extends StatefulWidget {
  const WebPortal({
    super.key,
    required this.isAdmin,
    required this.onThemeChanged,
    required this.onSignOut,
  });

  final bool isAdmin;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onSignOut;

  @override
  State<WebPortal> createState() => _WebPortalState();
}

class _WebPortalState extends State<WebPortal> {
  PortalSection _section = PortalSection.overview;
  late Timer _clock;
  DateTime _now = DateTime.now();
  bool _sensorConnected = true;
  final List<WebAlert> _alerts = [
    WebAlert(
      title: 'Activity pattern needs a check',
      detail: 'Camera A saw prolonged irregular pacing near the feeder.',
      severity: AlertSeverity.attention,
      time: '12 min ago',
    ),
    WebAlert(
      title: 'Humidity approaching caution zone',
      detail:
          'Coop humidity is 72%; consider improving airflow before it rises further.',
      severity: AlertSeverity.caution,
      time: '38 min ago',
    ),
    WebAlert(
      title: 'Daily health summary is ready',
      detail: 'Your morning monitoring snapshot has been prepared.',
      severity: AlertSeverity.info,
      time: 'Today, 8:00 AM',
    ),
  ];
  final List<WebCamera> _cameras = [
    WebCamera(
      name: 'Camera A',
      location: 'Main Pen',
      status: 'Attention',
      detail: 'Irregular pacing detected near feeder area.',
    ),
    WebCamera(
      name: 'Camera B',
      location: 'Chick Zone',
      status: 'Normal',
      detail: 'Chicks visible and resting normally.',
    ),
  ];
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      'You',
      'The app warning appeared. Can you help me check the sensor device?',
      false,
    ),
    _ChatMessage(
      'Roostify Support',
      'Absolutely. First, check that the ESP32 power light is on. We can schedule remote troubleshooting if it is.',
      true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(
      const Duration(seconds: 10),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  int get _activeAlertCount => _alerts.where((item) => !item.dismissed).length;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, bounds) {
        final desktop = bounds.maxWidth >= 980;
        return Scaffold(
          body: Row(
            children: [
              if (desktop)
                _Sidebar(
                  active: _section,
                  alertCount: _activeAlertCount,
                  isAdmin: widget.isAdmin,
                  onSelected: (section) => setState(() => _section = section),
                  onSignOut: widget.onSignOut,
                ),
              Expanded(
                child: SafeArea(
                  child: Column(
                    children: [
                      _PortalHeader(
                        section: _section,
                        alertCount: _activeAlertCount,
                        isAdmin: widget.isAdmin,
                        dark: dark,
                        onAlerts: () =>
                            setState(() => _section = PortalSection.alerts),
                      ),
                      if (!desktop)
                        _MobileNav(
                          active: _section,
                          alertCount: _activeAlertCount,
                          onSelected: (section) =>
                              setState(() => _section = section),
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            desktop ? 34 : 18,
                            12,
                            desktop ? 34 : 18,
                            34,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1440),
                            child: _bodyFor(
                              _section,
                              isWide: bounds.maxWidth >= 1180,
                            ),
                          ),
                        ),
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

  Widget _bodyFor(PortalSection section, {required bool isWide}) {
    return switch (section) {
      PortalSection.overview => _OverviewPage(
        isAdmin: widget.isAdmin,
        isWide: isWide,
        now: _now,
        sensorConnected: _sensorConnected,
        cameras: _cameras,
        alerts: _alerts.where((item) => !item.dismissed).toList(),
        onOpenCameras: () => setState(() => _section = PortalSection.cameras),
        onOpenAlerts: () => setState(() => _section = PortalSection.alerts),
        onSensorToggle: () =>
            setState(() => _sensorConnected = !_sensorConnected),
      ),
      PortalSection.cameras => _CamerasPage(
        cameras: _cameras,
        isWide: isWide,
        onAdd: _addCamera,
        onChanged: () => setState(() {}),
      ),
      PortalSection.scan => _ScanPage(onAlertAdded: _addScanAlert),
      PortalSection.alerts => _AlertsPage(
        alerts: _alerts,
        onDismiss: (alert) => setState(() => alert.dismissed = true),
        onRestore: (alert) => setState(() => alert.dismissed = false),
      ),
      PortalSection.guides => const _GuidesPage(),
      PortalSection.support => _SupportPage(
        messages: _messages,
        onSend: _sendMessage,
      ),
      PortalSection.profile => _ProfilePage(
        isAdmin: widget.isAdmin,
        dark: Theme.of(context).brightness == Brightness.dark,
        onThemeChanged: widget.onThemeChanged,
        onSignOut: widget.onSignOut,
      ),
    };
  }

  void _addCamera() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddCameraDialog(
        onSave: (name, location) {
          setState(() {
            _cameras.add(
              WebCamera(
                name: name,
                location: location,
                status: 'Connecting',
                detail: 'Waiting for a browser-compatible HLS or HTTPS feed.',
              ),
            );
          });
        },
      ),
    );
  }

  void _addScanAlert() {
    setState(() {
      _alerts.insert(
        0,
        WebAlert(
          title: 'Manual scan needs review',
          detail:
              'The last manual image scan found one rooster with an abnormal posture confidence of 83%.',
          severity: AlertSeverity.attention,
          time: 'Just now',
        ),
      );
      _section = PortalSection.alerts;
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage('You', text.trim(), false));
      _messages.add(
        _ChatMessage(
          'Roostify Support',
          'Thanks — your message is queued. A support specialist will reply in this thread.',
          true,
        ),
      );
    });
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.active,
    required this.alertCount,
    required this.isAdmin,
    required this.onSelected,
    required this.onSignOut,
  });
  final PortalSection active;
  final int alertCount;
  final bool isAdmin;
  final ValueChanged<PortalSection> onSelected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 258,
      color: const Color(0xFF11162A),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: _BrandMark(),
          ),
          const SizedBox(height: 34),
          ...PortalSection.values.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: _NavigationItem(
                section: section,
                active: active == section,
                badge: section == PortalSection.alerts && alertCount > 0
                    ? '$alertCount'
                    : null,
                onTap: () => onSelected(section),
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2441),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFF303B60)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE86839),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAdmin ? 'System Admin' : 'Farmer One',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        isAdmin ? 'Administrator' : 'Farm user',
                        style: const TextStyle(
                          color: Color(0xFFAEB9D6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onSignOut,
                  tooltip: 'Sign out',
                  icon: const Icon(
                    Icons.logout,
                    color: Color(0xFFAEB9D6),
                    size: 19,
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

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.large = false});
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: large ? 50 : 37,
          height: large ? 50 : 37,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3ED),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.asset(
            'assets/roostify_logo_transparent.png',
            errorBuilder: (_, _, _) =>
                const Icon(Icons.egg_alt_rounded, color: Color(0xFFE86839)),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Roostify',
          style: TextStyle(
            color: Colors.white,
            fontSize: large ? 26 : 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.section,
    required this.active,
    required this.onTap,
    this.badge,
  });
  final PortalSection section;
  final bool active;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFF412922) : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          child: Row(
            children: [
              Icon(
                section.icon,
                size: 21,
                color: active
                    ? const Color(0xFFFF9A74)
                    : const Color(0xFFAEB9D6),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  section.label,
                  style: TextStyle(
                    color: active ? Colors.white : const Color(0xFFC4CCE5),
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (badge != null) _Badge(label: badge!),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: const BoxDecoration(
      color: Color(0xFFE86839),
      shape: BoxShape.circle,
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _PortalHeader extends StatelessWidget {
  const _PortalHeader({
    required this.section,
    required this.alertCount,
    required this.isAdmin,
    required this.dark,
    required this.onAlerts,
  });
  final PortalSection section;
  final int alertCount;
  final bool isAdmin;
  final bool dark;
  final VoidCallback onAlerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 79,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: dark ? const Color(0xFF242E50) : const Color(0xFFE3E7EF),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.label,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  isAdmin
                      ? 'System administration workspace'
                      : 'Farm monitoring workspace',
                  style: TextStyle(
                    color: dark
                        ? const Color(0xFFAEB9D6)
                        : const Color(0xFF68728A),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (section != PortalSection.alerts)
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: onAlerts,
                  tooltip: 'Open alerts',
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                if (alertCount > 0)
                  Positioned(
                    top: 7,
                    right: 6,
                    child: _Badge(label: '$alertCount'),
                  ),
              ],
            ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: isAdmin
                ? const Color(0xFF7557E9)
                : const Color(0xFFE86839),
            radius: 18,
            child: Icon(
              isAdmin
                  ? Icons.admin_panel_settings_outlined
                  : Icons.person_outline,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({
    required this.active,
    required this.alertCount,
    required this.onSelected,
  });
  final PortalSection active;
  final int alertCount;
  final ValueChanged<PortalSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        children: PortalSection.values.map((section) {
          final selected = section == active;
          return Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(section.icon, size: 16),
                  const SizedBox(width: 6),
                  Text(section.label),
                  if (section == PortalSection.alerts && alertCount > 0) ...[
                    const SizedBox(width: 5),
                    _Badge(label: '$alertCount'),
                  ],
                ],
              ),
              selected: selected,
              onSelected: (_) => onSelected(section),
              selectedColor: const Color(0xFFE86839),
              backgroundColor: dark ? const Color(0xFF1B2340) : Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({
    required this.isAdmin,
    required this.isWide,
    required this.now,
    required this.sensorConnected,
    required this.cameras,
    required this.alerts,
    required this.onOpenCameras,
    required this.onOpenAlerts,
    required this.onSensorToggle,
  });
  final bool isAdmin;
  final bool isWide;
  final DateTime now;
  final bool sensorConnected;
  final List<WebCamera> cameras;
  final List<WebAlert> alerts;
  final VoidCallback onOpenCameras;
  final VoidCallback onOpenAlerts;
  final VoidCallback onSensorToggle;

  @override
  Widget build(BuildContext context) {
    if (isAdmin)
      return _AdminOverview(
        isWide: isWide,
        onOpenCameras: onOpenCameras,
        onOpenAlerts: onOpenAlerts,
      );
    final temp = 27.2 + math.sin(now.minute / 8) * .4;
    final humidity = 69 + (now.minute % 4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageIntro(
          eyebrow: 'LIVE FARM STATUS',
          title: 'Good morning, Farmer One.',
          description: sensorConnected
              ? 'Your main pen is being monitored. Here is the latest view of your flock.'
              : 'The sensor is offline. Reconnect it to resume live environmental readings.',
          action: OutlinedButton.icon(
            onPressed: onSensorToggle,
            icon: Icon(
              sensorConnected ? Icons.power_settings_new : Icons.wifi_tethering,
            ),
            label: Text(
              sensorConnected ? 'Test offline state' : 'Reconnect sensor',
            ),
          ),
        ),
        const SizedBox(height: 22),
        _FarmStatusHero(
          sensorConnected: sensorConnected,
          temperature: temp,
          humidity: humidity,
          cameraCount: cameras.length,
          alertCount: alerts.length,
          onOpenCameras: onOpenCameras,
        ),
        const SizedBox(height: 22),
        _SectionHeading(
          title: 'Environment at a glance',
          action: TextButton(
            onPressed: onOpenAlerts,
            child: const Text('View alerts'),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth > 830
                ? 3
                : box.maxWidth > 510
                ? 2
                : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 13,
              crossAxisSpacing: 13,
              childAspectRatio: columns == 1 ? 3.4 : 1.55,
              children: [
                _MetricCard(
                  icon: Icons.thermostat_outlined,
                  label: 'Temperature',
                  value: '${temp.toStringAsFixed(1)}°C',
                  status: 'Ideal range',
                  tint: const Color(0xFFFF8A65),
                ),
                _MetricCard(
                  icon: Icons.water_drop_outlined,
                  label: 'Humidity',
                  value: '$humidity%',
                  status: humidity > 70 ? 'Watch airflow' : 'Comfortable',
                  tint: const Color(0xFF60B8F7),
                ),
                _MetricCard(
                  icon: Icons.air_outlined,
                  label: 'Air quality',
                  value: 'Good',
                  status: 'No action needed',
                  tint: const Color(0xFF62C58C),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, box) {
            final stack = box.maxWidth < 820;
            final feed = _LiveFeedPreview(
              cameras: cameras,
              onOpenCameras: onOpenCameras,
            );
            final events = _RecentAlerts(
              alerts: alerts,
              onOpenAlerts: onOpenAlerts,
            );
            return stack
                ? Column(children: [feed, const SizedBox(height: 18), events])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: feed),
                      const SizedBox(width: 18),
                      Expanded(flex: 4, child: events),
                    ],
                  );
          },
        ),
      ],
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({
    required this.eyebrow,
    required this.title,
    required this.description,
    this.action,
  });
  final String eyebrow;
  final String title;
  final String description;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, size) {
        final stack = size.maxWidth < 610;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                color: Color(0xFFE86839),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.25,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(color: _muted(context), height: 1.45),
            ),
          ],
        );
        return stack
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  copy,
                  if (action != null) ...[const SizedBox(height: 15), action!],
                ],
              )
            : Row(
                children: [
                  Expanded(child: copy),
                  if (action != null) action!,
                ],
              );
      },
    );
  }
}

Color _muted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFAEB9D6)
    : const Color(0xFF667089);

class _FarmStatusHero extends StatelessWidget {
  const _FarmStatusHero({
    required this.sensorConnected,
    required this.temperature,
    required this.humidity,
    required this.cameraCount,
    required this.alertCount,
    required this.onOpenCameras,
  });
  final bool sensorConnected;
  final double temperature;
  final int humidity;
  final int cameraCount;
  final int alertCount;
  final VoidCallback onOpenCameras;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25345D), Color(0xFF1D2344), Color(0xFF442A20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFF425480)),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final stack = box.maxWidth < 750;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LiveDot(active: sensorConnected),
                  const SizedBox(width: 8),
                  Text(
                    sensorConnected ? 'SENSOR ONLINE' : 'SENSOR OFFLINE',
                    style: TextStyle(
                      color: sensorConnected
                          ? const Color(0xFF85E4AC)
                          : const Color(0xFFFFB199),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: .7,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Main Pen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                sensorConnected
                    ? 'Last update: just now'
                    : 'Last update: 14 minutes ago',
                style: const TextStyle(color: Color(0xFFBAC8E9)),
              ),
              const SizedBox(height: 18),
              FilledButton.tonalIcon(
                onPressed: onOpenCameras,
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Open live cameras'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0x32FFFFFF),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
          final stats = Wrap(
            spacing: 11,
            runSpacing: 11,
            children: [
              _HeroStat(
                icon: Icons.thermostat,
                value: '${temperature.toStringAsFixed(1)}°',
                label: 'temperature',
              ),
              _HeroStat(
                icon: Icons.water_drop_outlined,
                value: '$humidity%',
                label: 'humidity',
              ),
              _HeroStat(
                icon: Icons.videocam_outlined,
                value: '$cameraCount',
                label: 'cameras',
              ),
              _HeroStat(
                icon: Icons.priority_high_rounded,
                value: '$alertCount',
                label: 'alerts',
              ),
            ],
          );
          return stack
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 22), stats],
                )
              : Row(
                  children: [
                    Expanded(child: title),
                    SizedBox(
                      width: math.min(430, box.maxWidth * .48),
                      child: stats,
                    ),
                  ],
                );
        },
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      color: active ? const Color(0xFF70D998) : const Color(0xFFFF896E),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: active ? const Color(0x9970D998) : const Color(0x99FF896E),
          blurRadius: 8,
        ),
      ],
    ),
  );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    width: 124,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0x14FFFFFF),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x26FFFFFF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFFFB195), size: 19),
        const SizedBox(height: 13),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFBDC8E8), fontSize: 12),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.status,
    required this.tint,
  });
  final IconData icon;
  final String label;
  final String value;
  final String status;
  final Color tint;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: _muted(context), fontSize: 12)),
          const SizedBox(height: 10),
          Text(
            status,
            style: TextStyle(
              color: tint,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
      if (action != null) action!,
    ],
  );
}

class _LiveFeedPreview extends StatelessWidget {
  const _LiveFeedPreview({required this.cameras, required this.onOpenCameras});
  final List<WebCamera> cameras;
  final VoidCallback onOpenCameras;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
          child: Row(
            children: [
              const Expanded(
                child: _SectionHeading(title: 'Live camera overview'),
              ),
              TextButton(
                onPressed: onOpenCameras,
                child: const Text('Manage cameras'),
              ),
            ],
          ),
        ),
        AspectRatio(
          aspectRatio: 16 / 8.3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/chickens/healthy_rooster.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFF202A45)),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x800B1020),
                      Colors.transparent,
                      Color(0xAA0B1020),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                top: 15,
                left: 15,
                child: Row(
                  children: const [
                    _LiveDot(active: true),
                    SizedBox(width: 7),
                    Text(
                      'LIVE · CAMERA A',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: .6,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 13,
                top: 13,
                child: _Pill(
                  label: cameras.isNotEmpty && cameras.first.aiEnabled
                      ? 'AI TRACKING ON'
                      : 'AI TRACKING OFF',
                  color: cameras.isNotEmpty && cameras.first.aiEnabled
                      ? const Color(0xFF3BC783)
                      : const Color(0xFF8893B4),
                ),
              ),
              const Positioned(left: 25, bottom: 27, child: _DetectionBox()),
              const Positioned(
                right: 15,
                bottom: 13,
                child: Icon(Icons.fullscreen_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DetectionBox extends StatelessWidget {
  const _DetectionBox();
  @override
  Widget build(BuildContext context) => Container(
    width: 140,
    height: 106,
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFF7EE7AB), width: 2),
      borderRadius: BorderRadius.circular(6),
    ),
    alignment: Alignment.topLeft,
    child: Transform.translate(
      offset: const Offset(-2, -25),
      child: const _Pill(label: 'ROOSTER · 96%', color: Color(0xFF3BC783)),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: .3,
      ),
    ),
  );
}

class _RecentAlerts extends StatelessWidget {
  const _RecentAlerts({required this.alerts, required this.onOpenAlerts});
  final List<WebAlert> alerts;
  final VoidCallback onOpenAlerts;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            title: 'Needs attention',
            action: TextButton(
              onPressed: onOpenAlerts,
              child: const Text('All alerts'),
            ),
          ),
          const SizedBox(height: 5),
          if (alerts.isEmpty)
            const _EmptyPanel(
              icon: Icons.task_alt_rounded,
              title: 'All caught up',
              detail: 'There are no active farm alerts.',
            )
          else
            ...alerts.take(3).map((alert) => _CompactAlert(alert: alert)),
        ],
      ),
    ),
  );
}

class _CompactAlert extends StatelessWidget {
  const _CompactAlert({required this.alert});
  final WebAlert alert;
  @override
  Widget build(BuildContext context) {
    final color = _severityColor(alert.severity);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              shape: BoxShape.circle,
            ),
            child: Icon(_severityIcon(alert.severity), color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.time,
                  style: TextStyle(color: _muted(context), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _severityColor(AlertSeverity severity) => switch (severity) {
  AlertSeverity.attention => const Color(0xFFFF775D),
  AlertSeverity.caution => const Color(0xFFFFB657),
  AlertSeverity.info => const Color(0xFF6FAEF6),
};
IconData _severityIcon(AlertSeverity severity) => switch (severity) {
  AlertSeverity.attention => Icons.priority_high_rounded,
  AlertSeverity.caution => Icons.warning_amber_rounded,
  AlertSeverity.info => Icons.info_outline_rounded,
};

class _AdminOverview extends StatelessWidget {
  const _AdminOverview({
    required this.isWide,
    required this.onOpenCameras,
    required this.onOpenAlerts,
  });
  final bool isWide;
  final VoidCallback onOpenCameras;
  final VoidCallback onOpenAlerts;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _PageIntro(
        eyebrow: 'SYSTEM CONTROL',
        title: 'Farm network overview.',
        description:
            'A browser-friendly command center for your users, sensors, and camera access.',
        action: FilledButton.icon(
          onPressed: onOpenCameras,
          icon: const Icon(Icons.videocam_outlined),
          label: const Text('Review cameras'),
        ),
      ),
      const SizedBox(height: 23),
      LayoutBuilder(
        builder: (context, box) {
          final count = box.maxWidth > 850
              ? 4
              : box.maxWidth > 520
              ? 2
              : 1;
          return GridView.count(
            crossAxisCount: count,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 13,
            mainAxisSpacing: 13,
            childAspectRatio: count == 1 ? 3.4 : 1.65,
            children: const [
              _MetricCard(
                icon: Icons.people_alt_outlined,
                label: 'Farm users',
                value: '4',
                status: 'All accounts active',
                tint: Color(0xFF8C74F4),
              ),
              _MetricCard(
                icon: Icons.sensors_outlined,
                label: 'Sensors online',
                value: '3 / 4',
                status: '1 needs review',
                tint: Color(0xFF62C58C),
              ),
              _MetricCard(
                icon: Icons.videocam_outlined,
                label: 'Active cameras',
                value: '3',
                status: '2 AI streams enabled',
                tint: Color(0xFF60B8F7),
              ),
              _MetricCard(
                icon: Icons.forum_outlined,
                label: 'Open support',
                value: '1',
                status: 'Farmer One waiting',
                tint: Color(0xFFFFB657),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 24),
      LayoutBuilder(
        builder: (context, box) {
          final cards = [
            _AdminActionCard(
              icon: Icons.manage_accounts_outlined,
              title: 'User access',
              detail: 'Manage accounts and camera permissions.',
              action: 'Manage users',
              onTap: () {},
            ),
            _AdminActionCard(
              icon: Icons.warning_amber_rounded,
              title: 'System alerts',
              detail: 'Review warnings from every connected coop.',
              action: 'Open alerts',
              onTap: onOpenAlerts,
            ),
            _AdminActionCard(
              icon: Icons.settings_input_component_outlined,
              title: 'Browser compatibility',
              detail: 'Use HLS or HTTPS camera streams in this portal.',
              action: 'Read setup note',
              onTap: () => _showBrowserNote(context),
            ),
          ];
          return box.maxWidth < 760
              ? Column(
                  children: [
                    cards[0],
                    const SizedBox(height: 14),
                    cards[1],
                    const SizedBox(height: 14),
                    cards[2],
                  ],
                )
              : Row(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i < cards.length - 1) const SizedBox(width: 14),
                    ],
                  ],
                );
        },
      ),
    ],
  );
}

void _showBrowserNote(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Web camera support'),
      content: const Text(
        'Browsers cannot open RTSP or BLE devices directly. For live feeds, publish cameras through an HTTPS HLS/WebRTC gateway and keep the device connection service on your local network or backend.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.action,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String detail;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE86839).withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFE86839)),
          ),
          const SizedBox(height: 23),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(detail, style: TextStyle(color: _muted(context), height: 1.4)),
          const SizedBox(height: 15),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    ),
  );
}

class _CamerasPage extends StatelessWidget {
  const _CamerasPage({
    required this.cameras,
    required this.isWide,
    required this.onAdd,
    required this.onChanged,
  });
  final List<WebCamera> cameras;
  final bool isWide;
  final VoidCallback onAdd;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _PageIntro(
        eyebrow: 'LIVE MONITORING',
        title: 'Your camera network.',
        description:
            'View browser-compatible feeds and review AI behavior signals across the farm.',
        action: FilledButton.icon(
          onPressed: cameras.length >= 4 ? null : onAdd,
          icon: const Icon(Icons.add),
          label: Text(
            cameras.length >= 4 ? 'Camera limit reached' : 'Add camera',
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Web feeds use HLS, WebRTC, or HTTPS. RTSP remains available through the native Roostify app or a gateway.',
        style: TextStyle(color: _muted(context), fontSize: 12.5),
      ),
      const SizedBox(height: 21),
      LayoutBuilder(
        builder: (context, size) {
          final columns = size.maxWidth > 920 ? 2 : 1;
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: columns == 2 ? 1.55 : 1.4,
            children: cameras
                .map(
                  (camera) => _CameraCard(camera: camera, onChanged: onChanged),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.camera, required this.onChanged});
  final WebCamera camera;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final attention = camera.status == 'Attention';
    final connecting = camera.status == 'Connecting';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (connecting)
                  const ColoredBox(color: Color(0xFF202944))
                else
                  Image.asset(
                    attention
                        ? 'assets/chickens/abnormal_rooster.png'
                        : 'assets/chickens/healthy_rooster.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xFF202944)),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x800B1020),
                        Colors.transparent,
                        Color(0x950B1020),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  top: 13,
                  left: 13,
                  child: Row(
                    children: [
                      _LiveDot(active: !connecting),
                      const SizedBox(width: 7),
                      Text(
                        connecting ? 'CONNECTING' : 'LIVE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _Pill(
                    label: camera.status.toUpperCase(),
                    color: attention
                        ? const Color(0xFFFF705A)
                        : connecting
                        ? const Color(0xFF8C9ABE)
                        : const Color(0xFF3BC783),
                  ),
                ),
                if (!connecting && camera.aiEnabled && attention)
                  const Positioned(
                    left: 28,
                    bottom: 28,
                    child: _DetectionBox(),
                  ),
                if (connecting)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.link_rounded,
                          color: Color(0xFFB9C8F0),
                          size: 34,
                        ),
                        SizedBox(height: 7),
                        Text(
                          'Add a HLS / HTTPS feed to connect',
                          style: TextStyle(
                            color: Color(0xFFEAF0FF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 14, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camera.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        camera.location,
                        style: TextStyle(color: _muted(context), fontSize: 12),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        camera.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: attention
                              ? const Color(0xFFE86839)
                              : _muted(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Switch(
                      value: camera.aiEnabled,
                      onChanged: (_) {
                        camera.aiEnabled = !camera.aiEnabled;
                        onChanged();
                      },
                    ),
                    Text(
                      'AI',
                      style: TextStyle(
                        color: _muted(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
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
  }
}

class _AddCameraDialog extends StatefulWidget {
  const _AddCameraDialog({required this.onSave});
  final void Function(String name, String location) onSave;
  @override
  State<_AddCameraDialog> createState() => _AddCameraDialogState();
}

class _AddCameraDialogState extends State<_AddCameraDialog> {
  final _name = TextEditingController(text: 'Camera C');
  final _location = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add web camera'),
    content: SizedBox(
      width: 390,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Camera name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            decoration: const InputDecoration(
              labelText: 'Location',
              hintText: 'e.g. Brooder House',
            ),
          ),
          const SizedBox(height: 15),
          Text(
            'A feed URL can be configured after linking a browser-compatible HLS, WebRTC, or HTTPS camera gateway.',
            style: TextStyle(color: _muted(context), fontSize: 12, height: 1.4),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          widget.onSave(
            _name.text.trim().isEmpty ? 'New Camera' : _name.text.trim(),
            _location.text.trim().isEmpty
                ? 'Unassigned location'
                : _location.text.trim(),
          );
          Navigator.pop(context);
        },
        child: const Text('Add camera'),
      ),
    ],
  );
}

class _ScanPage extends StatefulWidget {
  const _ScanPage({required this.onAlertAdded});
  final VoidCallback onAlertAdded;
  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _analysed = false;
  bool _abnormal = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PageIntro(
        eyebrow: 'MANUAL AI CHECK',
        title: 'Inspect a rooster image.',
        description:
            'Use the native app for direct phone-camera scanning. This web screen demonstrates the same review workflow for images sent through your farm process.',
      ),
      const SizedBox(height: 23),
      LayoutBuilder(
        builder: (context, box) {
          final stack = box.maxWidth < 770;
          final capture = _ScanCapture(
            onRun: () => setState(() {
              _analysed = true;
              _abnormal = !_abnormal;
            }),
          );
          final result = _ScanResult(
            visible: _analysed,
            abnormal: _abnormal,
            onCreateAlert: widget.onAlertAdded,
          );
          return stack
              ? Column(children: [capture, const SizedBox(height: 18), result])
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: capture),
                    const SizedBox(width: 18),
                    Expanded(flex: 4, child: result),
                  ],
                );
        },
      ),
    ],
  );
}

class _ScanCapture extends StatelessWidget {
  const _ScanCapture({required this.onRun});
  final VoidCallback onRun;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.42,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/chickens/healthy_rooster.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFF202944)),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x480B1020), Color(0x960B1020)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 188,
                  height: 218,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'FRAME THE ROOSTER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 16,
                left: 16,
                child: _Pill(
                  label: 'WEB REVIEW MODE',
                  color: Color(0xFF5778CA),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(19),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Use the example image to preview a detection result.',
                  style: TextStyle(color: _muted(context)),
                ),
              ),
              FilledButton.icon(
                onPressed: onRun,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Run analysis'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ScanResult extends StatelessWidget {
  const _ScanResult({
    required this.visible,
    required this.abnormal,
    required this.onCreateAlert,
  });
  final bool visible;
  final bool abnormal;
  final VoidCallback onCreateAlert;
  @override
  Widget build(BuildContext context) {
    if (!visible)
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: _EmptyPanel(
            icon: Icons.query_stats_outlined,
            title: 'Ready for analysis',
            detail:
                'Run an analysis to see confidence and health posture results.',
          ),
        ),
      );
    final color = abnormal ? const Color(0xFFFF725C) : const Color(0xFF45C883);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analysis result',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 19),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                abnormal ? Icons.priority_high_rounded : Icons.check_rounded,
                color: color,
                size: 29,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              abnormal
                  ? 'Abnormal posture detected'
                  : 'Healthy posture detected',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              abnormal
                  ? 'The rooster may have sustained a head-down posture. Review it in person before taking action.'
                  : 'Movement and posture appear consistent with normal flock behavior.',
              style: TextStyle(color: _muted(context), height: 1.45),
            ),
            const SizedBox(height: 20),
            const _ConfidenceRow(label: 'Rooster confidence', value: .96),
            const SizedBox(height: 11),
            _ConfidenceRow(
              label: 'Posture confidence',
              value: abnormal ? .83 : .91,
              color: color,
            ),
            if (abnormal) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCreateAlert,
                  icon: const Icon(Icons.add_alert_outlined),
                  label: const Text('Create review alert'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConfidenceRow extends StatelessWidget {
  const _ConfidenceRow({
    required this.label,
    required this.value,
    this.color = const Color(0xFF45C883),
  });
  final String label;
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const Spacer(),
          Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
      const SizedBox(height: 7),
      LinearProgressIndicator(
        value: value,
        minHeight: 8,
        borderRadius: BorderRadius.circular(9),
        color: color,
        backgroundColor: color.withValues(alpha: .14),
      ),
    ],
  );
}

class _AlertsPage extends StatelessWidget {
  const _AlertsPage({
    required this.alerts,
    required this.onDismiss,
    required this.onRestore,
  });
  final List<WebAlert> alerts;
  final ValueChanged<WebAlert> onDismiss;
  final ValueChanged<WebAlert> onRestore;
  @override
  Widget build(BuildContext context) {
    final active = alerts.where((a) => !a.dismissed).toList();
    final handled = alerts.where((a) => a.dismissed).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageIntro(
          eyebrow: 'FARM ALERTS',
          title: 'Stay ahead of changes.',
          description: active.isEmpty
              ? 'No active alerts — your farm is all caught up.'
              : '${active.length} active ${active.length == 1 ? 'alert needs' : 'alerts need'} attention.',
        ),
        const SizedBox(height: 24),
        if (active.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(36),
              child: _EmptyPanel(
                icon: Icons.task_alt_rounded,
                title: 'All caught up',
                detail:
                    'New environmental, camera, and scan events will appear here.',
              ),
            ),
          )
        else
          ...active.map(
            (alert) => Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: _AlertDetailCard(
                alert: alert,
                actionLabel: 'Mark handled',
                onAction: () => onDismiss(alert),
              ),
            ),
          ),
        if (handled.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Handled alerts',
            style: TextStyle(
              color: _muted(context),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...handled.map(
            (alert) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AlertDetailCard(
                alert: alert,
                muted: true,
                actionLabel: 'Restore',
                onAction: () => onRestore(alert),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AlertDetailCard extends StatelessWidget {
  const _AlertDetailCard({
    required this.alert,
    required this.actionLabel,
    required this.onAction,
    this.muted = false,
  });
  final WebAlert alert;
  final String actionLabel;
  final VoidCallback onAction;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    final color = _severityColor(alert.severity);
    return Opacity(
      opacity: muted ? .63 : 1,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: LayoutBuilder(
            builder: (context, box) {
              final controls = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Pill(label: alert.severity.name.toUpperCase(), color: color),
                  const SizedBox(width: 10),
                  TextButton(onPressed: onAction, child: Text(actionLabel)),
                ],
              );
              final message = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(_severityIcon(alert.severity), color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          alert.detail,
                          style: TextStyle(color: _muted(context), height: 1.4),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          alert.time,
                          style: TextStyle(
                            color: _muted(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              return box.maxWidth < 620
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [message, const SizedBox(height: 12), controls],
                    )
                  : Row(
                      children: [
                        Expanded(child: message),
                        controls,
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }
}

class _GuidesPage extends StatelessWidget {
  const _GuidesPage();
  @override
  Widget build(BuildContext context) {
    const guides = [
      (
        Icons.psychology_outlined,
        'Understanding AI confidence',
        'Use posture confidence as a prompt for a real-world review, not a diagnosis.',
      ),
      (
        Icons.thermostat_outlined,
        'Environmental comfort ranges',
        'Learn which temperature, humidity, air, and lighting readings need attention.',
      ),
      (
        Icons.videocam_outlined,
        'Connect a camera for web viewing',
        'Publish camera video through HLS or WebRTC so modern browsers can display it.',
      ),
      (
        Icons.egg_alt_outlined,
        'Healthy flock behaviors',
        'Know the difference between normal foraging and patterns that warrant a closer look.',
      ),
      (
        Icons.sensors_outlined,
        'Set up an ESP32 sensor',
        'Connect the sensor using the Roostify mobile app, then review its data from the web.',
      ),
      (
        Icons.tune_outlined,
        'Alert preferences',
        'Decide what should trigger an in-app warning for each pen and camera.',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageIntro(
          eyebrow: 'ROOSTIFY GUIDES',
          title: 'Practical help for every check.',
          description:
              'Short, plain-language guides for using cameras, sensors, and AI observations responsibly.',
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth > 900
                ? 3
                : box.maxWidth > 570
                ? 2
                : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: columns == 1 ? 3.1 : 1.18,
              children: guides
                  .map(
                    (guide) => _GuideCard(
                      icon: guide.$1,
                      title: guide.$2,
                      detail: guide.$3,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(
            '$detail\n\nThe full guidance remains available in the native Roostify app while web documentation is connected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE86839).withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFE86839)),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 7),
            Text(
              detail,
              style: TextStyle(
                color: _muted(context),
                height: 1.4,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 13),
            const Row(
              children: [
                Text(
                  'Read guide',
                  style: TextStyle(
                    color: Color(0xFFE86839),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                Spacer(),
                Icon(Icons.arrow_forward, color: Color(0xFFE86839), size: 17),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ChatMessage {
  const _ChatMessage(this.sender, this.text, this.isSupport);
  final String sender;
  final String text;
  final bool isSupport;
}

class _SupportPage extends StatefulWidget {
  const _SupportPage({required this.messages, required this.onSend});
  final List<_ChatMessage> messages;
  final ValueChanged<String> onSend;
  @override
  State<_SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<_SupportPage> {
  final _composer = TextEditingController();
  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  void _send() {
    widget.onSend(_composer.text);
    _composer.clear();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PageIntro(
        eyebrow: 'SUPPORT CENTER',
        title: 'We are here to help.',
        description:
            'Ask about a sensor, a camera connection, or an alert. Your conversation stays attached to this farm workspace.',
      ),
      const SizedBox(height: 23),
      Card(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF8C74F4),
                      child: Icon(Icons.support_agent, color: Colors.white),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Roostify Support',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Typically responds within one business day',
                            style: TextStyle(
                              color: _muted(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const _Pill(label: 'OPEN', color: Color(0xFF3BC783)),
                  ],
                ),
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              Container(
                height: 350,
                padding: const EdgeInsets.all(18),
                child: ListView.separated(
                  itemCount: widget.messages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, index) =>
                      _ChatBubble(message: widget.messages[index]),
                ),
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _composer,
                        minLines: 1,
                        maxLines: 3,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Write a message…',
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    FilledButton(
                      onPressed: _send,
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(15),
                      ),
                      child: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final _ChatMessage message;
  @override
  Widget build(BuildContext context) {
    final mine = !message.isSupport;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.sender,
              style: TextStyle(
                color: _muted(context),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: mine
                    ? const Color(0xFFE86839)
                    : (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF252E4B)
                          : const Color(0xFFF0F2F7)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: mine ? Colors.white : null,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.isAdmin,
    required this.dark,
    required this.onThemeChanged,
    required this.onSignOut,
  });
  final bool isAdmin;
  final bool dark;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _PageIntro(
        eyebrow: 'YOUR PROFILE',
        title: isAdmin ? 'System Admin' : 'Farmer One',
        description: isAdmin
            ? 'Administrator account for the connected farm network.'
            : 'Manage the web workspace settings for your farm account.',
      ),
      const SizedBox(height: 23),
      LayoutBuilder(
        builder: (context, box) {
          final stack = box.maxWidth < 760;
          final identity = _ProfileIdentity(isAdmin: isAdmin);
          final settings = _WebSettings(
            dark: dark,
            onThemeChanged: onThemeChanged,
            onSignOut: onSignOut,
          );
          return stack
              ? Column(
                  children: [identity, const SizedBox(height: 17), settings],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: identity),
                    const SizedBox(width: 17),
                    Expanded(flex: 6, child: settings),
                  ],
                );
        },
      ),
    ],
  );
}

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({required this.isAdmin});
  final bool isAdmin;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 39,
            backgroundColor: isAdmin
                ? const Color(0xFF7557E9)
                : const Color(0xFFE86839),
            child: Icon(
              isAdmin
                  ? Icons.admin_panel_settings_outlined
                  : Icons.person_outline,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            isAdmin ? 'System Admin' : 'Farmer One',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            isAdmin ? 'Administrator' : 'Farm user · Main Pen',
            style: TextStyle(color: _muted(context)),
          ),
          const SizedBox(height: 23),
          const Divider(),
          const SizedBox(height: 13),
          _ProfileLine(
            icon: Icons.alternate_email,
            label: 'Username',
            value: isAdmin ? 'admin' : 'farmer1',
          ),
          const SizedBox(height: 14),
          const _ProfileLine(
            icon: Icons.verified_user_outlined,
            label: 'Web access',
            value: 'Enabled',
          ),
          const SizedBox(height: 14),
          const _ProfileLine(
            icon: Icons.language_outlined,
            label: 'Language',
            value: 'English',
          ),
        ],
      ),
    ),
  );
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: const Color(0xFFE86839), size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Text(label, style: TextStyle(color: _muted(context))),
      ),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ],
  );
}

class _WebSettings extends StatelessWidget {
  const _WebSettings({
    required this.dark,
    required this.onThemeChanged,
    required this.onSignOut,
  });
  final bool dark;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Web workspace settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'These preferences stay in your active browser session.',
            style: TextStyle(color: _muted(context)),
          ),
          const SizedBox(height: 18),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: dark,
            onChanged: onThemeChanged,
            title: const Text(
              'Dark appearance',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              'Use the low-light monitoring palette.',
              style: TextStyle(color: _muted(context)),
            ),
            secondary: const Icon(
              Icons.dark_mode_outlined,
              color: Color(0xFFE86839),
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFFE86839),
            ),
            title: const Text(
              'Browser notifications',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              'Connect notification permission when production alerts are enabled.',
              style: TextStyle(color: _muted(context)),
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, color: Color(0xFFE86839)),
            title: const Text(
              'Sign out from this workspace',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              'Return to the web sign-in page.',
              style: TextStyle(color: _muted(context)),
            ),
            trailing: TextButton(
              onPressed: onSignOut,
              child: const Text('Sign out'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE86839).withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFFE86839), size: 27),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 5),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted(context), height: 1.4),
        ),
      ],
    ),
  );
}
