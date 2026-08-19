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
                padding: const EdgeInsets.fromLTRB(20, 150, 20, 52),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _LandingLoginPanel(
                            onUserTap: () => _openLogin(context, UserRole.user),
                            onAdminTap: () =>
                                _openLogin(context, UserRole.admin),
                          ),
                          const SizedBox(height: 24),
                          GridView.count(
                            crossAxisCount: constraints.maxWidth < 430 ? 1 : 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: constraints.maxWidth < 430
                                ? 3.6
                                : 2.55,
                            children: const [
                              AppPill(
                                icon: Icons.sensors_outlined,
                                label: 'Live Environment',
                                subtitle: 'Real-time monitoring',
                              ),
                              AppPill(
                                icon: Icons.videocam_outlined,
                                label: 'YOLOv8 CCTV',
                                subtitle: 'AI camera monitoring',
                              ),
                              AppPill(
                                icon: Icons.camera_alt_outlined,
                                label: 'Phone Camera Scan',
                                subtitle: 'Scan & detect manually',
                              ),
                              AppPill(
                                icon: Icons.menu_book_outlined,
                                label: 'Care Guidelines',
                                subtitle: 'Best practices & tips',
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
  static const _loginOrange = Color(0xFFFF6A19);

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  late UserRole _selectedRole;
  String? _error;
  bool _signingInWithGoogle = false;
  bool _signingInWithPassword = false;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.expectedRole;
  }

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

  Future<void> _signInWithPassword() async {
    setState(() {
      _error = null;
      _signingInWithPassword = true;
    });

    final session = await widget.controller.signIn(
      username: _usernameController.text,
      password: _passwordController.text,
      expectedRole: _selectedRole,
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
      expectedRole: _selectedRole,
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

  Future<void> _showForgotPassword() async {
    var recoveryAccount = _usernameController.text.trim();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Forgot password?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your email or username. An administrator can then help '
              'you recover access to your Roostify account.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: recoveryAccount,
              onChanged: (value) => recoveryAccount = value,
              // Not autofocused: requesting focus while showDialog()'s
              // barrier + fade/scale entrance transition is still animating
              // races the keyboard's own show animation for frame budget,
              // which can drop the soft keyboard mid-word (see the same
              // fix on ProfileEditPage's dispose()).
              // Explicit label/icon color: the default (muted) input theme
              // color falls under the accessibility-minimum contrast ratio
              // against this dialog's tinted surface.
              decoration: InputDecoration(
                labelText: 'Email or Username',
                labelStyle: TextStyle(color: dialogContext.appColors.text),
                prefixIcon: Icon(
                  Icons.person_search_outlined,
                  color: dialogContext.appColors.text,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final account = recoveryAccount.trim();
              if (account.isEmpty) return;
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Recovery request prepared for $account. '
                    'Contact your administrator to reset the password.',
                  ),
                ),
              );
            },
            child: const Text('Request help'),
          ),
        ],
      ),
    );
  }

  void _showPolicy(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAdmin = _selectedRole == UserRole.admin;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF020713),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/login_background.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          const ColoredBox(color: Color(0x24000614)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = constraints.maxWidth > 584
                    ? 560.0
                    : constraints.maxWidth - 24;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  // Scrollable instead of FittedBox-scaled: FittedBox
                  // shrinks its child uniformly to fit, which was shrinking
                  // buttons/links below the 48dp accessibility minimum
                  // touch-target size on shorter screens. Scrolling keeps
                  // every control at its true declared size.
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: contentWidth,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Semantics(
                                image: true,
                                label: 'Roostify, Smart Rooster Monitoring',
                                child: Image.asset(
                                  'assets/roostify_logo_transparent.png',
                                  width: 180,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  20,
                                  20,
                                  18,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xE80A1221),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: _loginOrange,
                                    width: 1.4,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x66FF6A19),
                                      blurRadius: 22,
                                      spreadRadius: -7,
                                    ),
                                    BoxShadow(
                                      color: Color(0xB3000000),
                                      blurRadius: 36,
                                      offset: Offset(0, 18),
                                    ),
                                  ],
                                ),
                                child: Theme(
                                  data: buildAppTheme(Brightness.dark),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: _loginOrange,
                                                width: 1.4,
                                              ),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(9),
                                              child: Image.asset(
                                                'assets/roostify_logo_transparent.png',
                                                fit: BoxFit.cover,
                                                alignment: Alignment.topCenter,
                                                filterQuality:
                                                    FilterQuality.high,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isAdmin
                                                      ? l10n.loginAdminAccess
                                                      : l10n.loginTitle,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 23,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  l10n.loginSubtitle,
                                                  style: const TextStyle(
                                                    color: Color(0xFFADB3C1),
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      _DarkLoginField(
                                        controller: _usernameController,
                                        hintText: 'Email or Username',
                                        icon: Icons.person_outline_rounded,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                      ),
                                      const SizedBox(height: 8),
                                      _DarkLoginField(
                                        controller: _passwordController,
                                        hintText: l10n.loginPasswordLabel,
                                        icon: Icons.lock_outline_rounded,
                                        obscureText: !_passwordVisible,
                                        textInputAction: TextInputAction.done,
                                        onSubmitted: (_) =>
                                            _signingInWithPassword
                                            ? null
                                            : _signInWithPassword(),
                                        suffixIcon: IconButton(
                                          tooltip: _passwordVisible
                                              ? 'Hide password'
                                              : 'Show password',
                                          // Explicit constraints: the login
                                          // card is scaled down by the
                                          // surrounding FittedBox to fit small
                                          // screens, which shrank the default
                                          // 48x48 tap target just under the
                                          // accessibility minimum.
                                          constraints: const BoxConstraints(
                                            minWidth: 52,
                                            minHeight: 52,
                                          ),
                                          onPressed: () => setState(
                                            () => _passwordVisible =
                                                !_passwordVisible,
                                          ),
                                          icon: Icon(
                                            _passwordVisible
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: const Color(0xFFA7ADBA),
                                          ),
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            minimumSize: const Size(48, 52),
                                          ),
                                          onPressed: _showForgotPassword,
                                          child: const Text(
                                            'Forgot password?',
                                            style: TextStyle(
                                              color: _loginOrange,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_error != null) ...[
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0x663A1F2A),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFF9B4355),
                                            ),
                                          ),
                                          child: Text(
                                            _error!,
                                            style: const TextStyle(
                                              color: Color(0xFFFFA4AF),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      Semantics(
                                        button: true,
                                        // Distinct from the "Log in" card
                                        // heading above: identical speakable
                                        // text on a heading and a button
                                        // confuses screen-reader navigation.
                                        label: isAdmin
                                            ? 'Log in as administrator'
                                            : 'Log in to your account',
                                        excludeSemantics: true,
                                        onTap: _signingInWithPassword
                                            ? null
                                            : _signInWithPassword,
                                        child: SizedBox(
                                          height: 52,
                                          child: FilledButton.icon(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: _loginOrange,
                                              foregroundColor: Colors.white,
                                              shape: const StadiumBorder(),
                                            ),
                                            onPressed: _signingInWithPassword
                                                ? null
                                                : _signInWithPassword,
                                            icon: _signingInWithPassword
                                                ? const SizedBox.square(
                                                    dimension: 19,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons.login_rounded,
                                                  ),
                                            label: Text(
                                              _signingInWithPassword
                                                  ? l10n.loginSigningIn
                                                  : isAdmin
                                                  ? l10n.loginButtonAdmin
                                                  : l10n.loginButtonUser,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const _LoginDivider(),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        height: 52,
                                        child: FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: const Color(
                                              0xFF141820,
                                            ),
                                            shape: const StadiumBorder(),
                                          ),
                                          onPressed: _signingInWithGoogle
                                              ? null
                                              : _signInWithGoogle,
                                          icon: _signingInWithGoogle
                                              ? const SizedBox.square(
                                                  dimension: 19,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Color(
                                                          0xFF4285F4,
                                                        ),
                                                      ),
                                                )
                                              : const _GoogleMark(size: 22),
                                          label: Text(
                                            _signingInWithGoogle
                                                ? l10n.loginGoogleOpening
                                                : l10n.loginGoogleUser,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const _LoginDivider(),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        height: 52,
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: _loginOrange,
                                            side: BorderSide(
                                              color: isAdmin
                                                  ? Colors.white
                                                  : _loginOrange,
                                              width: 1.3,
                                            ),
                                            shape: const StadiumBorder(),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _selectedRole = isAdmin
                                                  ? UserRole.user
                                                  : UserRole.admin;
                                              _error = null;
                                            });
                                          },
                                          icon: Icon(
                                            isAdmin
                                                ? Icons.person_outline_rounded
                                                : Icons.shield_outlined,
                                          ),
                                          label: Text(
                                            isAdmin
                                                ? 'User Access'
                                                : 'Admin Access',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          const Text(
                                            'By continuing, you agree to our ',
                                            style: TextStyle(
                                              color: Color(0xFFA7ADBA),
                                              fontSize: 13,
                                            ),
                                          ),
                                          GestureDetector(
                                            // The button's visible text stays
                                            // small (matches the surrounding
                                            // legal copy), but its actual tap
                                            // target grows to the 48dp
                                            // accessibility minimum via the
                                            // invisible padding below.
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => _showPolicy(
                                              'Terms of Service',
                                              'Use Roostify responsibly and only with '
                                                  'cameras, sensors, and accounts you '
                                                  'are authorized to access.',
                                            ),
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                minHeight: 48,
                                              ),
                                              alignment: Alignment.center,
                                              child: const Text(
                                                'Terms of Service',
                                                style: TextStyle(
                                                  color: _loginOrange,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const Text(
                                            ' and ',
                                            style: TextStyle(
                                              color: Color(0xFFA7ADBA),
                                              fontSize: 13,
                                            ),
                                          ),
                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => _showPolicy(
                                              'Privacy Policy',
                                              'Roostify uses account information, '
                                                  'sensor readings, camera settings, '
                                                  'and recordings only to provide app '
                                                  'features and monitoring services.',
                                            ),
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                minHeight: 48,
                                              ),
                                              alignment: Alignment.center,
                                              child: const Text(
                                                'Privacy Policy.',
                                                style: TextStyle(
                                                  color: _loginOrange,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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
        ],
      ),
    );
  }
}

class _DarkLoginField extends StatelessWidget {
  const _DarkLoginField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onSubmitted,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        label: hintText,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          onSubmitted: onSubmitted,
          style: const TextStyle(color: Colors.white),
          cursorColor: _LoginPageState._loginOrange,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFFA7ADBA)),
            prefixIcon: Icon(icon, color: _LoginPageState._loginOrange),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xB30B1424),
            contentPadding: const EdgeInsets.symmetric(vertical: 19),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF384359)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: _LoginPageState._loginOrange,
                width: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginDivider extends StatelessWidget {
  const _LoginDivider();

  @override
  Widget build(BuildContext context) {
    // Purely decorative, and used twice on the same screen: with no way to
    // tell the two apart, a screen reader announcing "OR" at both is just
    // noise between buttons that already describe themselves.
    return const ExcludeSemantics(
      child: Row(
        children: [
          Expanded(child: Divider(color: Color(0xFF30394B))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text('OR', style: TextStyle(color: Color(0xFF858C9B))),
          ),
          Expanded(child: Divider(color: Color(0xFF30394B))),
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
    final l10n = AppLocalizations.of(context)!;

    if (widget.session.user.isAdmin) {
      return AdminRedesignShell(
        controller: widget.controller,
        session: widget.session,
      );
    }

    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: l10n.navDashboard,
      ),
      NavigationDestination(
        icon: const Icon(Icons.videocam_outlined),
        selectedIcon: const Icon(Icons.videocam),
        label: l10n.navCctv,
      ),
      NavigationDestination(
        icon: const Icon(Icons.camera_alt_outlined),
        selectedIcon: const Icon(Icons.camera_alt),
        label: l10n.navScan,
      ),
      NavigationDestination(
        icon: const Icon(Icons.menu_book_outlined),
        selectedIcon: const Icon(Icons.menu_book),
        label: l10n.navGuides,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: l10n.navProfile,
      ),
    ];

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        // Rebuilt on every controller notification (ESP32 sensor readings,
        // etc.) so the pages themselves pick up fresh data — building this
        // list outside the AnimatedBuilder would hand it the same widget
        // instances every time, which Flutter's element diffing treats as
        // identical and skips rebuilding.
        final pages = [
          UserDashboardPage(
            controller: widget.controller,
            session: widget.session,
          ),
          UserCctvPage(controller: widget.controller, session: widget.session),
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

        return Scaffold(
          body: pages[_index],
          floatingActionButton: _SupportChatBubble(
            controller: widget.controller,
            session: widget.session,
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: Theme(
            data: buildAppTheme(Theme.of(context).brightness),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: destinations,
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedAlertBell extends StatefulWidget {
  const _AnimatedAlertBell({required this.controller, required this.onPressed});

  final AppController controller;
  final VoidCallback onPressed;

  @override
  State<_AnimatedAlertBell> createState() => _AnimatedAlertBellState();
}

class _AnimatedAlertBellState extends State<_AnimatedAlertBell>
    with TickerProviderStateMixin {
  late final AnimationController _bellAnimationController;
  late final AnimationController _noticeAnimationController;
  StreamSubscription<AppAlertEvent>? _alertSubscription;
  Timer? _noticeTimer;
  AppAlertEvent? _visibleAlert;

  @override
  void initState() {
    super.initState();
    _bellAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _noticeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _listenForSensorAlerts();
  }

  @override
  void didUpdateWidget(covariant _AnimatedAlertBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      unawaited(_alertSubscription?.cancel());
      _listenForSensorAlerts();
    }
  }

  void _listenForSensorAlerts() {
    _alertSubscription = widget.controller.alertEvents
        .where((event) => event.category == 'sensor_alerts')
        .listen((event) {
          if (!mounted) return;
          setState(() => _visibleAlert = event);
          _bellAnimationController.forward(from: 0);
          _noticeAnimationController.forward(from: 0);
          _noticeTimer?.cancel();
          _noticeTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) _noticeAnimationController.reverse();
          });
        });
  }

  @override
  void dispose() {
    unawaited(_alertSubscription?.cancel());
    _noticeTimer?.cancel();
    _bellAnimationController.dispose();
    _noticeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alert = _visibleAlert;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.centerRight,
      children: [
        if (alert != null)
          Positioned(
            right: 56,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _noticeAnimationController,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0.12, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _noticeAnimationController,
                          curve: Curves.easeOutCubic,
                          reverseCurve: Curves.easeInCubic,
                        ),
                      ),
                  child: _BellAlertNotice(alert: alert),
                ),
              ),
            ),
          ),
        AnimatedBuilder(
          animation: _bellAnimationController,
          child: IconButton(
            tooltip: 'View alerts',
            onPressed: widget.onPressed,
            icon: Icon(
              Icons.notifications_none_rounded,
              color: context.appColors.text,
            ),
          ),
          builder: (context, child) {
            final progress = _bellAnimationController.value;
            final fade = 1 - progress;
            final rotation = math.sin(progress * math.pi * 8) * 0.18 * fade;
            final scale = 1 + (math.sin(progress * math.pi) * 0.16);
            return Transform.rotate(
              angle: rotation,
              child: Transform.scale(scale: scale, child: child),
            );
          },
        ),
      ],
    );
  }
}

class _BellAlertNotice extends StatelessWidget {
  const _BellAlertNotice({required this.alert});

  final AppAlertEvent alert;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final alertColor = alert.severity == AlertSeverity.danger
        ? colors.error
        : const Color(0xFFE09B26);

    return Material(
      color: colors.surfaceContainerHighest,
      elevation: 5,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: alertColor, width: 4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              alert.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              alert.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
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

    return Semantics(
      button: true,
      label: messageCount > 0
          ? 'Chat admin, $messageCount unread message${messageCount == 1 ? '' : 's'}'
          : 'Chat admin',
      excludeSemantics: true,
      child: Stack(
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
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
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
    final activeWarningCount = monitor.alerts
        .where((alert) => alert.severity != AlertSeverity.info)
        .length;
    unawaited(controller.maybeShowDailySummary(user.username));

    return Theme(
      data: buildAppTheme(Theme.of(context).brightness),
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 76,
          titleSpacing: 16,
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/app_icon_square.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Roostify',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Smart Rooster Monitoring',
                    style: TextStyle(
                      color: _appAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Semantics(
                label: activeWarningCount > 0
                    ? '$activeWarningCount active alerts. View alerts.'
                    : 'View alerts',
                button: true,
                excludeSemantics: true,
                child: Badge(
                  isLabelVisible: activeWarningCount > 0,
                  label: Text('$activeWarningCount'),
                  child: _AnimatedAlertBell(
                    controller: controller,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AlertsPage(alerts: monitor.alerts),
                        ),
                      );
                    },
                  ),
                ),
              ),
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
            final activeWarnings = activeWarningCount;
            final sensorOnline =
                controller.sensorConnectionStatus ==
                Esp32SensorConnectionStatus.connected;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FarmOverviewCard(
                    cctvCount: user.liveCctvStreams.length,
                    alertCount: activeWarnings,
                    sensorOnline: sensorOnline,
                  ),
                  const SizedBox(height: 22),
                  _DashboardSectionTitle(
                    title: 'Live Environment',
                    subtitle: 'Real-time environmental monitoring',
                    online: sensorOnline,
                  ),
                  const SizedBox(height: 12),
                  Esp32SensorConnectionCard(
                    controller: controller,
                    username: user.username,
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: constraints.maxWidth < 420 ? .44 : .6,
                        children: [
                          CircularSensorGauge(
                            title: 'Temperature',
                            value: monitor.dhtAvailable
                                ? monitor.temperature.toStringAsFixed(1)
                                : 'Offline',
                            unit: monitor.dhtAvailable ? '°C' : '',
                            progress: monitor.temperature / 45,
                            icon: Icons.thermostat_outlined,
                            status: monitor.dhtAvailable
                                ? monitor.temperatureStatus
                                : 'DHT sensor offline — check wiring',
                            level: monitor.temperatureLevel,
                            accent: const Color(0xFFFF453A),
                            alerts: temperatureAlerts,
                          ),
                          CircularSensorGauge(
                            title: 'Humidity',
                            value: monitor.dhtAvailable
                                ? monitor.humidity.toStringAsFixed(0)
                                : 'Offline',
                            unit: monitor.dhtAvailable ? '%' : '',
                            progress: monitor.humidity / 100,
                            icon: Icons.water_drop_outlined,
                            status: monitor.dhtAvailable
                                ? monitor.humidityStatus
                                : 'DHT sensor offline — check wiring',
                            level: monitor.humidityLevel,
                            accent: const Color(0xFF3B82F6),
                            alerts: humidityAlerts,
                          ),
                          CircularSensorGauge(
                            title: 'Air Pollution',
                            value: monitor.airAvailable
                                ? '${monitor.airPpm}'
                                : 'Offline',
                            unit: monitor.airAvailable ? 'ppm' : '',
                            progress: monitor.airPpm / 50,
                            icon: Icons.air_outlined,
                            status: monitor.airAvailable
                                ? monitor.airStatus
                                : 'MQ135 sensor offline — check wiring',
                            level: monitor.airLevel,
                            accent: const Color(0xFFFF7A00),
                            alerts: airAlerts,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
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
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color:
                                (activeWarnings == 0
                                        ? const Color(0xFF26C281)
                                        : _appAccent)
                                    .withValues(alpha: .12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            activeWarnings == 0
                                ? Icons.verified_user_outlined
                                : Icons.gpp_maybe_outlined,
                            size: 30,
                            color: activeWarnings == 0
                                ? const Color(0xFF26C281)
                                : _appAccent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            activeWarnings == 0
                                ? 'Farm conditions look safe. Tap a sensor card to see its details.'
                                : 'Tap a sensor card with a badge to see its warnings. The Guides tab explains each warning.',
                            style: TextStyle(
                              color: context.appColors.mutedText,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  AlertsPage(alerts: monitor.alerts),
                            ),
                          ),
                          icon: const Icon(Icons.chevron_right_rounded),
                          iconAlignment: IconAlignment.end,
                          label: Text(
                            activeWarnings == 0
                                ? 'ALL CLEAR'
                                : '$activeWarnings ACTIVE',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FarmOverviewCard extends StatelessWidget {
  const _FarmOverviewCard({
    required this.cctvCount,
    required this.alertCount,
    required this.sensorOnline,
  });
  final int cctvCount;
  final int alertCount;
  final bool sensorOnline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OverviewMetric(
            icon: Icons.videocam_outlined,
            value: '$cctvCount',
            label: 'CCTV Connect',
            detail: cctvCount == 1 ? 'Connected' : 'Connections',
            color: _appAccent,
            semanticLabel: cctvCount == 1
                ? 'CCTV Connect: 1 connection'
                : 'CCTV Connect: $cctvCount connections',
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _OverviewMetric(
            icon: Icons.memory_rounded,
            value: sensorOnline ? '1' : '0',
            label: 'ESP32 Sensor',
            detail: sensorOnline ? 'Online' : 'Offline',
            color: const Color(0xFF5E83FF),
            semanticLabel:
                'ESP32 Sensor: ${sensorOnline ? 'Online' : 'Offline'}',
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _OverviewMetric(
            icon: Icons.notifications_none_rounded,
            value: '$alertCount',
            label: 'Alerts',
            detail: 'Today',
            color: const Color(0xFFFF5252),
            semanticLabel: 'Alerts: $alertCount today',
          ),
        ),
      ],
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.detail,
    required this.color,
    required this.semanticLabel,
  });
  final IconData icon;
  final String value;
  final String label;
  final String detail;
  final Color color;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    excludeSemantics: true,
    child: Container(
      constraints: const BoxConstraints(minHeight: 166),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .38)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .11),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: .45)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 11),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 27),
          ),
          Text(
            detail,
            style: TextStyle(
              color: detail == 'Online'
                  ? const Color(0xFF26C281)
                  : context.appColors.mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
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
      Container(
        width: 4,
        height: 28,
        decoration: BoxDecoration(
          color: _appAccent,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: context.appColors.mutedText,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      if (online)
        Semantics(
          label: '$title: Online',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF23BF75).withValues(alpha: .1),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, color: Color(0xFF23BF75), size: 8),
                SizedBox(width: 6),
                Text(
                  'Online',
                  style: TextStyle(
                    color: Color(0xFF23BF75),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      if (!online)
        Semantics(
          label: '$title: Offline',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5252).withValues(alpha: .1),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, color: Color(0xFFFF5252), size: 8),
                SizedBox(width: 6),
                Text(
                  'Offline',
                  style: TextStyle(
                    color: Color(0xFFFF7777),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
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

  void _openCamera(
    BuildContext context,
    AppUser user,
    LiveCctvStream stream,
    int index,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CctvViewerPage(
          controller: controller,
          user: user,
          stream: stream,
          displayLabel: stream.label.isEmpty
              ? cctvStreamDisplayLabel(index, user.liveCctvStreams.length)
              : stream.label,
        ),
      ),
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
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
            children: [
              _CctvCameraCollection(
                streams: streams,
                onScan: () => _openManageCameras(context, user),
                onAdd: () => _openManageCameras(context, user),
                onView: (stream, index) =>
                    _openCamera(context, user, stream, index),
                onManage: () => _openManageCameras(context, user),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CctvCameraCollection extends StatelessWidget {
  const _CctvCameraCollection({
    required this.streams,
    required this.onScan,
    required this.onAdd,
    required this.onView,
    required this.onManage,
  });

  final List<LiveCctvStream> streams;
  final VoidCallback onScan;
  final VoidCallback onAdd;
  final void Function(LiveCctvStream stream, int index) onView;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Cameras',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Manage and monitor your CCTV cameras',
                      style: TextStyle(
                        color: context.appColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.outlined(
                tooltip: 'Scan camera',
                onPressed: onScan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
              ),
              const SizedBox(width: 7),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (streams.isEmpty)
            _CctvTabEmptyState(onManage: onAdd)
          else
            for (var index = 0; index < streams.length; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              _CctvCameraCard(
                stream: streams[index],
                index: index,
                total: streams.length,
                onView: () => onView(streams[index], index),
                onManage: onManage,
              ),
            ],
        ],
      ),
    );
  }
}

class _CctvCameraCard extends StatelessWidget {
  const _CctvCameraCard({
    required this.stream,
    required this.index,
    required this.total,
    required this.onView,
    required this.onManage,
  });

  final LiveCctvStream stream;
  final int index;
  final int total;
  final VoidCallback onView;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(stream.streamUrl);
    final label = stream.label.isEmpty
        ? cctvStreamDisplayLabel(index, total)
        : stream.label;
    final endpoint = uri?.host.isNotEmpty == true ? uri!.host : 'RTSP camera';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.appColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 112,
            height: 86,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF26354A), Color(0xFF0B111D)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(
                    Icons.videocam_outlined,
                    color: Colors.white54,
                    size: 34,
                  ),
                ),
                Positioned(
                  left: 7,
                  top: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF20B66A),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'Online',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Manage camera',
                      onPressed: onManage,
                      icon: const Icon(Icons.more_vert_rounded),
                    ),
                  ],
                ),
                Text(
                  'V380 Pro • CH${(index + 1).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: context.appColors.mutedText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  endpoint,
                  style: TextStyle(
                    color: context.appColors.mutedText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('View'),
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

class _CctvViewerPage extends StatelessWidget {
  const _CctvViewerPage({
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: .82),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayLabel),
            const Row(
              children: [
                Icon(Icons.circle, color: Color(0xFF26C281), size: 8),
                SizedBox(width: 5),
                Text(
                  'Live',
                  style: TextStyle(
                    color: Color(0xFF26C281),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: _CctvFeedTile(
          controller: controller,
          user: user,
          stream: stream,
          displayLabel: displayLabel,
        ),
      ),
    );
  }
}

class _CctvFeedTile extends StatelessWidget {
  const _CctvFeedTile({
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
      controller: controller,
      detections: stream.inspection.detections,
      onFrameReady: (frameBytes) {
        return controller.inspectCctvFrame(
          user.username,
          stream.id,
          frameBytes,
        );
      },
      onConnectionChanged: (online) {
        controller.markCctvConnectionStatus(user.username, stream.id, online);
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
        final query = _query.trim().toLowerCase();
        final guideItems = _redesignedGuides
            .where((item) => query.isEmpty || item.matches(query))
            .toList();

        return Theme(
          data: buildAppTheme(Theme.of(context).brightness),
          child: _RedesignedGuidesHome(
            controller: widget.controller,
            session: widget.session,
            searchController: _searchController,
            guides: guideItems,
            onSearchChanged: (value) => setState(() => _query = value),
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

// Retained for compatibility with the previous guide layout.
// ignore: unused_element
class _GuidesAboutCard extends StatelessWidget {
  const _GuidesAboutCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.appColors.border),
    ),
    child: Column(
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/app_icon_square.png',
                width: 78,
                height: 78,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Smart Rooster Farming Using IoT',
                    style: TextStyle(
                      color: _appAccent,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Roostify combines sensors, CCTV, AI detection, early warnings, and practical care guidance for a healthier rooster.',
                    style: TextStyle(
                      color: context.appColors.mutedText,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Row(
          children: [
            Expanded(
              child: _AboutFeature(
                icon: Icons.sensors_outlined,
                label: 'Real-time\nMonitoring',
                color: _appAccent,
              ),
            ),
            Expanded(
              child: _AboutFeature(
                icon: Icons.notifications_none_rounded,
                label: 'Smart Alerts',
                color: Color(0xFF26C281),
              ),
            ),
            Expanded(
              child: _AboutFeature(
                icon: Icons.psychology_outlined,
                label: 'AI Detection',
                color: Color(0xFFC94DFF),
              ),
            ),
            Expanded(
              child: _AboutFeature(
                icon: Icons.verified_user_outlined,
                label: 'Care Support',
                color: Color(0xFF4A9FF5),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _AboutFeature extends StatelessWidget {
  const _AboutFeature({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: color, size: 26),
      const SizedBox(height: 7),
      Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.appColors.mutedText, fontSize: 13),
      ),
    ],
  );
}

// Retained for compatibility with the previous guide layout.
// ignore: unused_element
class _GuidesSupportCard extends StatelessWidget {
  const _GuidesSupportCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.appColors.border),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: Color(0x22FF6A32),
          foregroundColor: _appAccent,
          child: Icon(Icons.lightbulb_outline_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Need help?\nContact our support team.',
            style: TextStyle(color: context.appColors.mutedText, height: 1.4),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.arrow_forward_rounded),
          iconAlignment: IconAlignment.end,
          label: const Text('Contact Support'),
        ),
      ],
    ),
  );
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
    title: 'Rooster Detection',
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

// Retained for compatibility with legacy deep-link guide content.
// ignore: unused_element
List<_GuideGridItem> get _guideGridItems => [
  _GuideGridItem.system(
    _systemBracketGuides[0],
    'Understand sensor readings, alerts, and environment monitoring.',
    Icons.device_thermostat_rounded,
    const Color(0xFFFF5570),
  ),
  _GuideGridItem.system(
    _systemBracketGuides[1],
    'Learn how CCTV works, setup, and live monitoring.',
    Icons.videocam_outlined,
    const Color(0xFFFF7A45),
  ),
  _GuideGridItem.system(
    _systemBracketGuides[2],
    'How detection works and confidence levels.',
    Icons.center_focus_strong_outlined,
    const Color(0xFFC94DFF),
  ),
  _GuideGridItem.system(
    _systemBracketGuides[3],
    'Normal vs abnormal postures and their meanings.',
    Icons.egg_alt_outlined,
    const Color(0xFF43D977),
  ),
  const _GuideGridItem.supplemental(
    'Breeding Guide',
    'How to breed healthy roosters and improve your rooster.',
    Icons.favorite_border_rounded,
    Color(0xFF4A9FF5),
    [
      (
        'Selecting a breeding rooster',
        'Choose active, healthy birds with good balance and a calm temperament.',
      ),
      (
        'Breeding setup',
        'Keep breeding areas clean, spacious, and supplied with fresh water and feed.',
      ),
      (
        'Egg care',
        'Collect eggs regularly and keep them clean and protected before incubation.',
      ),
    ],
  ),
  const _GuideGridItem.supplemental(
    'Care & Best Practices',
    'Daily care tips for a healthy rooster.',
    Icons.verified_user_outlined,
    Color(0xFFFFBE20),
    [
      (
        'Daily check',
        'Observe appetite, movement, droppings, and breathing every day.',
      ),
      (
        'Clean living space',
        'Remove waste, refresh bedding, and maintain dry, well-ventilated coops.',
      ),
      ('Food and water', 'Provide balanced feed and clean water at all times.'),
    ],
  ),
  const _GuideGridItem.supplemental(
    'Diseases & Prevention',
    'Common diseases, symptoms, and prevention methods.',
    Icons.health_and_safety_outlined,
    Color(0xFFFF5364),
    [
      (
        'Prevent spread',
        'Separate birds showing signs of illness from the rest of the roosters.',
      ),
      (
        'Keep records',
        'Track symptoms, treatments, and vaccinations for each rooster.',
      ),
      (
        'Ask a professional',
        'Contact a veterinarian when symptoms are severe or persistent.',
      ),
    ],
  ),
];

class _GuideGridItem {
  const _GuideGridItem.system(
    this.systemGuide,
    this.description,
    this.icon,
    this.color,
  ) : title = null,
      entries = null;
  const _GuideGridItem.supplemental(
    this.title,
    this.description,
    this.icon,
    this.color,
    this.entries,
  ) : systemGuide = null;
  final _SystemBracketGuide? systemGuide;
  final String? title;
  final String description;
  final IconData icon;
  final Color color;
  final List<(String, String)>? entries;
  String get label => systemGuide?.title ?? title!;
  bool matches(String query) =>
      label.toLowerCase().contains(query) ||
      description.toLowerCase().contains(query);
}

// Retained for compatibility with the previous guide grid.
// ignore: unused_element
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
        onTap: () {
          if (item.systemGuide != null && item.label != 'Rooster Detection') {
            _showGuideInfoDialog(context, item);
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => item.label == 'Rooster Detection'
                  ? const _ChickenStateGuidePage()
                  : _ActiveSupplementalGuidePage(item: item),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: item.color.withValues(alpha: .42)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: colors.mutedText),
                ],
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Text(
                  item.description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.mutedText,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showGuideInfoDialog(BuildContext context, _GuideGridItem item) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      backgroundColor: context.appColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: item.color.withValues(alpha: .65)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(item.icon, color: item.color, size: 32),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.label} Guide',
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style: TextStyle(
                            color: context.appColors.mutedText,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (title, explanation)
                        in item.systemGuide!.entries)
                      _GuideDialogEntry(
                        title: title,
                        explanation: explanation,
                        color: item.color,
                      ),
                    Container(
                      margin: const EdgeInsets.only(top: 4, bottom: 16),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: _appAccent.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _appAccent.withValues(alpha: .4),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            color: _appAccent,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tip: Keep equipment clean, readings visible, and camera views unobstructed.',
                              style: TextStyle(height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          _SystemBracketDetailPage(guide: item.systemGuide!),
                    ),
                  );
                },
                child: const Text('Learn more'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _GuideDialogEntry extends StatelessWidget {
  const _GuideDialogEntry({
    required this.title,
    required this.explanation,
    required this.color,
  });

  final String title;
  final String explanation;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.appColors.surfaceRaised,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.appColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Icons.auto_awesome_outlined, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                explanation,
                style: TextStyle(
                  color: context.appColors.mutedText,
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

class _ActiveSupplementalGuidePage extends StatelessWidget {
  const _ActiveSupplementalGuidePage({required this.item});

  final _GuideGridItem item;

  String get activeSection => switch (item.label) {
    'Breeding Guide' => 'Breeding Basics',
    'Care & Best Practices' => 'Daily Care',
    _ => 'Common Diseases',
  };

  List<(String, String, IconData)> get sections => switch (item.label) {
    'Breeding Guide' => const [
      (
        'Ideal Breeding Ratio',
        'Use 1 healthy rooster for every 8–12 hens to maintain fertility and reduce stress.',
        Icons.groups_outlined,
      ),
      (
        'Best Breeding Age',
        'Roosters are commonly ready at 8–12 months; hens at 6–8 months.',
        Icons.calendar_month_outlined,
      ),
      (
        'Signs of Readiness',
        'Choose active, healthy breeders with good body condition and natural behavior.',
        Icons.check_circle_outline_rounded,
      ),
      (
        'Important Reminders',
        'Provide quality feed, clean water, dry housing, and daily observation.',
        Icons.notifications_none_rounded,
      ),
    ],
    'Care & Best Practices' => const [
      (
        'Provide Clean Water',
        'Always supply fresh, clean water and check drinkers throughout the day.',
        Icons.water_drop_outlined,
      ),
      (
        'Balanced Feed',
        'Use high-quality feed with appropriate protein, vitamins, and minerals.',
        Icons.rice_bowl_outlined,
      ),
      (
        'Observe Behavior',
        'Check activity, appetite, posture, breathing, and social behavior daily.',
        Icons.visibility_outlined,
      ),
      (
        'Clean and Ventilate',
        'Keep housing dry, remove waste, reduce heat stress, and provide airflow.',
        Icons.cleaning_services_outlined,
      ),
      (
        'Record and Monitor',
        'Track health changes, treatments, breeding, and production.',
        Icons.assignment_outlined,
      ),
    ],
    _ => const [
      (
        'Coccidiosis',
        'Watch for diarrhea, weakness, and ruffled feathers. Keep housing clean and dry.',
        Icons.coronavirus_outlined,
      ),
      (
        'Infectious Coryza',
        'Look for facial swelling, discharge, and breathing difficulty. Improve ventilation.',
        Icons.sick_outlined,
      ),
      (
        'Fowl Pox',
        'Scabs may form on the comb or wattles. Control insects and isolate affected birds.',
        Icons.health_and_safety_outlined,
      ),
      (
        'Avian Influenza',
        'Sudden weakness, swelling, or breathing problems require immediate professional help.',
        Icons.warning_amber_rounded,
      ),
      (
        'External Parasites',
        'Inspect feathers and skin regularly and keep housing and equipment sanitary.',
        Icons.pest_control_outlined,
      ),
    ],
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(item.label)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        _GuidePageHero(item: item, activeSection: activeSection),
        const SizedBox(height: 16),
        for (final (title, text, icon) in sections)
          _ActiveGuideSectionCard(
            title: title,
            text: text,
            icon: icon,
            color: item.color,
          ),
        if (item.label == 'Breeding Guide')
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _BreedingTopicPage(
                    topic: 'Breeding Tips & Reminders',
                    icon: Icons.lightbulb_outline,
                  ),
                ),
              ),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('View Breeding Best Practices'),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: item.color.withValues(alpha: .4)),
          ),
          child: Text(
            item.label == 'Diseases & Prevention'
                ? 'Early detection, isolation, good hygiene, and veterinary support help prevent disease from spreading.'
                : 'Consistent daily care and good records improve rooster health and productivity.',
            style: const TextStyle(height: 1.45, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _GuidePageHero extends StatelessWidget {
  const _GuidePageHero({required this.item, required this.activeSection});
  final _GuideGridItem item;
  final String activeSection;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: item.color.withValues(alpha: .5)),
    ),
    child: Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(item.icon, color: item.color, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activeSection,
                style: TextStyle(
                  color: item.color,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.description,
                style: TextStyle(
                  color: context.appColors.mutedText,
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

class _ActiveGuideSectionCard extends StatelessWidget {
  const _ActiveGuideSectionCard({
    required this.title,
    required this.text,
    required this.icon,
    required this.color,
  });
  final String title;
  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 11),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.appColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                text,
                style: TextStyle(
                  color: context.appColors.mutedText,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
    if (Theme.of(context).useMaterial3) {
      return const _FunctionalChickenStateGuide();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Rooster Detection')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: const [
          _GuideModeTabs(),
          SizedBox(height: 14),
          _ChickenStateCard(
            title: 'Normal (Healthy)',
            description:
                'Roosters appear alert, balanced, and active with natural posture.',
            color: Color(0xFF26C281),
            cues: [
              'Standing upright',
              'Walking normally',
              'Foraging / scratching',
            ],
          ),
          SizedBox(height: 12),
          _ChickenStateCard(
            title: 'Abnormal (Needs Attention)',
            description:
                'Roosters show signs of discomfort, illness, or stress.',
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
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEEE9),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Text(
            'Posture-based State',
            style: TextStyle(
              color: _appAccent,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9F6),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Text(
            'Movement Cues',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ),
    ],
  );
}

class _ChickenStateCard extends StatelessWidget {
  const _ChickenStateCard({
    required this.title,
    required this.description,
    required this.color,
    required this.cues,
    this.note,
  });
  final String title;
  final String description;
  final Color color;
  final List<String> cues;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _appAccent.withValues(alpha: .58)),
        boxShadow: [
          BoxShadow(
            color: _appAccent.withValues(alpha: .08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 9),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(color: colors.mutedText, height: 1.45),
          ),
          const SizedBox(height: 15),
          for (final cue in cues)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    color == const Color(0xFF26C281)
                        ? Icons.check_box_rounded
                        : Icons.cancel_rounded,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(cue),
                ],
              ),
            ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              style: TextStyle(color: colors.mutedText, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

class _FunctionalChickenStateGuide extends StatefulWidget {
  const _FunctionalChickenStateGuide();
  @override
  State<_FunctionalChickenStateGuide> createState() =>
      _FunctionalChickenStateGuideState();
}

class _FunctionalChickenStateGuideState
    extends State<_FunctionalChickenStateGuide> {
  bool _movementCues = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final normal = _movementCues
        ? const ['Active walking', 'Smooth, even steps', 'Regular foraging']
        : const [
            'Standing upright',
            'Walking normally',
            'Foraging / scratching',
          ];
    final abnormal = _movementCues
        ? const ['Limping or dragging', 'Loss of balance', 'Repeated pacing']
        : const ['Weak balance', 'Abnormal stance', 'Repeated pacing'];
    return Scaffold(
      appBar: AppBar(title: const Text('Rooster Detection')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Row(
            children: [
              _StateTab(
                label: 'Posture-based State',
                selected: !_movementCues,
                onTap: () => setState(() => _movementCues = false),
              ),
              const SizedBox(width: 9),
              _StateTab(
                label: 'Movement Cues',
                selected: _movementCues,
                onTap: () => setState(() => _movementCues = true),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _FunctionalStateCard(
            title: 'Normal (Healthy)',
            description: _movementCues
                ? 'Healthy roosters move with purpose and stay engaged with their surroundings.'
                : 'Roosters appear alert, balanced, and active with natural posture.',
            color: const Color(0xFF26C281),
            cues: normal,
            imageAsset: 'assets/chickens/healthy_rooster.png',
          ),
          const SizedBox(height: 12),
          _FunctionalStateCard(
            title: 'Abnormal (Needs Attention)',
            description: _movementCues
                ? 'Unusual movement can point to injury, illness, pain, or stress.'
                : 'Roosters show signs of discomfort, illness, or stress.',
            color: const Color(0xFFFF4F3A),
            cues: abnormal,
            note: 'Inspect as soon as possible and provide proper care.',
            imageAsset: 'assets/chickens/abnormal_rooster.png',
          ),
          const SizedBox(height: 14),
          Text(
            _movementCues
                ? 'Watch a rooster over several moments before deciding a movement is abnormal.'
                : 'Posture is most useful when the full body is visible and the camera view is clear.',
            style: TextStyle(
              color: colors.mutedText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateTab extends StatelessWidget {
  const _StateTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Expanded(
      child: Material(
        color: selected
            ? _appAccent.withValues(alpha: .13)
            : colors.surfaceRaised,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? _appAccent : colors.mutedText,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FunctionalStateCard extends StatelessWidget {
  const _FunctionalStateCard({
    required this.title,
    required this.description,
    required this.color,
    required this.cues,
    this.note,
    this.imageAsset,
  });
  final String title;
  final String description;
  final Color color;
  final List<String> cues;
  final String? note;
  final String? imageAsset;
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final showImage =
        imageAsset != null && Theme.of(context).brightness == Brightness.light;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          description,
          style: TextStyle(color: colors.mutedText, height: 1.45),
        ),
        const SizedBox(height: 15),
        for (final cue in cues)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  color == const Color(0xFF26C281)
                      ? Icons.check_box_rounded
                      : Icons.cancel_rounded,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(cue, style: TextStyle(color: colors.text)),
                ),
              ],
            ),
          ),
        if (note != null)
          Text(note!, style: TextStyle(color: colors.mutedText, height: 1.45)),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(right: showImage ? 116 : 0),
            child: content,
          ),
          if (showImage)
            Positioned(
              right: -20,
              bottom: 0,
              child: SizedBox(
                width: 144,
                height: 138,
                child: Image.asset(imageAsset!, fit: BoxFit.contain),
              ),
            ),
        ],
      ),
    );
  }
}

class _BreedingTopicPage extends StatelessWidget {
  const _BreedingTopicPage({required this.topic, required this.icon});
  final String topic;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final details =
        _breedingTopicDetails[topic] ??
        const [
          'Keep birds healthy, comfortable, and under regular observation.',
          'Use clean housing, balanced feed, fresh water, and appropriate space.',
          'Ask a poultry professional for help with illness or persistent breeding issues.',
        ];
    return Scaffold(
      appBar: AppBar(title: Text(topic)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _appAccent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _appAccent),
          ),
          const SizedBox(height: 16),
          Text(
            'Practical guidance',
            style: TextStyle(
              color: colors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < details.length; index++)
            _BracketEntryCard(
              label: 'Step ${index + 1}',
              explanation: details[index],
            ),
        ],
      ),
    );
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
    'Separate breeding pens from the other roosters to control which birds mate and avoid stress.',
  ],
  'Mating Process': [
    'Introduce breeding birds gradually and watch for aggression during the first few days.',
    'Observe the roosters daily to ensure hens are not being over-mated or injured.',
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
    'Breeding closely related birds repeatedly, which can weaken the roosters over generations.',
    'Skipping quarantine for new breeding stock before introducing them to the roosters.',
    'Rushing the incubation or brooder setup instead of confirming stable temperature and humidity first.',
  ],
  'Breeding Tips & Reminders': [
    'Keep records of parent birds, hatch dates, health issues, and results to guide future pairings.',
    'Do not breed birds while they are sick, stressed, or under treatment.',
    'Prioritize bird health and welfare over rapid breeding results.',
    'Introduce new bloodlines occasionally to keep the roosters genetically healthy.',
    'Review past hatch outcomes each season and adjust nutrition, setup, or pairings as needed.',
  ],
};

class _SensorsGuidePage extends StatelessWidget {
  const _SensorsGuidePage();
  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).useMaterial3) return const _FunctionalSensorsGuide();
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(title: const Text('Sensors')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Environmental sensor explanations and safe levels.',
            style: TextStyle(color: colors.mutedText, height: 1.5),
          ),
          const SizedBox(height: 18),
          _SensorRangeCard(
            title: 'Temperature (°C)',
            icon: Icons.thermostat_outlined,
            color: const Color(0xFFFF6B55),
            ranges: const [
              (
                'OK\nNORMAL',
                '18 - 27 °C',
                'Comfortable for roosters.',
                Color(0xFF26C281),
              ),
              (
                '!\nCAUTION',
                '27 - 30 °C',
                'Start prevention.',
                Color(0xFFE5A52C),
              ),
              (
                '!\nDANGER',
                '> 30 °C',
                'Strong cooling needed.',
                Color(0xFFFF4F3A),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SensorCollapsedRow(
            title: 'Humidity (%)',
            icon: Icons.water_drop_outlined,
            color: const Color(0xFF3BB7E8),
          ),
          const SizedBox(height: 8),
          _SensorCollapsedRow(
            title: 'Air Pollution (ppm)',
            icon: Icons.air_outlined,
            color: const Color(0xFF4A9FF5),
          ),
          const SizedBox(height: 18),
          Text(
            'Tap any sensor to learn more about readings and recommendations.',
            style: TextStyle(
              color: colors.mutedText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorRangeCard extends StatelessWidget {
  const _SensorRangeCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.ranges,
  });
  final String title;
  final IconData icon;
  final Color color;
  final List<(String, String, String, Color)> ranges;
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 13),
          for (final (level, range, note, levelColor) in ranges)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 76,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: levelColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      level,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: levelColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          range,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          note,
                          style: TextStyle(
                            color: colors.mutedText,
                            fontSize: 13,
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

class _SensorCollapsedRow extends StatelessWidget {
  const _SensorCollapsedRow({
    required this.title,
    required this.icon,
    required this.color,
  });
  final String title;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.appColors.border),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Icon(
          Icons.keyboard_arrow_down_rounded,
          color: context.appColors.mutedText,
        ),
      ],
    ),
  );
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
          Text(
            'Environmental sensor explanations, safe levels, and recommended actions.',
            style: TextStyle(color: colors.mutedText, height: 1.5),
          ),
          const SizedBox(height: 18),
          const _FunctionalSensorGuideCard(
            title: 'Temperature (°C)',
            icon: Icons.thermostat_outlined,
            color: Color(0xFFFF6B55),
            summary: 'Comfort, heat-stress, and emergency temperature ranges.',
            ranges: [
              ('Normal', '18 - 26 °C', 'Good / comfortable'),
              ('Caution', '27 - 29 °C', 'Shade, water, and airflow'),
              ('Warning', '30 - 31 °C', 'Heat stress likely'),
              ('Danger', '32 °C+', 'Strong cooling needed'),
            ],
          ),
          const SizedBox(height: 10),
          const _FunctionalSensorGuideCard(
            title: 'Humidity (%)',
            icon: Icons.water_drop_outlined,
            color: Color(0xFF3BB7E8),
            summary: 'Relative humidity levels that affect cooling and dust.',
            ranges: [
              ('Normal', '45 - 70%', 'Good range'),
              ('Caution', '71 - 79%', 'Improve ventilation'),
              ('Warning', '80 - 89%', 'Risky, especially in heat'),
              ('Danger', '90%+', 'Very poor cooling condition'),
            ],
          ),
          const SizedBox(height: 10),
          const _FunctionalSensorGuideCard(
            title: 'Air Pollution (ppm)',
            icon: Icons.air_outlined,
            color: Color(0xFF4A9FF5),
            summary: 'Ammonia air-quality limits for the poultry area.',
            ranges: [
              ('Normal', '0 - 9 ppm', 'Good air'),
              ('Caution', '10 - 19 ppm', 'Improve ventilation'),
              ('Warning', '20 - 24 ppm', 'Air quality becoming unsafe'),
              ('Danger', '25+ ppm', 'Ventilate and clean immediately'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Tap a sensor to expand its reference chart and the action for each level.',
            style: TextStyle(
              color: colors.mutedText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _FunctionalSensorGuideCard extends StatelessWidget {
  const _FunctionalSensorGuideCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.summary,
    required this.ranges,
  });
  final String title;
  final IconData icon;
  final Color color;
  final String summary;
  final List<(String, String, String)> ranges;

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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.all(15),
            childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.mutedText,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            children: [
              for (final (level, range, action) in ranges)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 76,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          level,
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              range,
                              style: TextStyle(
                                color: colors.text,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              action,
                              style: TextStyle(
                                color: colors.mutedText,
                                fontSize: 13,
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
    if (guide.title == 'Rooster Detection') {
      return const _ChickenStateGuidePage();
    }
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
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final (label, explanation) in guide.entries)
            _BracketEntryCard(label: label, explanation: explanation),
          if (guide.title == 'Sensors') ...[
            const SizedBox(height: 8),
            const Text(
              'Sensor Warning Explanations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Warning levels explain when a reading needs closer monitoring or action.',
              style: TextStyle(color: colors.mutedText, height: 1.45),
            ),
            const SizedBox(height: 12),
            for (final warningGuide in _sensorWarningGuides)
              _SensorWarningGuideCard(guide: warningGuide),
          ],
          if (guide.title == 'Rooster Detection') ...[
            const SizedBox(height: 8),
            const _PostureGuideSection(
              title: 'Normal Postures (Healthy)',
              description:
                  'These postures indicate that the rooster appears healthy and behaves normally.',
              color: Color(0xFF26C281),
              entries: _normalPostureGuides,
            ),
            const SizedBox(height: 16),
            const _PostureGuideSection(
              title: 'Abnormal Postures (Possible Health Problems)',
              description:
                  'These postures may indicate illness, injury, weakness, or stress.',
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(
            explanation,
            style: TextStyle(color: colors.mutedText, height: 1.45),
          ),
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
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(color: colors.mutedText, height: 1.45),
        ),
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
        'Ventilate and clean immediately; ammonia at this level harms the roosters.',
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
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          advice,
                          style: TextStyle(
                            color: colors.mutedText,
                            fontSize: 13,
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
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meaning,
                  style: TextStyle(
                    color: colors.mutedText,
                    fontSize: 13,
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

  void _sendConcern() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    widget.controller.sendUserSupportMessage(
      username: widget.session.user.username,
      text: message,
    );
    _messageController.clear();
  }

  void _showFaq() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Frequently Asked Questions'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FaqEntry(
                question: 'Why is my CCTV offline?',
                answer:
                    'Check camera power, Wi-Fi, RTSP settings, and the camera address.',
              ),
              _FaqEntry(
                question: 'Why are sensor readings unavailable?',
                answer:
                    'Reconnect the ESP32 and confirm Bluetooth and sensor power are enabled.',
              ),
              _FaqEntry(
                question: 'How do I report a detection problem?',
                answer:
                    'Choose Report a Bug and describe the frame, lighting, and result.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

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
          appBar: AppBar(
            title: const Text('Help & Support'),
            leading: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Text(
                'Get assistance with the app, CCTV, sensors, or your account.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.mutedText, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: [
                    _SupportHubRow(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Live Chat with Admin',
                      subtitle: 'Chat with our support team',
                      onTap: () => _messageController.text =
                          'Hello, I need assistance from an admin.',
                    ),
                    _SupportHubRow(
                      icon: Icons.bug_report_outlined,
                      title: 'Report a Bug',
                      subtitle: 'Found something not working?',
                      onTap: () =>
                          _messageController.text = 'I encountered a bug: ',
                    ),
                    _SupportHubRow(
                      icon: Icons.sensors_outlined,
                      title: 'Sensor Issue',
                      subtitle: 'Having trouble with a sensor?',
                      onTap: () => _messageController.text =
                          'I need help with an ESP32 sensor: ',
                    ),
                    _SupportHubRow(
                      icon: Icons.videocam_outlined,
                      title: 'CCTV Concern',
                      subtitle: 'Issue with your CCTV or recordings?',
                      onTap: () => _messageController.text =
                          'I need help with CCTV or recordings: ',
                    ),
                    _SupportHubRow(
                      icon: Icons.person_outline_rounded,
                      title: 'Account Help',
                      subtitle: 'Login, profile, or account issues?',
                      onTap: () => _messageController.text =
                          'I need help with my account: ',
                    ),
                    _SupportHubRow(
                      icon: Icons.help_outline_rounded,
                      title: 'FAQ',
                      subtitle: 'Browse common questions',
                      onTap: _showFaq,
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.schedule_rounded, color: _appAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Typical response time: 5–10 minutes.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MergeSemantics(
                child: Semantics(
                  label: 'Describe your concern',
                  child: TextField(
                    controller: _messageController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Describe your concern...',
                      prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                      helperText: 'Our team will get back to you shortly.',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _sendConcern,
                  icon: const Icon(Icons.support_agent_rounded),
                  label: const Text('Contact Support'),
                ),
              ),
              if (thread != null && thread.messages.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'Recent Conversation',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                for (final message in thread.messages)
                  ChatBubble(
                    message: message,
                    mine: message.senderRole == UserRole.user,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SupportHubRow extends StatelessWidget {
  const _SupportHubRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.last = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: context.appColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _appAccent.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: _appAccent, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.appColors.mutedText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );
}

class _FaqEntry extends StatelessWidget {
  const _FaqEntry({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(
          answer,
          style: TextStyle(color: context.appColors.mutedText, height: 1.4),
        ),
      ],
    ),
  );
}

Future<void> _showProfileContentDialog(BuildContext context, Widget content) {
  final size = MediaQuery.sizeOf(context);
  return showDialog<void>(
    context: context,
    useSafeArea: true,
    barrierColor: Colors.black.withValues(alpha: .72),
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      clipBehavior: Clip.antiAlias,
      backgroundColor: context.appColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: _appAccent.withValues(alpha: .55)),
      ),
      child: SizedBox(
        width: math.min(size.width - 36, 620),
        height: math.min(size.height - 72, 780),
        child: content,
      ),
    ),
  );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.controller,
    required this.session,
  });

  final AppController controller;
  final Session session;

  Future<void> _confirmLogout(BuildContext context) async {
    var rememberDevice = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(color: _appAccent.withValues(alpha: .55)),
          ),
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Log Out?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(dialogContext).pop(false),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: _appAccent.withValues(alpha: .08),
                  shape: BoxShape.circle,
                  border: Border.all(color: _appAccent.withValues(alpha: .45)),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: _appAccent,
                  size: 40,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Are you sure you want to log out of your Roostify account on this device?',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.45),
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: rememberDevice,
                onChanged: (value) =>
                    setDialogState(() => rememberDevice = value ?? false),
                title: const Text(
                  'Remember this device',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Skip sign-in on this device next time.'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.appColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: context.appColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: _appAccent),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You can sign back in using your username, password, or connected Google account.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log Out'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (rememberDevice) {
      await controller.rememberThisDevice(
        session.user.username,
        session.user.role,
      );
    } else {
      await controller.forgetThisDevice();
    }
    await controller.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) =>
            LoginPage(controller: controller, expectedRole: session.user.role),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = controller.userByUsername(session.user.username)!;
    return Scaffold(
      appBar: user.isAdmin
          ? null
          : AppBar(
              toolbarHeight: 74,
              title: const Text(
                'Profile',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
              ),
              actions: [
                IconButton(
                  tooltip: 'App settings',
                  onPressed: () => _showProfileContentDialog(
                    context,
                    Scaffold(
                      appBar: AppBar(
                        title: const Text('App Settings'),
                        leading: IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                      body: ListView(
                        padding: const EdgeInsets.all(18),
                        children: [
                          ThemePreferenceCard(
                            controller: controller,
                            username: session.user.username,
                          ),
                        ],
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, user.isAdmin ? 18 : 8, 16, 88),
        children: [
          if (user.isAdmin)
            const _AdminPageHeader(
              title: 'Admin Profile',
              subtitle: 'Manage your account, preferences, and admin access.',
              icon: Icons.settings_outlined,
            ),
          _ProfileSummaryCard(
            controller: controller,
            user: user,
            session: session,
          ),
          const SizedBox(height: 18),
          _ProfileMenuGroup(
            children: [
              _ProfileMenuRow(
                icon: Icons.person_outline,
                label: 'My Information',
                onTap: () => _showProfileContentDialog(
                  context,
                  ProfileEditPage(controller: controller, user: user),
                ),
              ),
              _ProfileMenuRow(
                icon: Icons.key_outlined,
                label: 'Username & Password',
                onTap: () => _showProfileContentDialog(
                  context,
                  CredentialsEditPage(controller: controller, user: user),
                ),
              ),
              _ProfileMenuRow(
                icon: Icons.account_circle_outlined,
                label: 'Connected Accounts',
                trailing: const _GoogleMark(size: 24),
                onTap: () => _showProfileContentDialog(
                  context,
                  ConnectedAccountsPage(controller: controller),
                ),
              ),
              _ProfileMenuRow(
                icon: Icons.video_library_outlined,
                label: user.isAdmin ? 'All Recordings' : 'My Recordings',
                onTap: () => _showProfileContentDialog(
                  context,
                  RecordingsPage(currentUser: user),
                ),
              ),
              _ProfileMenuRow(
                icon: Icons.notifications_none_rounded,
                label: 'Notification Preferences',
                onTap: () => _showProfileContentDialog(
                  context,
                  const NotificationPreferencesPage(),
                ),
              ),
              _ProfileMenuRow(
                icon: Icons.settings_outlined,
                label: 'App Settings',
                onTap: () => _showProfileContentDialog(
                  context,
                  Scaffold(
                    appBar: AppBar(
                      title: const Text('App Settings'),
                      leading: IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                    body: ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        ThemePreferenceCard(
                          controller: controller,
                          username: session.user.username,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Admin's own support requests would create a self-addressed
              // thread that then shows up in their own Inbox tab; admins
              // handle user reports through the Inbox instead.
              if (!user.isAdmin)
                _ProfileMenuRow(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & Support',
                  onTap: () => _showProfileContentDialog(
                    context,
                    SupportChatPage(controller: controller, session: session),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 58,
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_outlined),
              label: const Text('Log out'),
            ),
          ),
        ],
      ),
      floatingActionButton: user.isAdmin
          ? null
          : FloatingActionButton(
              tooltip: 'Help and support',
              onPressed: () => _showProfileContentDialog(
                context,
                SupportChatPage(controller: controller, session: session),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
    );
  }
}

class ConnectedAccountsPage extends StatefulWidget {
  const ConnectedAccountsPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<ConnectedAccountsPage> createState() => _ConnectedAccountsPageState();
}

class _ConnectedAccountsPageState extends State<ConnectedAccountsPage> {
  bool _syncProfile = true;

  @override
  void initState() {
    super.initState();
    _loadSyncPreferences();
  }

  Future<void> _loadSyncPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _syncProfile = prefs.getBool('roostify.sync.profile') ?? true;
    });
  }

  Future<void> _saveAndClose() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('roostify.sync.profile', _syncProfile);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final session = widget.controller.session;
        final connected = session?.email != null;
        final colors = context.appColors;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Connected Accounts'),
            leading: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              const _ProfileSubpageIntro(
                icon: Icons.group_outlined,
                title: 'Connected Accounts',
                subtitle: 'Link or manage external sign-in accounts.',
              ),
              const SizedBox(height: 18),
              _ConnectedAccountCard(
                connected: connected,
                email: session?.email,
                onTap: () async {
                  if (connected) {
                    await widget.controller.unlinkGoogleAccount();
                    return;
                  }
                  final linked = await widget.controller.linkGoogleAccount();
                  if (!context.mounted || linked) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        widget.controller.lastError ??
                            'Could not connect Google.',
                      ),
                    ),
                  );
                },
              ),
              if (connected) ...[
                const SizedBox(height: 10),
                _SwitchConnectedAccountRow(
                  onTap: () async {
                    final linked = await widget.controller.linkGoogleAccount();
                    if (!context.mounted || linked) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          widget.controller.lastError ??
                              'Could not switch Google account.',
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 22),
              const Text(
                'Sync Permissions',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: SwitchListTile(
                  secondary: const Icon(
                    Icons.person_outline_rounded,
                    color: _appAccent,
                  ),
                  title: const Text(
                    'Sync profile information',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'When you sign in with Google, use its name for your '
                    'Roostify profile',
                  ),
                  value: _syncProfile,
                  onChanged: (value) => setState(() => _syncProfile = value),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _saveAndClose,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Connections'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectedAccountCard extends StatelessWidget {
  const _ConnectedAccountCard({
    required this.connected,
    required this.email,
    required this.onTap,
  });

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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              const _GoogleMark(size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (connected) ...[
                      const SizedBox(height: 3),
                      Text(
                        email!,
                        style: TextStyle(color: colors.mutedText, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Manage',
                        style: TextStyle(
                          color: _appAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 3),
                      Text(
                        'Not connected',
                        style: TextStyle(color: colors.mutedText, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              if (connected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF26C281).withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'Connected',
                    style: TextStyle(
                      color: Color(0xFF26C281),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded, color: colors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchConnectedAccountRow extends StatelessWidget {
  const _SwitchConnectedAccountRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.appColors.surface,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.appColors.border),
              ),
              child: const Icon(Icons.swap_horiz_rounded),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Switch Google account',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    // Roostify only keeps one linked Google account at a
                    // time; this replaces it rather than adding a second.
                    'Replace this with a different Google account',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});
  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  static const _prefix = 'roostify.notification.';
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 6, minute: 0);
  final Map<String, bool> _preferences = {
    for (final item in _notificationOptions) item.key: item.defaultValue,
  };

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final item in _notificationOptions) {
        _preferences[item.key] =
            prefs.getBool('$_prefix${item.key}') ?? item.defaultValue;
      }
      _quietStart = TimeOfDay(
        hour: prefs.getInt('${_prefix}quiet_start_hour') ?? 22,
        minute: prefs.getInt('${_prefix}quiet_start_minute') ?? 0,
      );
      _quietEnd = TimeOfDay(
        hour: prefs.getInt('${_prefix}quiet_end_hour') ?? 6,
        minute: prefs.getInt('${_prefix}quiet_end_minute') ?? 0,
      );
    });
  }

  Future<void> _setPreference(String key, bool value) async {
    setState(() => _preferences[key] = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$key', value);
  }

  Future<void> _pickQuietHours() async {
    final start = await showTimePicker(
      context: context,
      initialTime: _quietStart,
      helpText: 'Quiet hours start',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: _quietEnd,
      helpText: 'Quiet hours end',
    );
    if (end == null || !mounted) return;
    setState(() {
      _quietStart = start;
      _quietEnd = end;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_prefix}quiet_start_hour', start.hour);
    await prefs.setInt('${_prefix}quiet_start_minute', start.minute);
    await prefs.setInt('${_prefix}quiet_end_hour', end.hour);
    await prefs.setInt('${_prefix}quiet_end_minute', end.minute);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const _ProfileSubpageIntro(
            icon: Icons.notifications_none_rounded,
            title: 'Notification Preferences',
            subtitle: 'Choose which alerts and updates you want to receive.',
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                for (final item in _notificationOptions)
                  _NotificationOptionRow(
                    option: item,
                    value: _preferences[item.key]!,
                    enabled: true,
                    onChanged: (value) => _setPreference(item.key, value),
                  ),
                _QuietHoursRow(
                  value:
                      '${_quietStart.format(context)} – ${_quietEnd.format(context)}',
                  onTap: _pickQuietHours,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 19),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Critical alerts will still be delivered during quiet hours.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Preferences'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationOption {
  const _NotificationOption(
    this.key,
    this.label,
    this.description,
    this.icon,
    this.color, {
    this.defaultValue = true,
  });
  final String key;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final bool defaultValue;
}

const _notificationOptions = [
  _NotificationOption(
    'sensor_alerts',
    'Sensor Alerts',
    'Temperature, humidity, and air quality warnings',
    Icons.notifications_none_rounded,
    Color(0xFFFF5A3D),
  ),
  _NotificationOption(
    'cctv_offline',
    'CCTV Offline Alert',
    'Be notified when a camera disconnects',
    Icons.videocam_off_outlined,
    Color(0xFFFF5A3D),
  ),
  _NotificationOption(
    'recording_updates',
    'Recording Updates',
    'Saved clips and storage reminders',
    Icons.videocam_outlined,
    Color(0xFFFF5A3D),
    defaultValue: false,
  ),
  _NotificationOption(
    'daily_summary',
    'Daily Summary',
    'Get a daily farm monitoring summary',
    Icons.calendar_today_outlined,
    Color(0xFFFF5A3D),
  ),
  _NotificationOption(
    'sound_notifications',
    'Sound Notifications',
    'Play a sound for urgent alerts',
    Icons.volume_up_outlined,
    Color(0xFFFF5A3D),
  ),
  _NotificationOption(
    'vibration',
    'Vibration',
    'Vibrate on mobile alerts',
    Icons.vibration_rounded,
    Color(0xFFFF5A3D),
    defaultValue: false,
  ),
];

class _NotificationOptionRow extends StatelessWidget {
  const _NotificationOptionRow({
    required this.option,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final _NotificationOption option;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: .7)),
        ),
      ),
      child: SwitchListTile(
        secondary: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: option.color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(option.icon, color: option.color, size: 19),
        ),
        title: Text(
          option.label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          option.description,
          style: TextStyle(color: colors.mutedText, fontSize: 13),
        ),
        value: value,
        activeThumbColor: const Color(0xFF26C281),
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class _QuietHoursRow extends StatelessWidget {
  const _QuietHoursRow({required this.value, required this.onTap});
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _appAccent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: _appAccent,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Quiet Hours',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: context.appColors.mutedText, fontSize: 13),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 19),
        ],
      ),
    ),
  );
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({
    required this.controller,
    required this.user,
    required this.session,
  });

  final AppController controller;
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
                  border: Border.all(
                    color: _appAccent.withValues(alpha: .35),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: colors.accentSurface,
                  backgroundImage: user.avatarPath != null
                      ? FileImage(File(user.avatarPath!)) as ImageProvider
                      : session.photoUrl == null
                      ? null
                      : NetworkImage(session.photoUrl!),
                  child: user.avatarPath == null && session.photoUrl == null
                      ? Icon(
                          user.isAdmin
                              ? Icons.admin_panel_settings_outlined
                              : Icons.person_outline,
                          color: _appAccent,
                          size: 32,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      session.email ?? '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.mutedText, fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.isAdmin
                          ? 'Admin supervisor account'
                          : 'Backyard rooster farm user',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.subtleText, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit profile',
                onPressed: () => _showProfileContentDialog(
                  context,
                  ProfileEditPage(controller: controller, user: user),
                ),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 22),
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
  const _ProfileMenuRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
  });

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
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colors.border.withValues(alpha: .75)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _appAccent.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _appAccent.withValues(alpha: .18)),
                ),
                child: Icon(icon, color: _appAccent, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null)
                trailing!
              else
                Icon(Icons.chevron_right_rounded, color: colors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileEditorHero extends StatefulWidget {
  const _ProfileEditorHero({required this.controller, required this.user});

  final AppController controller;
  final AppUser user;

  @override
  State<_ProfileEditorHero> createState() => _ProfileEditorHeroState();
}

class _ProfileEditorHeroState extends State<_ProfileEditorHero> {
  bool _busy = false;

  Future<void> _pickPhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final documentsDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${documentsDir.path}/profile_photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final savedPath =
          '${photosDir.path}/${widget.user.username}${_extensionOf(picked.path)}';
      await File(picked.path).copy(savedPath);

      await widget.controller.updateProfilePhoto(
        widget.user.username,
        savedPath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update photo: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    return dot == -1 ? '.jpg' : path.substring(dot);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final avatarPath = user.avatarPath;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _appAccent.withValues(alpha: .42)),
      ),
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _appAccent.withValues(alpha: .08),
              border: Border.all(color: _appAccent.withValues(alpha: .52)),
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarPath == null
                ? const Icon(Icons.person_outline, color: _appAccent, size: 39)
                : Image.file(File(avatarPath), fit: BoxFit.cover),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user.username}',
                  style: TextStyle(color: context.appColors.mutedText),
                ),
                const SizedBox(height: 4),
                Text(
                  user.isAdmin
                      ? 'Admin supervisor account'
                      : 'Backyard rooster farm user',
                  style: TextStyle(
                    color: context.appColors.subtleText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit photo',
            onPressed: _busy ? null : _pickPhoto,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.camera_alt_outlined, color: _appAccent),
          ),
        ],
      ),
    );
  }
}

class _ProfileSubpageIntro extends StatelessWidget {
  const _ProfileSubpageIntro({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _appAccent.withValues(alpha: .35)),
    ),
    child: Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: _appAccent.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: _appAccent, size: 27),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.appColors.mutedText,
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

class _ProfileFormField extends StatelessWidget {
  const _ProfileFormField({
    required this.icon,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.readOnly = false,
    this.obscureText = false,
    this.prefixText,
    this.suffixIcon,
    this.onChanged,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool readOnly;
  final bool obscureText;
  final String? prefixText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              Icon(icon, color: _appAccent, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: MergeSemantics(
            child: Semantics(
              label: label,
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                readOnly: readOnly,
                obscureText: obscureText,
                onChanged: onChanged,
                decoration: InputDecoration(
                  prefixText: prefixText,
                  suffixIcon: suffixIcon,
                  filled: true,
                  fillColor: context.appColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: _appAccent.withValues(alpha: .75),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: _appAccent, width: 1.7),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: _appAccent.withValues(alpha: .35),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
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
  late final TextEditingController _usernameController = TextEditingController(
    text: widget.user.username,
  );
  late final TextEditingController _nameController = TextEditingController(
    text: widget.user.displayName,
  );
  late final TextEditingController _contactController = TextEditingController(
    text: widget.user.contactNumber
        .replaceFirst(RegExp(r'^\s*\+?63\s*'), '')
        .trim(),
  );
  late final TextEditingController _emailController = TextEditingController(
    text: widget.user.email.isEmpty
        ? '${widget.user.username}@roostify.com'
        : widget.user.email,
  );
  late final TextEditingController _farmNameController = TextEditingController(
    text: widget.user.farmName.isEmpty
        ? 'Roostify Rooster Farm'
        : widget.user.farmName,
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
    _usernameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _farmNameController.dispose();
    super.dispose();
  }

  void _persist() {
    final localNumber = _contactController.text
        .replaceFirst(RegExp(r'^\s*\+?63\s*'), '')
        .trim();
    widget.controller.updateProfileDetails(
      widget.user.username,
      displayName: _nameController.text,
      contactNumber: localNumber.isEmpty ? '' : '+63 $localNumber',
      address: widget.user.address,
      facebookContact: widget.user.facebookContact,
      email: _emailController.text,
      farmName: _farmNameController.text,
      shortBio: widget.user.shortBio,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Information'),
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _ProfileEditorHero(controller: widget.controller, user: widget.user),
          const SizedBox(height: 24),
          _ProfileFormField(
            icon: Icons.person_outline_rounded,
            label: 'Full Name',
            controller: _nameController,
          ),
          _ProfileFormField(
            icon: Icons.key_rounded,
            label: 'Username',
            controller: _usernameController,
            readOnly: true,
          ),
          _ProfileFormField(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          _ProfileFormField(
            icon: Icons.call_outlined,
            label: 'Contact Number',
            controller: _contactController,
            keyboardType: TextInputType.phone,
            prefixText: '+63 ',
          ),
          _ProfileFormField(
            icon: Icons.home_work_outlined,
            label: 'Farm Name',
            controller: _farmNameController,
          ),
          const SizedBox(height: 2),
          FilledButton.icon(
            onPressed: () {
              _persist();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile information saved.')),
              );
            },
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Save Changes'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              side: const BorderSide(color: _appAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.password});
  final String password;

  @override
  Widget build(BuildContext context) {
    final score =
        (password.length >= 8
            ? 2
            : password.isNotEmpty
            ? 1
            : 0) +
        (RegExp(r'[A-Za-z]').hasMatch(password) &&
                RegExp(r'[0-9]').hasMatch(password)
            ? 2
            : 0);
    final label = score >= 4
        ? 'Strong'
        : score >= 2
        ? 'Medium'
        : password.isEmpty
        ? '—'
        : 'Weak';
    final color = score >= 4
        ? const Color(0xFF26C281)
        : score >= 2
        ? const Color(0xFFE6B452)
        : const Color(0xFFFF6B72);
    return Padding(
      padding: const EdgeInsets.fromLTRB(33, 0, 8, 6),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Password Strength: ',
                style: TextStyle(
                  color: context.appColors.mutedText,
                  fontSize: 13,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: score / 4,
            minHeight: 4,
            borderRadius: BorderRadius.circular(99),
            color: color,
            backgroundColor: context.appColors.border,
          ),
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
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  late final TextEditingController _recoveryEmailController =
      TextEditingController(
        text: widget.user.email.isEmpty
            ? '${widget.user.username}@roostify.com'
            : widget.user.email,
      );
  String? _error;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    // Disposing from this page's own dispose() (rather than a
    // showDialog().whenComplete()-style callback) ties controller lifetime
    // to the page's actual removal, after its transition finishes — see the
    // same note on ProfileEditPage's dispose().
    _passwordController.dispose();
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _confirmPasswordController.dispose();
    _recoveryEmailController.dispose();
    super.dispose();
  }

  Future<void> _saveCredentials() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'New passwords do not match.');
      return;
    }
    final error = await widget.controller.updateCredentials(
      widget.user.username,
      newPassword: _passwordController.text,
      currentPassword: _currentPasswordController.text,
      recoveryEmail: _recoveryEmailController.text,
    );
    if (!mounted) return;
    setState(() => _error = error);
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username and password settings saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Username & Password'),
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const _ProfileSubpageIntro(
            icon: Icons.key_rounded,
            title: 'Username & Password',
            subtitle: 'Manage your login credentials securely.',
          ),
          const SizedBox(height: 24),
          _ProfileFormField(
            icon: Icons.person_outline_rounded,
            label: 'Current Username',
            controller: _usernameController,
            readOnly: true,
          ),
          _ProfileFormField(
            icon: Icons.lock_outline_rounded,
            label: 'Current Password',
            controller: _currentPasswordController,
            obscureText: !_showCurrentPassword,
            suffixIcon: IconButton(
              tooltip: _showCurrentPassword ? 'Hide password' : 'Show password',
              onPressed: () =>
                  setState(() => _showCurrentPassword = !_showCurrentPassword),
              icon: Icon(
                _showCurrentPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          _ProfileFormField(
            icon: Icons.lock_reset_rounded,
            label: 'New Password',
            controller: _passwordController,
            obscureText: !_showNewPassword,
            onChanged: (_) => setState(() {}),
            suffixIcon: IconButton(
              tooltip: _showNewPassword ? 'Hide password' : 'Show password',
              onPressed: () =>
                  setState(() => _showNewPassword = !_showNewPassword),
              icon: Icon(
                _showNewPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          _PasswordStrengthIndicator(password: _passwordController.text),
          const SizedBox(height: 10),
          _ProfileFormField(
            icon: Icons.lock_outline_rounded,
            label: 'Confirm New Password',
            controller: _confirmPasswordController,
            obscureText: !_showConfirmPassword,
            suffixIcon: IconButton(
              tooltip: _showConfirmPassword ? 'Hide password' : 'Show password',
              onPressed: () =>
                  setState(() => _showConfirmPassword = !_showConfirmPassword),
              icon: Icon(
                _showConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          _ProfileFormField(
            icon: Icons.mail_outline_rounded,
            label: 'Recovery Email',
            controller: _recoveryEmailController,
            keyboardType: TextInputType.emailAddress,
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
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: _saveCredentials,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Save Changes'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              side: const BorderSide(color: _appAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _appAccent.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _appAccent.withValues(alpha: .3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: _appAccent),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Security Tip: Use at least 8 characters with a mix of letters and numbers.',
                    style: TextStyle(height: 1.4),
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
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AdminPageHeader extends StatelessWidget {
  const _AdminPageHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 8, 2, 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.circle, color: _appAccent, size: 13),
            SizedBox(width: 8),
            Text(
              'ROOSTIFY',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 17),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: context.appColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appColors.border),
              ),
              child: Icon(icon, color: context.appColors.text),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          style: TextStyle(color: context.appColors.mutedText, height: 1.4),
        ),
      ],
    ),
  );
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
  bool _autoScanEnabled = true;
  bool _torchEnabled = false;
  int _cameraIndex = 0;
  String? _scanStatus;
  ManualScanResult? _result;

  @override
  void initState() {
    super.initState();
    unawaited(_setupCamera());
  }

  Future<void> _setupCamera({int? cameraIndex}) async {
    if (widget.controller.cameras.isEmpty) {
      setState(() => _initializing = false);
      unawaited(_runAnalysis());
      return;
    }

    final cameras = widget.controller.cameras;
    final preferredCamera = cameraIndex == null
        ? cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          )
        : cameras[cameraIndex % cameras.length];
    _cameraIndex = cameras.indexOf(preferredCamera);

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
    if (!_autoScanEnabled) return;
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
        _scanStatus = result.detected ? _statusForManualResult(result) : null;
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

  void _toggleAutoScan() {
    setState(() => _autoScanEnabled = !_autoScanEnabled);
    if (_autoScanEnabled) {
      _scheduleNextScan(immediate: true);
    } else {
      _autoScanTimer?.cancel();
    }
  }

  Future<void> _switchCamera() async {
    final cameras = widget.controller.cameras;
    if (cameras.length < 2 || _initializing) return;
    _autoScanTimer?.cancel();
    final oldController = _cameraController;
    setState(() {
      _initializing = true;
      _cameraController = null;
      _torchEnabled = false;
    });
    await oldController?.dispose();
    if (!mounted) return;
    await _setupCamera(cameraIndex: (_cameraIndex + 1) % cameras.length);
  }

  Future<void> _toggleTorch() async {
    final camera = _cameraController;
    if (camera == null || !camera.value.isInitialized) return;
    final next = !_torchEnabled;
    try {
      await camera.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torchEnabled = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Torch is unavailable on this camera.')),
        );
      }
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
    final detected = _result?.detected ?? false;
    final resultColor = _result?.condition == HealthState.abnormal
        ? HealthState.abnormal.color
        : const Color(0xFF43E39C);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 82,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual Rooster Scan',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 3),
            Text(
              'Point your camera to scan the area',
              style: TextStyle(color: Color(0xFF8E97A8), fontSize: 13),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton.icon(
              onPressed: _toggleAutoScan,
              icon: Icon(
                _autoScanEnabled
                    ? Icons.bolt_rounded
                    : Icons.pause_circle_outline_rounded,
              ),
              label: Text(_autoScanEnabled ? 'AUTO SCAN' : 'AUTO OFF'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          if (detected) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: _RoosterCountBadge(count: _result!.detectionCount),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ScanStatusCard(
                    icon: Icons.egg_alt_outlined,
                    label: _scanStatus!,
                    color: resultColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ScanStatusCard(
                    icon: Icons.speed_rounded,
                    label: 'Confidence ${_result!.confidenceLabel}',
                    color: resultColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Container(
            height: 470,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF070B13),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: context.appColors.border),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_initializing)
                  const Center(child: CircularProgressIndicator())
                else if (hasCamera) ...[
                  _buildFillingCameraPreview(_cameraController!),
                  IgnorePointer(
                    child: Semantics(
                      label: (_result?.detections ?? const []).isEmpty
                          ? null
                          : (_result?.detections ?? const [])
                                .map(
                                  (detection) =>
                                      '${detection.label} '
                                      '${(detection.confidence * 100).toStringAsFixed(0)}% '
                                      'confidence',
                                )
                                .join(', '),
                      child: CustomPaint(
                        painter: ChickenDetectionPainter(
                          detections: _result?.detections ?? const [],
                        ),
                      ),
                    ),
                  ),
                ] else
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Camera preview is unavailable on this device or emulator.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, height: 1.5),
                      ),
                    ),
                  ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 18,
                  child: Text(
                    detected
                        ? 'Keep the rooster clearly inside the frame'
                        : 'Bring the rooster into the frame for better detection',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _ScanTipsCard(),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ScanControlButton(
                icon: Icons.cameraswitch_outlined,
                label: 'Switch\nCamera',
                onTap: _switchCamera,
              ),
              _ScanNowButton(
                analyzing: _analyzing,
                onTap: _analyzing ? null : _runAnalysis,
              ),
              _ScanControlButton(
                icon: _torchEnabled
                    ? Icons.flashlight_on_rounded
                    : Icons.flashlight_off_rounded,
                label: _torchEnabled ? 'Torch\nOn' : 'Torch\nOff',
                onTap: _toggleTorch,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoosterCountBadge extends StatelessWidget {
  const _RoosterCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _appAccent.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _appAccent.withValues(alpha: .4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pets_rounded, color: _appAccent, size: 15),
          const SizedBox(width: 6),
          Text(
            count == 1 ? '1 rooster found' : '$count roosters found',
            style: const TextStyle(
              color: _appAccent,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanStatusCard extends StatelessWidget {
  const _ScanStatusCard({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: context.appColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanTipsCard extends StatelessWidget {
  const _ScanTipsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _appAccent.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: _appAccent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tips for better scan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                for (final tip in const [
                  'Ensure good lighting',
                  'Keep the rooster clearly visible',
                  'Avoid blur and obstructions',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_rounded,
                          color: _appAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            tip,
                            style: TextStyle(
                              color: context.appColors.mutedText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.egg_alt_outlined, color: _appAccent, size: 48),
        ],
      ),
    );
  }
}

class _ScanControlButton extends StatelessWidget {
  const _ScanControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 94,
        height: 76,
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 23),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: context.appColors.mutedText,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanNowButton extends StatelessWidget {
  const _ScanNowButton({required this.analyzing, required this.onTap});

  final bool analyzing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          color: _appAccent,
          shape: BoxShape.circle,
          border: Border.all(
            color: _appAccent.withValues(alpha: .35),
            width: 8,
          ),
          boxShadow: [
            BoxShadow(color: _appAccent.withValues(alpha: .22), blurRadius: 18),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            analyzing
                ? const SizedBox.square(
                    dimension: 26,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
            const SizedBox(height: 5),
            Text(
              analyzing ? 'SCANNING' : 'SCAN NOW',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
