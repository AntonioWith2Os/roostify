part of '../../main.dart';

class AppController extends ChangeNotifier {
  static const _requiredCctvHits = 2;
  static const _emptyCctvFramesBeforeClear = 2;
  static const maxLiveCctvStreams = 4;
  // The model has no memory of previous frames, so it flags "looking down"
  // as abnormal on every single frame regardless of how long it has lasted.
  // A rooster foraging briefly is normal; only a posture held continuously
  // past this threshold is treated as a real abnormal-behavior signal.
  static const _sustainedAbnormalThreshold = Duration(minutes: 5);

  AppController({required this.cameras})
    : _users = [
        AppUser(
          username: 'admin',
          displayName: 'System Admin',
          role: UserRole.admin,
          cameraAccessEnabled: false,
          monitor: MonitorSnapshot.empty(),
          cctvs: const [],
        ),
        AppUser(
          username: 'farmer1',
          displayName: 'Farmer One',
          role: UserRole.user,
          cameraAccessEnabled: true,
          monitor: MonitorSnapshot.sampleOne(),
          cctvs: const [
            CctvFeed(
              name: 'Camera A',
              location: 'Main Pen',
              status: HealthState.abnormal,
              online: true,
              note: 'Irregular pacing detected near feeder area.',
            ),
            CctvFeed(
              name: 'Camera B',
              location: 'Chick Zone',
              status: HealthState.normal,
              online: true,
              note: 'Chicks visible and resting normally.',
            ),
          ],
          liveCctvStreams: [
            LiveCctvStream(
              id: 'seed-camera-1',
              streamUrl: _exampleCloudPlaybackUrl,
              label: 'CCTV',
            ),
          ],
        ),
        AppUser(
          username: 'farmer2',
          displayName: 'Farmer Two',
          role: UserRole.user,
          cameraAccessEnabled: false,
          monitor: MonitorSnapshot.sampleTwo(),
          cctvs: const [
            CctvFeed(
              name: 'Camera A',
              location: 'Breeding Coop',
              status: HealthState.healthy,
              online: true,
              note: 'Movement and posture are stable.',
            ),
          ],
        ),
        AppUser(
          username: 'user1',
          displayName: 'User One',
          role: UserRole.user,
          cameraAccessEnabled: true,
          monitor: MonitorSnapshot.sampleOne(),
          cctvs: const [],
        ),
        AppUser(
          username: 'user2',
          displayName: 'User Two',
          role: UserRole.user,
          cameraAccessEnabled: true,
          monitor: MonitorSnapshot.sampleTwo(),
          cctvs: const [],
        ),
      ],
      _supportThreads = [
        SupportThread(
          id: 'thread-1',
          username: 'farmer1',
          resolved: false,
          messages: const [
            SupportMessage(
              senderRole: UserRole.user,
              text:
                  'The app warning appeared, and I need help checking if the sensor device is still connected.',
              timestamp: '10:15 AM',
            ),
            SupportMessage(
              senderRole: UserRole.admin,
              text:
                  'Check the power light first. We can schedule remote troubleshooting at 2:00 PM.',
              timestamp: '10:22 AM',
            ),
          ],
        ),
      ] {
    _sensorClient.addListener(notifyListeners);
    unawaited(_loadThemePreference());
    unawaited(_loadLanguagePreference());
    _persistedStateLoaded = _loadPersistedAccountsAndThreads();
  }

  Timer? _liveStatusTicker;

  /// MonitorSnapshot.isLive is a pure function of DateTime.now() versus the
  /// last reading's timestamp, but nothing re-evaluates it purely because
  /// time passed - notifyListeners() otherwise only fires when a new reading
  /// actually arrives. Without this, a sensor that goes silent never gets
  /// marked offline: the dashboard just keeps showing whatever was last
  /// rendered indefinitely, since nothing prompts it to check the clock
  /// again. Ticking well inside _liveThreshold keeps that a prompt reaction
  /// instead of an indefinite freeze.
  ///
  /// Deliberately opt-in rather than started from the constructor: this is
  /// a real, uncancelled Timer.periodic, and flutter_test's fake-async zone
  /// fails any test that ends with one still pending - which almost every
  /// test in this suite would, since most construct an AppController
  /// directly without ever mounting the real app shell that would dispose
  /// it. Only the actual app entry point (RoosterWatchApp) calls this.
  void startLiveStatusTicking() {
    if (_liveStatusTicker != null) return;
    _liveStatusTicker = Timer.periodic(
      const Duration(seconds: 3),
      (_) => notifyListeners(),
    );
  }

  final List<CameraDescription> cameras;
  final List<AppUser> _users;
  final List<SupportThread> _supportThreads;
  final Esp32ProvisioningClient _sensorClient = Esp32ProvisioningClient();
  final OnDeviceYoloDetector _yoloDetector = OnDeviceYoloDetector();
  final SupabaseBackendService _supabase = SupabaseBackendService();
  final Map<String, StreamSubscription<List<Map<String, dynamic>>>>
  _farmStatusSubscriptions = {};
  final Map<String, CctvInspectionResult> _cctvCandidates = {};
  final Map<String, int> _cctvCandidateHits = {};
  final PostureDurationTracker _postureDurationTracker = PostureDurationTracker(
    sustainedAbnormalThreshold: _sustainedAbnormalThreshold,
  );
  final Map<String, int> _cctvEmptyFrames = {};
  final StreamController<AppAlertEvent> _alertController =
      StreamController<AppAlertEvent>.broadcast();
  AppThemePreference _themePreference = AppThemePreference.light;
  Locale _languageLocale = const Locale('en');
  DateTime? _lastDailySummaryDate;
  String? lastError;
  Session? _session;
  int _streamIdCounter = 0;
  int _threadIdCounter = 0;

  // Resolves once accounts and support threads have been restored from disk.
  // Awaited by [restoreRememberedSession] so an auto-login can't run against
  // stale seed data while a previous session's edits are still loading.
  late final Future<void> _persistedStateLoaded;

  static const _notificationPrefsPrefix = 'roostify.notification.';
  static const _rememberUsernameKey = 'roostify.remember.username';
  static const _rememberRoleKey = 'roostify.remember.role';
  static const _accountsPrefKey = 'roostify.accounts';
  static const _supportThreadsPrefKey = 'roostify.support_threads';
  static const _tempPasswordLockDays = 7;

  List<AppUser> get farmUsers =>
      List.unmodifiable(_users.where((user) => !user.isAdmin));
  List<SupportThread> get supportThreads =>
      List.unmodifiable(_supportThreads.reversed);
  Session? get session => _session;
  int get totalCctvCount => farmUsers.fold<int>(
    0,
    (total, user) => total + user.liveCctvStreams.length,
  );
  int get openSupportCount =>
      _supportThreads.where((thread) => !thread.resolved).length;
  int get unreadSupportCount =>
      _supportThreads.where((thread) => thread.unreadByAdmin).length;

  /// BLE setup-link status - only meaningful while actively (re)configuring
  /// an environmental sensor's Wi-Fi. Not related to whether live sensor
  /// data is flowing; see [sensorOnline] for that.
  Esp32ProvisioningStatus get esp32SetupStatus => _sensorClient.status;
  String? get esp32SetupError => _sensorClient.lastError;
  List<DiscoveredEsp32Device> get discoveredEsp32Devices =>
      _sensorClient.discoveredDevices;
  bool get canConfigureSensorWifi => _sensorClient.canProvisionWifi;
  bool get isConfiguringSensorWifi => _sensorClient.isProvisioningWifi;
  String? get sensorWifiProvisioningStatus =>
      _sensorClient.wifiProvisioningStatus;

  /// True when the signed-in user's own farm has a recent reading posted by
  /// their ESP32 over Wi-Fi (see [MonitorSnapshot.isLive]).
  bool get sensorOnline => _session?.user.monitor.isLive ?? false;
  AppThemePreference get themePreference => _themePreference;
  Locale get languageLocale => _languageLocale;

  /// Fires whenever an event matches an enabled Notification Preference
  /// (and isn't muted by quiet hours), for the app shell to surface through
  /// its relevant in-app indicator, sound, or vibration.
  Stream<AppAlertEvent> get alertEvents => _alertController.stream;

  void setThemePreference(AppThemePreference preference) {
    if (_themePreference == preference) return;
    _themePreference = preference;
    notifyListeners();
    unawaited(_persistThemePreference(preference));
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('roostify.app.theme');
    final preference = AppThemePreference.values
        .where((item) => item.name == saved)
        .firstOrNull;
    if (preference == null || preference == _themePreference) return;
    _themePreference = preference;
    notifyListeners();
  }

  Future<void> _persistThemePreference(AppThemePreference preference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('roostify.app.theme', preference.name);
  }

  static const Map<String, Locale> _supportedLanguageLocales = {
    'English': Locale('en'),
    'Filipino': Locale('fil'),
  };

  /// Switches the app's display language. [languageName] is one of the
  /// entries offered by the Language settings picker ('English', 'Filipino').
  void setLanguage(String languageName) {
    final locale = _supportedLanguageLocales[languageName];
    if (locale == null || locale == _languageLocale) return;
    _languageLocale = locale;
    notifyListeners();
    unawaited(_persistLanguagePreference(languageName));
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('roostify.app.language');
    final locale = saved == null ? null : _supportedLanguageLocales[saved];
    if (locale == null || locale == _languageLocale) return;
    _languageLocale = locale;
    notifyListeners();
  }

  Future<void> _persistLanguagePreference(String languageName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('roostify.app.language', languageName);
  }

  /// Restores accounts (Add/Remove User, camera-access toggles, credential
  /// and profile edits) and support-thread state saved by a previous
  /// session. Without this, every admin write silently reverted to the
  /// hardcoded demo seed on the next app launch.
  Future<void> _loadPersistedAccountsAndThreads() async {
    final prefs = await SharedPreferences.getInstance();
    _applyPersistedAccounts(prefs);
    _applyPersistedSupportThreads(prefs);
    notifyListeners();
  }

  void _applyPersistedAccounts(SharedPreferences prefs) {
    final raw = prefs.getString(_accountsPrefKey);
    if (raw == null) return;

    try {
      final persisted = (jsonDecode(raw) as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();
      final persistedIds = persisted
          .map((json) => json['accountId'] as String)
          .toSet();

      // An account present in the seed but missing from persisted state was
      // removed by an admin in a previous session; drop it (never the admin
      // account itself, which is always seeded fresh and never persisted
      // out of existence).
      _users.removeWhere(
        (user) => !user.isAdmin && !persistedIds.contains(user.accountId),
      );

      for (final json in persisted) {
        final accountId = json['accountId'] as String;
        final existing = _users
            .where((user) => user.accountId == accountId)
            .firstOrNull;
        if (existing != null) {
          existing.applyAccountJson(json);
          continue;
        }

        // Created at runtime in a previous session (Add User or Google
        // sign-in) and isn't part of the hardcoded seed.
        final displayName =
            json['displayName'] as String? ?? json['username'] as String;
        _users.add(
          AppUser(
            accountId: accountId,
            username: json['username'] as String,
            displayName: displayName,
            role: UserRole.user,
            cameraAccessEnabled: true,
            monitor: MonitorSnapshot.newUser(displayName),
            cctvs: const [
              CctvFeed(
                name: 'Camera A',
                location: 'New Coop',
                status: HealthState.normal,
                online: false,
                note: 'Waiting for the first live feed connection.',
              ),
            ],
          )..applyAccountJson(json),
        );
      }
    } catch (_) {
      // Ignore corrupted persisted data; keep the in-memory seed.
    }
  }

  void _applyPersistedSupportThreads(SharedPreferences prefs) {
    final raw = prefs.getString(_supportThreadsPrefKey);
    if (raw == null) return;

    try {
      final threads = (jsonDecode(raw) as List<dynamic>)
          .map((item) => SupportThread.fromJson(item as Map<String, dynamic>))
          .toList();
      _supportThreads
        ..clear()
        ..addAll(threads);
    } catch (_) {
      // Ignore corrupted persisted data; keep the in-memory seed.
    }
  }

  Future<void> _persistAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _accountsPrefKey,
      jsonEncode(_users.map((user) => user.toAccountJson()).toList()),
    );
  }

  Future<void> _persistSupportThreads() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _supportThreadsPrefKey,
      jsonEncode(_supportThreads.map((thread) => thread.toJson()).toList()),
    );
  }

  /// Persists the currently signed-in [username]/[role] so the next app
  /// launch can skip straight back in, per the "Remember this device"
  /// checkbox shown when logging out. No password is stored.
  Future<void> rememberThisDevice(String username, UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberUsernameKey, username);
    await prefs.setString(_rememberRoleKey, role.name);
  }

  Future<void> forgetThisDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberUsernameKey);
    await prefs.remove(_rememberRoleKey);
  }

  /// Restores a session remembered via [rememberThisDevice] (set
  /// automatically on every successful sign-in — see [_openSupabaseSession]),
  /// if any. Called once at app startup, before falling back to the login
  /// screen.
  Future<Session?> restoreRememberedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_rememberUsernameKey);
    final roleName = prefs.getString(_rememberRoleKey);
    if (username == null || roleName == null) return null;

    final role = UserRole.values.where((r) => r.name == roleName).firstOrNull;
    if (role == null) return null;

    final supabaseUser = _supabase.currentUser;
    if (supabaseUser == null) return null;

    await _persistedStateLoaded;

    // A previous session already persisted this exact profile locally (see
    // _applyPersistedAccounts / _persistAccounts) — trust it and land on the
    // dashboard immediately instead of blocking on a fresh fetch. The
    // profile is still re-fetched, just in the background, to pick up
    // role/detail changes made elsewhere.
    final cachedUser = userByUsername(username);
    if (cachedUser != null && cachedUser.role == role) {
      lastError = null;
      _session = Session(user: cachedUser, email: supabaseUser.email);
      notifyListeners();

      // Every session needs this: a farmer's own farm status (their live
      // sensor data) as much as an admin's view across every farm.
      _listenToFarmStatuses();
      unawaited(_reconcileRememberedProfile(supabaseUser, username, role));
      return _session;
    }

    try {
      final data = await _supabase.profileFor(supabaseUser.id);
      if (data == null) return null;
      final user = _upsertProfile(supabaseUser.id, data);
      if (user.username != username || user.role != role) return null;

      lastError = null;
      _session = Session(
        user: userByUsername(user.username) ?? user,
        email: supabaseUser.email,
      );
      notifyListeners();

      // The admin farm-user list isn't needed to land on the dashboard, only
      // to populate it — fetch it in the background instead of making
      // startup wait through a second round trip on top of the profile
      // fetch above. A farmer session has no roster to load first, so its
      // own farm status can be listened to immediately.
      if (user.isAdmin) {
        unawaited(
          _loadUsersForAdmin().then((_) {
            _listenToFarmStatuses();
            notifyListeners();
          }),
        );
      } else {
        _listenToFarmStatuses();
      }

      return _session;
    } on PostgrestException {
      return null;
    }
  }

  /// Refreshes a remembered-session profile after the dashboard has already
  /// been shown from the locally cached copy (see
  /// [restoreRememberedSession]). Best-effort: a stale cache is corrected
  /// once this lands, and a network hiccup here just leaves the cached
  /// profile in place rather than disrupting an already-open session.
  Future<void> _reconcileRememberedProfile(
    User supabaseUser,
    String username,
    UserRole role,
  ) async {
    try {
      final data = await _supabase.profileFor(supabaseUser.id);
      if (data == null) return;
      final user = _upsertProfile(supabaseUser.id, data);
      if (user.username != username || user.role != role) return;

      if (user.isAdmin) {
        await _loadUsersForAdmin();
      }
      _listenToFarmStatuses();
      notifyListeners();
    } on PostgrestException {
      // Offline or a database hiccup — keep using the cached profile.
    }
  }

  /// Emits an [AppAlertEvent] for [category] if that Notification Preference
  /// toggle is enabled and the event isn't muted by quiet hours (danger-level
  /// events always get through, matching the "critical alerts still deliver
  /// during quiet hours" copy on the Notification Preferences page).
  Future<void> _maybeEmitAlert({
    required String category,
    required String title,
    required String message,
    AlertSeverity severity = AlertSeverity.info,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('$_notificationPrefsPrefix$category') ?? true;
    if (!enabled) return;
    if (severity != AlertSeverity.danger && _isWithinQuietHours(prefs)) {
      return;
    }
    if (_alertController.isClosed) return;

    _alertController.add(
      AppAlertEvent(
        category: category,
        title: title,
        message: message,
        severity: severity,
        playSound:
            prefs.getBool('${_notificationPrefsPrefix}sound_notifications') ??
            true,
        vibrate: prefs.getBool('${_notificationPrefsPrefix}vibration') ?? false,
      ),
    );
  }

  bool _isWithinQuietHours(SharedPreferences prefs) {
    final startHour = prefs.getInt(
      '${_notificationPrefsPrefix}quiet_start_hour',
    );
    final endHour = prefs.getInt('${_notificationPrefsPrefix}quiet_end_hour');
    if (startHour == null || endHour == null) {
      return false;
    }
    final startMinute =
        prefs.getInt('${_notificationPrefsPrefix}quiet_start_minute') ?? 0;
    final endMinute =
        prefs.getInt('${_notificationPrefsPrefix}quiet_end_minute') ?? 0;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;
    if (startMinutes == endMinutes) return false;

    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    return startMinutes < endMinutes
        ? nowMinutes >= startMinutes && nowMinutes < endMinutes
        : nowMinutes >= startMinutes || nowMinutes < endMinutes;
  }

  /// Shows a once-per-day farm summary alert, gated by the "Daily Summary"
  /// Notification Preference. Safe to call from every Dashboard build; the
  /// in-memory date guard makes repeat calls on the same day a no-op.
  Future<void> maybeShowDailySummary(String username) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_lastDailySummaryDate == today) return;

    final prefs = await SharedPreferences.getInstance();
    const dateKey = 'roostify.notification.daily_summary_date';
    final todayLabel = today.toIso8601String();
    if (prefs.getString(dateKey) == todayLabel) {
      _lastDailySummaryDate = today;
      return;
    }

    final user = userByUsername(username);
    if (user == null) return;
    _lastDailySummaryDate = today;
    await prefs.setString(dateKey, todayLabel);

    final monitor = user.monitor;
    await _maybeEmitAlert(
      category: 'daily_summary',
      title: 'Daily farm summary',
      message:
          'Temp ${monitor.temperature.toStringAsFixed(1)}°C · Humidity '
          '${monitor.humidity.toStringAsFixed(0)}% · Air ${monitor.airPpm} ppm. '
          '${monitor.cctvSummary}',
    );
  }

  /// Publishes a completed temporary clip to the recording server.
  ///
  /// Returns false when the upload fails. In that case the local file is kept
  /// so [RecordingServerService.retryPendingUploads] can safely retry later.
  Future<bool> publishRecording(String username, String path) async {
    final fileName = path.split(Platform.pathSeparator).last;
    try {
      await RecordingServerService.uploadRecording(
        sourcePath: path,
        ownerUsername: username,
      );
      await _maybeEmitAlert(
        category: 'recording_updates',
        title: 'Recording uploaded',
        message: 'Uploaded $fileName to your server Recordings library.',
      );
      return true;
    } catch (error) {
      lastError = 'Recording upload failed: $error';
      await _maybeEmitAlert(
        category: 'recording_updates',
        title: 'Recording upload pending',
        message: '$fileName is safe on this device and will retry later.',
        severity: AlertSeverity.warning,
      );
      return false;
    }
  }

  /// Searches for nearby environmental sensors over Bluetooth, populating
  /// [discoveredEsp32Devices] as they're found - see [connectToEsp32Device]
  /// for picking one to actually set up.
  Future<void> startEsp32Discovery() {
    return _sensorClient.startDiscovery();
  }

  Future<void> stopEsp32Discovery() {
    return _sensorClient.stopDiscovery();
  }

  /// Opens the BLE link used only to (re)configure a sensor - never to
  /// stream sensor data, which travels over Wi-Fi -> Supabase instead.
  Future<void> connectToEsp32Device(DiscoveredEsp32Device device) {
    return _sensorClient.connectToDevice(device);
  }

  Future<void> disconnectEsp32Setup() {
    return _sensorClient.disconnect();
  }

  /// Provisions the Wi-Fi network through the connected sensor's BLE setup
  /// characteristic. The device receives an account UID only when this is a
  /// real signed-in Supabase session; it remains a label, not a credential.
  Future<String> configureEsp32Wifi({
    required String username,
    required String ssid,
    required String password,
  }) {
    final user = userByUsername(username);
    if (user == null || user.isAdmin) {
      throw StateError('Sign in as a farmer before configuring a sensor.');
    }

    final ownerUid = _supabase.currentUser?.id == user.accountId
        ? user.accountId
        : null;
    return _sensorClient.provisionWifi(
      ssid: ssid,
      password: password,
      ownerUid: ownerUid,
    );
  }

  /// Wipes the sensor's saved Wi-Fi network, password, and owner UID over
  /// the already-open BLE setup link (see [connectToEsp32Device]).
  Future<String> forgetEsp32Wifi() {
    return _sensorClient.forgetWifi();
  }

  /// Nearby Wi-Fi network names as seen by the connected sensor itself.
  Future<List<String>> scanEsp32WifiNetworks() {
    return _sensorClient.scanWifiNetworks();
  }

  List<GuidelineItem> get guides => const [
    GuidelineItem(
      title: 'Daily Chick Check-Up',
      description:
          'Check if chicks are active, dry, eating properly, and not crowded in one hot or cold corner.',
      icon: Icons.health_and_safety_outlined,
    ),
    GuidelineItem(
      title: 'Rooster Breeding Basics',
      description:
          'Keep breeding pens clean, reduce stress, and separate weak birds early when abnormal movement appears.',
      icon: Icons.egg_alt_outlined,
    ),
    GuidelineItem(
      title: 'Environment Safety',
      description:
          'When heat, humidity, or air pollution rises, improve airflow, clean waste quickly, and ensure water is available.',
      icon: Icons.air_outlined,
    ),
    GuidelineItem(
      title: 'Observation Routine',
      description:
          'Use CCTV first, then switch to manual camera scan if the rooster is hidden, blurred, or hard to identify.',
      icon: Icons.visibility_outlined,
    ),
  ];

  Future<Session?> signIn({
    required String username,
    required String password,
    required UserRole expectedRole,
  }) async {
    final cleanUsername = username.trim();
    final cleanPassword = password.trim();
    if (cleanUsername.isEmpty || cleanPassword.isEmpty) {
      lastError = 'Enter your username and password.';
      notifyListeners();
      return null;
    }

    try {
      final credential = await _supabase.signInWithPassword(
        usernameOrEmail: cleanUsername,
        password: cleanPassword,
      );
      final supabaseUser = credential.user;
      if (supabaseUser == null) {
        throw const AuthException('Invalid username or password.');
      }
      final data = await _supabase.profileFor(supabaseUser.id);
      if (data == null) {
        await _supabase.signOut();
        lastError =
            'This account has no Roostify profile. Ask an administrator to provision it.';
        notifyListeners();
        return null;
      }

      final user = _upsertProfile(supabaseUser.id, data);
      if (user.role != expectedRole) {
        await _supabase.signOut();
        lastError = _roleMismatchMessage(expectedRole);
        notifyListeners();
        return null;
      }

      if (user.isAdmin) {
        await _loadUsersForAdmin();
      }
      _listenToFarmStatuses();
      return _openSupabaseSession(
        userByUsername(user.username) ?? user,
        supabaseUser,
      );
    } on AuthException catch (error) {
      lastError = _friendlyAuthError(error);
    } on PostgrestException catch (error) {
      lastError = error.message;
    } catch (_) {
      lastError = 'Unable to sign in. Check your connection and try again.';
    }
    notifyListeners();
    return null;
  }

  Session _openSupabaseSession(AppUser user, User supabaseUser) {
    lastError = null;
    _session = Session(user: user, email: supabaseUser.email);
    // Stay signed in across app restarts by default, the same as any other
    // mobile app — no separate opt-in needed. Explicit sign-out clears this.
    unawaited(rememberThisDevice(user.username, user.role));
    if (user.firstLoginAt == null) {
      user.firstLoginAt = DateTime.now();
      unawaited(_persistAccounts());
    }
    notifyListeners();
    return _session!;
  }

  String _roleMismatchMessage(UserRole expectedRole) {
    return expectedRole == UserRole.admin
        ? 'This account is not registered as an admin.'
        : 'This account is not registered as a user.';
  }

  String _friendlyAuthError(AuthException error) {
    // GoTrue's own message for wrong-password/unknown-email sign-in attempts
    // ("Invalid login credentials") is already fine as-is and has no
    // dedicated error code to switch on - only the cases below need
    // rewording.
    return switch (error.code) {
      'user_not_found' => 'Invalid username or password.',
      'user_banned' => 'This account has been disabled.',
      'over_request_rate_limit' =>
        'Too many sign-in attempts. Wait a moment and try again.',
      'session_expired' || 'session_not_found' =>
        'For security, sign out and sign in again before making this change.',
      _ => error.message,
    };
  }

  /// Edge Function errors (create/delete/reset-password) come back as an
  /// HTTP status with a JSON body `{"error": "message"}` — this unwraps that
  /// on the expected path and falls back to [fallback] for anything else
  /// (a network failure, an unexpected response shape, etc).
  String _friendlyFunctionError(FunctionException error, String fallback) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return error.reasonPhrase ?? fallback;
  }

  /// [data] uses the `profiles` table's `snake_case` column names.
  AppUser _upsertProfile(String uid, Map<String, dynamic> data) {
    final username = (data['username'] as String?)?.trim();
    final resolvedUsername = username == null || username.isEmpty
        ? 'user_${uid.substring(0, uid.length < 8 ? uid.length : 8)}'
        : username;
    final roleName = data['role'] as String?;
    final role = roleName == UserRole.admin.name
        ? UserRole.admin
        : UserRole.user;
    final index = _users.indexWhere(
      (user) => user.accountId == uid || user.username == resolvedUsername,
    );
    final previous = index < 0 ? null : _users[index];
    final displayName = (data['display_name'] as String?)?.trim();
    final user = AppUser(
      accountId: uid,
      username: resolvedUsername,
      displayName: displayName == null || displayName.isEmpty
          ? resolvedUsername
          : displayName,
      email: data['email'] as String? ?? '',
      contactNumber: data['contact_number'] as String? ?? '',
      address: data['address'] as String? ?? '',
      facebookContact: data['facebook_contact'] as String? ?? '',
      farmName: data['farm_name'] as String? ?? '',
      shortBio: data['short_bio'] as String? ?? '',
      avatarPath: previous?.avatarPath,
      firstLoginAt: previous?.firstLoginAt,
      tempPasswordIssued: previous?.tempPasswordIssued ?? false,
      role: role,
      cameraAccessEnabled:
          data['camera_access_enabled'] as bool? ?? role == UserRole.user,
      monitor:
          previous?.monitor ??
          (role == UserRole.admin
              ? MonitorSnapshot.empty()
              : MonitorSnapshot.newUser(
                  displayName == null || displayName.isEmpty
                      ? resolvedUsername
                      : displayName,
                )),
      cctvs: previous?.cctvs ?? const [],
      liveCctvStreams: previous?.liveCctvStreams,
    );
    if (index < 0) {
      _users.add(user);
    } else {
      _users[index] = user;
    }
    return user;
  }

  Future<void> _loadUsersForAdmin() async {
    final profiles = await _supabase.allUserProfiles();
    final remoteIds = <String>{};
    for (final profile in profiles) {
      final uid = profile['id'] as String?;
      if (uid == null || uid.isEmpty) continue;
      remoteIds.add(uid);
      _upsertProfile(uid, profile);
    }
    _users.removeWhere((user) => !remoteIds.contains(user.accountId));
  }

  /// True when temperature, humidity, or air quality is outside the
  /// "normal" range - the same per-metric level computation
  /// [MonitorSnapshot._environmentAlerts] uses to decide whether to raise an
  /// alert, reused here so [AppUser.sensorReadingLog] tracks exactly the
  /// readings that would actually be considered noteworthy.
  bool _isNotableReading(Esp32SensorReading reading) {
    final dhtNotable =
        reading.dhtAvailable &&
        (MonitorSnapshot.temperatureLevelFor(
                  reading.temperatureC,
                  humidity: reading.humidityPercent,
                ) !=
                SensorWarningLevel.normal ||
            MonitorSnapshot.humidityLevelFor(
                  reading.humidityPercent,
                  temperature: reading.temperatureC,
                ) !=
                SensorWarningLevel.normal);
    final airNotable =
        reading.airAvailable &&
        MonitorSnapshot.airLevelFor(reading.airQualityPpm) !=
            SensorWarningLevel.normal;
    return dhtNotable || airNotable;
  }

  /// Subscribes to `farm_status` for every farm user currently in memory -
  /// just the signed-in farmer's own farm for a farmer session, or every
  /// farm for an admin session (see the callers below). This is the only
  /// place live sensor data reaches the app: the ESP32 posts straight to
  /// Supabase over Wi-Fi, so there's nothing to listen to over Bluetooth.
  void _listenToFarmStatuses() {
    for (final subscription in _farmStatusSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _farmStatusSubscriptions.clear();

    for (final user in farmUsers) {
      _farmStatusSubscriptions[user.accountId] = _supabase
          .watchLatestSensor(user.accountId)
          .listen((rows) {
            if (rows.isEmpty) return;
            final data = rows.first;
            final temperature = data['temperature'];
            final humidity = data['humidity'];
            final airPpm = data['air_ppm'];
            if (temperature is! num || humidity is! num || airPpm is! num) {
              return;
            }
            final updatedAt = data['updated_at'];
            final previousAlerts = user.monitor.alerts;
            final reading = Esp32SensorReading(
              temperatureC: temperature.toDouble(),
              humidityPercent: humidity.toDouble(),
              airQualityPpm: airPpm.toInt(),
              dhtAvailable: data['dht_available'] as bool? ?? true,
              // The MQ135's raw-ADC-based availability heuristic
              // (airRaw > 0 && airRaw < 4095, see the sketch) turned out to
              // false-flag a genuinely working sensor - clean air can
              // legitimately read near the bottom of that range. Until
              // there's a more reliable way to detect a truly disconnected
              // MQ135, the app just trusts every airPpm value it receives
              // rather than gating it on what the firmware reported here.
              airAvailable: true,
              receivedAt: updatedAt is String
                  ? DateTime.parse(updatedAt)
                  : DateTime.now(),
            );
            user.monitor = user.monitor.withEnvironmentReading(reading);

            // Realtime can redeliver the same row (e.g. on reconnect)
            // without a new reading actually having arrived - skip logging
            // it again rather than showing a duplicate timestamp. Also skip
            // anything that isn't actually notable: the log is meant to
            // surface moments a threshold was crossed, not a redundant
            // entry every ~2 seconds while everything's fine.
            final log = user.sensorReadingLog;
            if (_isNotableReading(reading) &&
                (log.isEmpty || log.first.recordedAt != reading.receivedAt)) {
              log.insert(0, SensorReadingLogEntry.fromReading(reading));
              if (log.length > maxSensorReadingLogEntries) {
                log.removeRange(maxSensorReadingLogEntries, log.length);
              }
            }

            notifyListeners();

            // Notification preferences are per-device, not per-account, so
            // only ever alert on the signed-in user's own farm - otherwise
            // an admin watching every farm's status would be paged for
            // every farmer's environment warnings.
            if (user.accountId == _session?.user.accountId) {
              for (final alert in user.monitor.alerts) {
                final isNew = !previousAlerts.any(
                  (old) =>
                      old.title == alert.title &&
                      old.category == alert.category,
                );
                if (isNew && alert.severity != AlertSeverity.info) {
                  unawaited(
                    _maybeEmitAlert(
                      category: 'sensor_alerts',
                      title: alert.title,
                      message: alert.message,
                      severity: alert.severity,
                    ),
                  );
                }
              }
            }
          });
    }
  }

  /// This is only ever reached from an explicit "Log Out" action, so it
  /// always fully signs out — a session persists across app restarts on its
  /// own (see [_openSupabaseSession]), and this is what undoes that.
  Future<void> signOut() async {
    await forgetThisDevice();
    await _supabase.signOut();
    for (final subscription in _farmStatusSubscriptions.values) {
      await subscription.cancel();
    }
    _farmStatusSubscriptions.clear();
    _session = null;
    notifyListeners();
  }

  /// Updates [username]'s profile fields in one pass. Batching every field
  /// into a single notifyListeners() call (instead of one call per field)
  /// keeps the Profiles page's save action to one rebuild of the app shell
  /// rather than several back-to-back ones.
  void updateProfileDetails(
    String username, {
    required String displayName,
    required String contactNumber,
    required String address,
    required String facebookContact,
    required String email,
    required String farmName,
    required String shortBio,
  }) {
    final user = userByUsername(username);
    if (user == null) return;

    final cleanDisplayName = displayName.trim();
    if (cleanDisplayName.isNotEmpty) {
      user.displayName = cleanDisplayName;
    }
    user.contactNumber = contactNumber.trim();
    user.address = address.trim();
    user.facebookContact = facebookContact.trim();
    user.email = email.trim();
    user.farmName = farmName.trim();
    user.shortBio = shortBio.trim();

    notifyListeners();
    unawaited(_persistAccounts());
    if (_supabase.currentUser?.id == user.accountId ||
        _session?.user.isAdmin == true) {
      unawaited(_supabase.updateProfile(user));
    }
  }

  /// Sets [username]'s local profile photo to the file already saved at
  /// [avatarPath], deleting the previous photo file (if different) so picked
  /// photos don't accumulate on disk.
  Future<void> updateProfilePhoto(String username, String avatarPath) async {
    final user = userByUsername(username);
    if (user == null) return;

    final previousPath = user.avatarPath;
    user.avatarPath = avatarPath;
    notifyListeners();
    unawaited(_persistAccounts());

    if (previousPath != null && previousPath != avatarPath) {
      final previousFile = File(previousPath);
      if (await previousFile.exists()) {
        await previousFile.delete();
      }
    }
  }

  /// Changes [username]'s username and/or password after verifying
  /// [currentPassword]. Pass a null/blank [newUsername] or [newPassword] to
  /// leave that field unchanged. Returns null on success, or an error
  /// message to show the user.
  Future<String?> updateCredentials(
    String username, {
    String? newUsername,
    String? newPassword,
    String? recoveryEmail,
    required String currentPassword,
  }) async {
    final user = userByUsername(username);
    if (user == null) {
      return 'Account not found.';
    }

    final cleanUsername = newUsername?.trim();
    final cleanPassword = newPassword?.trim();
    final wantsUsernameChange =
        cleanUsername != null &&
        cleanUsername.isNotEmpty &&
        cleanUsername != user.username;
    final wantsPasswordChange =
        cleanPassword != null && cleanPassword.isNotEmpty;

    if (!wantsUsernameChange && !wantsPasswordChange) {
      return 'Enter a new username or password to update.';
    }

    if (wantsPasswordChange &&
        user.tempPasswordIssued &&
        user.firstLoginAt != null) {
      final unlocksAt = user.firstLoginAt!.add(
        const Duration(days: _tempPasswordLockDays),
      );
      if (DateTime.now().isBefore(unlocksAt)) {
        final unlocksLabel =
            '${unlocksAt.month}/${unlocksAt.day}/${unlocksAt.year}';
        return 'Your temporary password can be changed starting '
            '$unlocksLabel ($_tempPasswordLockDays days after your first '
            'login).';
      }
    }

    if (wantsUsernameChange &&
        _users.any((other) => other.username == cleanUsername)) {
      return 'That username is already taken.';
    }

    if (wantsUsernameChange) {
      return 'Username changes must be completed by an administrator.';
    }

    if (wantsPasswordChange) {
      try {
        await _supabase.updatePassword(
          currentPassword: currentPassword,
          newPassword: cleanPassword,
        );
      } on AuthException catch (error) {
        return _friendlyAuthError(error);
      }
    }
    if (recoveryEmail != null) {
      user.email = recoveryEmail.trim();
    }

    notifyListeners();
    unawaited(_persistAccounts());
    if (_supabase.currentUser?.id == user.accountId ||
        _session?.user.isAdmin == true) {
      unawaited(_supabase.updateProfile(user));
    }
    return null;
  }

  AppUser? userByUsername(String username) {
    for (final user in _users) {
      if (user.username == username) {
        return user;
      }
    }
    return null;
  }

  Future<bool> addUser({
    required String username,
    required String displayName,
    String email = '',
    String farmName = '',
    String contactNumber = '',
    String address = '',
    String password = 'Farm1234',
  }) async {
    final cleanUsername = username.trim();
    final cleanDisplayName = displayName.trim();

    if (cleanUsername.isEmpty || cleanDisplayName.isEmpty) {
      lastError = 'Display name and username are required.';
      notifyListeners();
      return false;
    }

    if (_users.any((user) => user.username == cleanUsername)) {
      lastError = 'That username already exists.';
      notifyListeners();
      return false;
    }

    if (_session?.user.isAdmin != true) {
      lastError = 'Sign in as an administrator to create users.';
      notifyListeners();
      return false;
    }

    try {
      final result = await _supabase.createUser(
        username: cleanUsername,
        displayName: cleanDisplayName,
        email: email.trim(),
        farmName: farmName.trim(),
        contactNumber: contactNumber.trim(),
        address: address.trim(),
        temporaryPassword: password.trim().isEmpty
            ? 'Farm1234'
            : password.trim(),
      );
      final uid = result['uid'] as String;
      final profile = Map<String, dynamic>.from(result['profile'] as Map);
      final user = _upsertProfile(uid, profile);
      user.tempPasswordIssued = true;
      lastError = null;
      notifyListeners();
      unawaited(_persistAccounts());
      _listenToFarmStatuses();
      return true;
    } on FunctionException catch (error) {
      lastError = _friendlyFunctionError(error, 'Unable to create the user.');
    } on PostgrestException catch (error) {
      lastError = error.message;
    }
    notifyListeners();
    return false;
  }

  Future<bool> removeUser(String username) async {
    final user = userByUsername(username);
    if (user == null || user.isAdmin) return false;
    try {
      await _supabase.deleteUser(user.accountId);
    } on FunctionException catch (error) {
      lastError = _friendlyFunctionError(error, 'Unable to remove the user.');
      notifyListeners();
      return false;
    }
    _users.removeWhere((user) => user.username == username && !user.isAdmin);
    _supportThreads.removeWhere((thread) => thread.username == username);
    _clearCctvFiltersForUser(username);
    notifyListeners();
    unawaited(_persistAccounts());
    unawaited(_persistSupportThreads());
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.remove(_liveCctvStreamsPrefKey(username)),
      ),
    );
    lastError = null;
    return true;
  }

  void toggleCameraAccess(String username) {
    final user = userByUsername(username);
    if (user == null || user.isAdmin) return;
    user.cameraAccessEnabled = !user.cameraAccessEnabled;
    notifyListeners();
    unawaited(_persistAccounts());
    unawaited(
      _supabase.updateCameraAccess(user.accountId, user.cameraAccessEnabled),
    );
  }

  /// Issues [username] a new temporary password on the admin's behalf, no
  /// current-password check required. Restarts the 7-day temp-password
  /// grace period tracked by [AppUser.firstLoginAt].
  Future<bool> adminResetPassword(String username, String newPassword) async {
    final user = userByUsername(username);
    final cleanPassword = newPassword.trim();
    if (user == null || user.isAdmin) {
      lastError = 'Account not found.';
      notifyListeners();
      return false;
    }
    if (cleanPassword.isEmpty) {
      lastError = 'Enter a temporary password.';
      notifyListeners();
      return false;
    }

    try {
      await _supabase.resetUserPassword(user.accountId, cleanPassword);
    } on FunctionException catch (error) {
      lastError = _friendlyFunctionError(
        error,
        'Unable to reset the password.',
      );
      notifyListeners();
      return false;
    }
    user.tempPasswordIssued = true;
    user.firstLoginAt = null;
    lastError = null;
    notifyListeners();
    unawaited(_persistAccounts());
    return true;
  }

  LiveCctvStream? _liveStreamById(AppUser user, String streamId) {
    for (final stream in user.liveCctvStreams) {
      if (stream.id == streamId) {
        return stream;
      }
    }
    return null;
  }

  String _generateStreamId() {
    _streamIdCounter += 1;
    return 'stream-${DateTime.now().microsecondsSinceEpoch}-$_streamIdCounter';
  }

  /// Adds a playback endpoint for [username]. Cloud endpoints are used by
  /// default; [allowDirectRtspCamera] permits a camera reached directly on the
  /// LAN, through a VPN, or through an existing router port-forward.
  bool addLiveCctvStream(
    String username,
    String streamUrl, {
    String? label,
    bool allowDirectRtspCamera = false,
  }) {
    final user = userByUsername(username);
    if (user == null || user.isAdmin) return false;

    final cleanStreamUrl = streamUrl.trim();
    final validationError =
        Uri.tryParse(cleanStreamUrl)?.scheme.toLowerCase() == 'v380'
        ? v380CloudCameraValidationError(cleanStreamUrl)
        : allowDirectRtspCamera
        ? directRtspCameraUrlValidationError(cleanStreamUrl)
        : cloudPlaybackUrlValidationError(cleanStreamUrl);
    if (validationError != null) {
      lastError = validationError;
      notifyListeners();
      return false;
    }

    if (user.liveCctvStreams.any(
      (stream) => stream.streamUrl == cleanStreamUrl,
    )) {
      lastError = 'That camera stream is already connected.';
      notifyListeners();
      return false;
    }

    if (user.liveCctvStreams.length >= maxLiveCctvStreams) {
      lastError =
          'Up to $maxLiveCctvStreams live cameras can be connected at once. Remove one to add another.';
      notifyListeners();
      return false;
    }

    user.liveCctvStreams.add(
      LiveCctvStream(
        id: _generateStreamId(),
        streamUrl: cleanStreamUrl,
        // Numbered display name is computed fresh wherever streams are
        // listed (see cctvStreamDisplayLabel), so it stays correct after
        // cameras are added/removed instead of going stale here.
        label: label?.trim().isNotEmpty == true ? label!.trim() : 'CCTV',
      ),
    );
    lastError = null;
    notifyListeners();
    unawaited(_persistLiveCctvStreams(user));
    return true;
  }

  void removeLiveCctvStream(String username, String streamId) {
    final user = userByUsername(username);
    if (user == null || user.isAdmin) return;

    final removed = user.liveCctvStreams
        .where((stream) => stream.id == streamId)
        .toList();
    user.liveCctvStreams.removeWhere((stream) => stream.id == streamId);
    for (final stream in removed) {
      unawaited(V380CloudBridgeRegistry.instance.stop(stream.streamUrl));
    }
    _clearCctvFilter(username, streamId);
    notifyListeners();
    unawaited(_persistLiveCctvStreams(user));
  }

  static String _liveCctvStreamsPrefKey(String username) =>
      'roostify.cctv_streams.$username';

  /// Persists [user]'s cloud and direct camera URLs across app restarts.
  ///
  /// Always writes, even when the list is empty: an explicit `[]` records
  /// that the user cleared their cameras, distinct from "never touched",
  /// which would otherwise fall back to the built-in demo seed camera again.
  Future<void> _persistLiveCctvStreams(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _liveCctvStreamsPrefKey(user.username),
      jsonEncode(
        user.liveCctvStreams.map((stream) => stream.toJson()).toList(),
      ),
    );
  }

  /// Restores every user's saved playback URLs from the previous app session.
  Future<void> loadPersistedLiveCctvStreams() async {
    final prefs = await SharedPreferences.getInstance();
    var restoredAny = false;

    for (final user in _users) {
      if (user.isAdmin) continue;

      final raw = prefs.getString(_liveCctvStreamsPrefKey(user.username));
      if (raw == null) continue;

      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final streams = decoded
            .map(
              (item) => LiveCctvStream.fromJson(item as Map<String, dynamic>),
            )
            .toList();
        user.liveCctvStreams
          ..clear()
          ..addAll(streams);
        restoredAny = true;
      } catch (_) {
        // Ignore corrupted persisted data for this user.
      }
    }

    if (restoredAny) {
      notifyListeners();
    }
  }

  void markCctvInspectionCapturing(String username, String streamId) {
    final user = userByUsername(username);
    final stream = user == null ? null : _liveStreamById(user, streamId);
    if (user == null || user.isAdmin || stream == null) {
      return;
    }

    stream.inspection = CctvInspectionResult.capturing();
  }

  void markCctvInspectionError(
    String username,
    String streamId,
    String message,
  ) {
    final user = userByUsername(username);
    final stream = user == null ? null : _liveStreamById(user, streamId);
    if (user == null || user.isAdmin || stream == null) {
      return;
    }

    stream.inspection = CctvInspectionResult.error(message);
    notifyListeners();
  }

  /// Tracks actual player connectivity separately from snapshot/YOLO health.
  /// A failed analysis frame must never label a playing camera as offline.
  void markCctvConnectionStatus(String username, String streamId, bool online) {
    final user = userByUsername(username);
    final stream = user == null ? null : _liveStreamById(user, streamId);
    if (user == null || user.isAdmin || stream == null) return;
    if (stream.isOnline == online) return;

    final wasOnline = stream.isOnline;
    stream.isOnline = online;
    notifyListeners();
    if (wasOnline && !online) {
      unawaited(
        _maybeEmitAlert(
          category: 'cctv_offline',
          title: 'CCTV camera disconnected',
          message: '${stream.label} lost its video connection.',
          severity: AlertSeverity.warning,
        ),
      );
    }
  }

  /// Actively checks how many of a user's configured cameras are currently
  /// reachable, independent of whether a [LiveFeedCard] happens to be
  /// mounted (which is the only thing that otherwise keeps
  /// [LiveCctvStream.isOnline] fresh). Used by the dashboard's CCTV summary
  /// so it reports real-time reachability rather than just a saved count.
  Future<int> countReachableCctvStreams(String username) async {
    final user = userByUsername(username);
    final streams = user?.liveCctvStreams ?? const <LiveCctvStream>[];
    if (streams.isEmpty) return 0;

    final results = await Future.wait(streams.map(_probeStreamReachable));
    return results.where((reachable) => reachable).length;
  }

  Future<bool> _probeStreamReachable(LiveCctvStream stream) async {
    if (kIsWeb) return stream.isOnline;

    final uri = Uri.tryParse(stream.streamUrl);
    if (uri == null || uri.host.isEmpty) return stream.isOnline;

    // A V380 Cloud camera has no directly dialable host/port — reaching it
    // requires the full cloud handshake in v380_cloud_bridge.dart, which is
    // too heavy for a lightweight dashboard check. If the on-device bridge
    // session is already running (started by a live view, but kept alive in
    // the background after it closes), its live status is a cheap read and
    // far fresher than stream.isOnline, which only ever reflects whatever was
    // true while that live view happened to be open. Only fall back to
    // stream.isOnline when the camera hasn't been opened at all this run.
    if (stream.deliveryProtocol == VideoDeliveryProtocol.v380Cloud) {
      final knownOnline = V380CloudBridgeRegistry.instance.isKnownOnline(
        stream.streamUrl,
      );
      return knownOnline ?? stream.isOnline;
    }

    final port = uri.hasPort ? uri.port : _defaultPortForScheme(uri.scheme);
    try {
      final socket = await Socket.connect(
        uri.host,
        port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  int _defaultPortForScheme(String scheme) => switch (scheme.toLowerCase()) {
    'rtsp' => 554,
    'rtsps' => 322,
    'rtmp' || 'rtmps' => 1935,
    'https' => 443,
    _ => 80,
  };

  Future<CctvInspectionResult?> inspectCctvFrame(
    String username,
    String streamId,
    Uint8List frameBytes,
  ) async {
    final user = userByUsername(username);
    final stream = user == null ? null : _liveStreamById(user, streamId);
    if (user == null || user.isAdmin || stream == null) {
      return null;
    }

    stream.inspection = CctvInspectionResult.inspecting();
    notifyListeners();

    try {
      final rawResult = await _yoloDetector.inspectFrame(frameBytes);
      final result = _confirmedCctvInspectionResult(
        username,
        streamId,
        rawResult,
      );
      final currentUser = userByUsername(username);
      final currentStream = currentUser == null
          ? null
          : _liveStreamById(currentUser, streamId);
      if (currentUser == null || currentUser.isAdmin || currentStream == null) {
        return null;
      }

      currentStream.inspection = result;
      notifyListeners();
      return result;
    } catch (error) {
      markCctvInspectionError(
        username,
        streamId,
        'Could not inspect the CCTV frame: $error',
      );
      return stream.inspection;
    }
  }

  CctvInspectionResult _confirmedCctvInspectionResult(
    String username,
    String streamId,
    CctvInspectionResult result,
  ) {
    final key = '$username::$streamId';
    final gated = _applyPostureDurationGate(key, result);

    if (!gated.detected) {
      _cctvCandidates.remove(key);
      _cctvCandidateHits.remove(key);
      final emptyFrames = (_cctvEmptyFrames[key] ?? 0) + 1;
      _cctvEmptyFrames[key] = emptyFrames;
      if (emptyFrames >= _emptyCctvFramesBeforeClear) {
        return gated;
      }
      final user = userByUsername(username);
      final stream = user == null ? null : _liveStreamById(user, streamId);
      return stream?.inspection ?? gated;
    }

    _cctvEmptyFrames[key] = 0;
    final candidate = _cctvCandidates[key];
    final hits =
        candidate != null &&
            _sameDetectedRooster(candidate.detections, gated.detections)
        ? (_cctvCandidateHits[key] ?? 1) + 1
        : 1;

    _cctvCandidates[key] = gated;
    _cctvCandidateHits[key] = hits;
    return hits >= _requiredCctvHits
        ? gated
        : CctvInspectionResult.inspecting();
  }

  /// Reclassifies [result] with [PostureDurationTracker], so a posture the
  /// model flags as abnormal only surfaces as abnormal once it has persisted
  /// for [_sustainedAbnormalThreshold]; shorter streaks read as normal. Fires
  /// a one-shot alert the moment a streak first crosses that threshold.
  CctvInspectionResult _applyPostureDurationGate(
    String key,
    CctvInspectionResult result,
  ) {
    if (!result.detected) {
      _postureDurationTracker.clear(key);
      return result;
    }

    final effectiveCondition = _postureDurationTracker.evaluate(
      key,
      result.condition,
    );

    if (_postureDurationTracker.consumeSustainedAlert(
      key,
      effectiveCondition,
    )) {
      unawaited(
        _maybeEmitAlert(
          category: 'sustained_abnormal_posture',
          title: 'Sustained abnormal posture detected',
          message:
              '${result.resultLabel} has held an abnormal posture for over '
              '${_sustainedAbnormalThreshold.inMinutes} minutes.',
          severity: AlertSeverity.warning,
        ),
      );
    }

    if (effectiveCondition == result.condition) {
      return result;
    }

    final gatedDetections = result.detections
        .map(
          (detection) => detection.condition == HealthState.abnormal
              ? ChickenDetection(
                  box: detection.box,
                  label: detection.label,
                  confidence: detection.confidence,
                  condition: effectiveCondition,
                )
              : detection,
        )
        .toList(growable: false);

    final abnormalCount = gatedDetections
        .where((detection) => detection.condition == HealthState.abnormal)
        .length;
    final resultLabel = abnormalCount > 0
        ? '$abnormalCount abnormal rooster${abnormalCount == 1 ? '' : 's'}'
        : '${gatedDetections.length} normal rooster${gatedDetections.length == 1 ? '' : 's'}';

    return CctvInspectionResult(
      state: result.state,
      resultLabel: resultLabel,
      confidenceLabel: result.confidenceLabel,
      message: result.message,
      inspectedAtLabel: result.inspectedAtLabel,
      condition: effectiveCondition,
      detected: result.detected,
      detectionCount: result.detectionCount,
      detections: gatedDetections,
    );
  }

  void _clearCctvFilter(String username, String streamId) {
    final key = '$username::$streamId';
    _cctvCandidates.remove(key);
    _cctvCandidateHits.remove(key);
    _cctvEmptyFrames.remove(key);
    _postureDurationTracker.clear(key);
  }

  void _clearCctvFiltersForUser(String username) {
    final prefix = '$username::';
    _cctvCandidates.removeWhere((key, _) => key.startsWith(prefix));
    _cctvCandidateHits.removeWhere((key, _) => key.startsWith(prefix));
    _postureDurationTracker.clearWhere((k) => k.startsWith(prefix));
    _cctvEmptyFrames.removeWhere((key, _) => key.startsWith(prefix));
  }

  Future<ManualScanResult> inspectManualFrame(
    String username,
    Uint8List frameBytes,
  ) async {
    final user = userByUsername(username);
    final monitor = user?.monitor ?? MonitorSnapshot.sampleOne();
    final result = await _yoloDetector.inspectFrame(frameBytes);
    return _manualResultFromInspection(result, monitor);
  }

  Future<ManualScanResult> inspectLiveCameraFrame(
    String username,
    LiveCameraFrame frame,
  ) async {
    final user = userByUsername(username);
    final monitor = user?.monitor ?? MonitorSnapshot.sampleOne();
    final result = await _yoloDetector.inspectCameraFrame(frame);
    return _manualResultFromInspection(result, monitor);
  }

  ManualScanResult _manualResultFromInspection(
    CctvInspectionResult result,
    MonitorSnapshot monitor,
  ) {
    final condition = result.condition;
    final movement = result.detected
        ? (result.condition == HealthState.abnormal
              ? 'Abnormal movement detected'
              : 'Normal movement')
        : 'No rooster detected';

    return ManualScanResult(
      condition: condition,
      breed: monitor.detectedBreed,
      movement: movement,
      confidenceLabel: result.confidenceLabel,
      detectionCount: result.detectionCount ?? 0,
      detections: result.detections,
      note: result.detected
          ? 'The on-device YOLOv8 model found ${result.detectionCount} rooster${result.detectionCount == 1 ? '' : 's'} in the phone camera frame.'
          : 'The live YOLOv8 model did not find a rooster in this phone camera frame.',
    );
  }

  SupportThread? threadForUser(String username) {
    for (final thread in _supportThreads.reversed) {
      if (thread.username == username) {
        return thread;
      }
    }
    return null;
  }

  SupportThread? threadById(String id) {
    for (final thread in _supportThreads) {
      if (thread.id == id) {
        return thread;
      }
    }
    return null;
  }

  void sendUserSupportMessage({
    required String username,
    required String text,
  }) {
    final clean = text.trim();
    if (clean.isEmpty) return;

    var thread = threadForUser(username);
    if (thread == null) {
      thread = SupportThread(
        id: _generateThreadId(),
        username: username,
        messages: [],
        resolved: false,
      );
      _supportThreads.add(thread);
    }

    thread.messages.add(
      SupportMessage(
        senderRole: UserRole.user,
        text: clean,
        timestamp: _timestampLabel(),
      ),
    );
    thread.resolved = false;
    thread.unreadByAdmin = true;
    notifyListeners();
    unawaited(_persistSupportThreads());
  }

  String _generateThreadId() {
    _threadIdCounter += 1;
    return 'thread-${DateTime.now().microsecondsSinceEpoch}-$_threadIdCounter';
  }

  void sendAdminSupportMessage({
    required String threadId,
    required String text,
  }) {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final thread = threadById(threadId);
    if (thread == null) return;

    thread.messages.add(
      SupportMessage(
        senderRole: UserRole.admin,
        text: clean,
        timestamp: _timestampLabel(),
      ),
    );
    thread.unreadByAdmin = false;
    notifyListeners();
    unawaited(_persistSupportThreads());
  }

  /// Marks [threadId] as opened by the admin, clearing the Inbox's "New"
  /// badge without affecting whether it's resolved.
  void markThreadRead(String threadId) {
    final thread = threadById(threadId);
    if (thread == null || !thread.unreadByAdmin) return;
    thread.unreadByAdmin = false;
    notifyListeners();
    unawaited(_persistSupportThreads());
  }

  void setThreadResolved(String threadId, {required bool resolved}) {
    final thread = threadById(threadId);
    if (thread == null || thread.resolved == resolved) return;
    thread.resolved = resolved;
    notifyListeners();
    unawaited(_persistSupportThreads());
  }

  /// Kept for callers that only ever mark a thread resolved.
  void resolveThread(String threadId) =>
      setThreadResolved(threadId, resolved: true);

  /// Fallback result shown when the phone camera preview isn't available
  /// (e.g. on an emulator), so the Scan tab has something to display without
  /// fabricating breed/movement values that were never actually observed.
  ManualScanResult generateManualScan() {
    return const ManualScanResult(
      condition: HealthState.normal,
      breed: '-',
      movement: '-',
      detectionCount: 0,
      note:
          'Camera preview is unavailable on this device, so a live scan could not run.',
    );
  }

  @override
  void dispose() {
    _liveStatusTicker?.cancel();
    for (final subscription in _farmStatusSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _farmStatusSubscriptions.clear();
    _sensorClient.removeListener(notifyListeners);
    _sensorClient.dispose();
    _yoloDetector.close();
    unawaited(V380CloudBridgeRegistry.instance.closeAll());
    unawaited(_alertController.close());
    super.dispose();
  }
}
