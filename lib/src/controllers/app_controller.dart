part of '../../main.dart';

class AppController extends ChangeNotifier {
  static const _requiredCctvHits = 2;
  static const _emptyCctvFramesBeforeClear = 2;
  static const maxLiveCctvStreams = 4;

  AppController({required this.cameras})
    : _users = [
        AppUser(
          username: 'admin',
          password: '123456',
          displayName: 'System Admin',
          role: UserRole.admin,
          cameraAccessEnabled: false,
          monitor: MonitorSnapshot.empty(),
          cctvs: const [],
        ),
        AppUser(
          username: 'farmer1',
          password: 'farm123',
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
              streamUrl: _testRtspStreamUrl,
              label: 'CCTV',
            ),
          ],
        ),
        AppUser(
          username: 'farmer2',
          password: 'farm123',
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
          password: '123456',
          displayName: 'User One',
          role: UserRole.user,
          cameraAccessEnabled: true,
          monitor: MonitorSnapshot.sampleOne(),
          cctvs: const [],
        ),
        AppUser(
          username: 'user2',
          password: '123456',
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

  final List<CameraDescription> cameras;
  final List<AppUser> _users;
  final List<SupportThread> _supportThreads;
  final Esp32SensorClient _sensorClient = Esp32SensorClient();
  final OnDeviceYoloDetector _yoloDetector = OnDeviceYoloDetector();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId:
        '402884110739-fsm2ontv9tajkin1seajgphs6d08e3ug.apps.googleusercontent.com',
  );
  final Map<String, CctvInspectionResult> _cctvCandidates = {};
  final Map<String, int> _cctvCandidateHits = {};
  final Map<String, int> _cctvEmptyFrames = {};
  final StreamController<AppAlertEvent> _alertController =
      StreamController<AppAlertEvent>.broadcast();
  AppThemePreference _themePreference = AppThemePreference.light;
  Locale _languageLocale = const Locale('en');
  DateTime? _lastDailySummaryDate;
  String? lastError;
  Session? _session;
  int _streamIdCounter = 0;
  int _accountIdCounter = 0;
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
  int get totalCctvCount =>
      farmUsers.fold<int>(0, (sum, user) => sum + user.liveCctvStreams.length);
  int get openSupportCount =>
      _supportThreads.where((thread) => !thread.resolved).length;
  int get unreadSupportCount =>
      _supportThreads.where((thread) => thread.unreadByAdmin).length;
  Esp32SensorConnectionStatus get sensorConnectionStatus =>
      _sensorClient.status;
  Esp32SensorReading? get latestSensorReading => _sensorClient.latestReading;
  String get sensorStatusLabel => _sensorClient.statusLabel;
  bool get sensorHasReadIssue => _sensorClient.hasReadIssue;
  AppThemePreference get themePreference => _themePreference;
  Locale get languageLocale => _languageLocale;

  /// Fires whenever an event matches an enabled Notification Preference
  /// (and isn't muted by quiet hours), for the app shell to surface as an
  /// in-app SnackBar/sound/vibration.
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
            password: '',
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

  /// Restores a session remembered via [rememberThisDevice], if any. Called
  /// once at app startup, before falling back to the login screen.
  Future<Session?> restoreRememberedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_rememberUsernameKey);
    final roleName = prefs.getString(_rememberRoleKey);
    if (username == null || roleName == null) return null;

    // Wait for a previous session's persisted account edits (renames,
    // removals, credential changes) to finish loading before checking who
    // this username actually is now.
    await _persistedStateLoaded;

    final role = UserRole.values.where((r) => r.name == roleName).firstOrNull;
    final user = userByUsername(username);
    if (role == null || user == null || user.role != role) return null;

    lastError = null;
    _session = Session(user: user);
    notifyListeners();
    return _session;
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
    final startHour = prefs.getInt('${_notificationPrefsPrefix}quiet_start_hour');
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

  /// Called after a live camera finishes saving a recorded clip, gated by
  /// the "Recording Updates" Notification Preference.
  Future<void> notifyRecordingSaved(String username, String path) async {
    final fileName = path.split(Platform.pathSeparator).last;
    await _maybeEmitAlert(
      category: 'recording_updates',
      title: 'Recording saved',
      message: 'Saved $fileName to your Recordings library.',
    );
  }

  Future<void> connectEsp32Sensor(String username) {
    return _sensorClient.connect(
      onReading: (reading) => _applyEsp32Reading(username, reading),
    );
  }

  Future<void> disconnectEsp32Sensor() {
    return _sensorClient.disconnect();
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

  Session? signIn({
    required String username,
    required String password,
    required UserRole expectedRole,
  }) {
    final cleanUsername = username.trim();
    final cleanPassword = password.trim();

    AppUser? user;
    for (final entry in _users) {
      if (entry.username == cleanUsername) {
        user = entry;
        break;
      }
    }

    if (user == null || user.password != cleanPassword) {
      lastError = 'Invalid username or password.';
      notifyListeners();
      return null;
    }

    if (user.role != expectedRole) {
      lastError = expectedRole == UserRole.admin
          ? 'This account is not registered as an admin.'
          : 'This account is not registered as a user.';
      notifyListeners();
      return null;
    }

    lastError = null;
    _session = Session(user: user);
    if (user.firstLoginAt == null) {
      user.firstLoginAt = DateTime.now();
      unawaited(_persistAccounts());
    }
    notifyListeners();
    return _session;
  }

  Future<Session?> signInWithGoogle({required UserRole expectedRole}) async {
    try {
      final googleAccount = await _googleSignIn.signIn();

      if (googleAccount == null) {
        lastError = 'Google sign-in was cancelled.';
        notifyListeners();
        return null;
      }

      // Google provides identity; the selected landing button still decides
      // which existing app workspace the user enters.
      final user = _userForGoogleAccount(googleAccount, expectedRole);
      await _applyGoogleProfileIfSyncEnabled(user, googleAccount);

      lastError = null;
      _session = Session(
        user: user,
        email: googleAccount.email,
        photoUrl: googleAccount.photoUrl,
      );
      notifyListeners();
      return _session;
    } catch (_) {
      lastError =
          'Unable to sign in with Google. Check the Google OAuth setup for this app.';
      notifyListeners();
      return null;
    }
  }

  /// Overwrites [user]'s display name with the Google account's, but only
  /// when the "Sync profile information" toggle on Connected Accounts is on
  /// (defaults to on). When off, local profile edits are left alone.
  Future<void> _applyGoogleProfileIfSyncEnabled(
    AppUser user,
    GoogleSignInAccount googleAccount,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final syncProfile = prefs.getBool('roostify.sync.profile') ?? true;
    if (!syncProfile) return;

    final displayName = googleAccount.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      user.displayName = displayName;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _session = null;
    notifyListeners();
  }

  /// Links the currently signed-in local/demo account to a Google account,
  /// so its email and photo show up on the Profile tab. Mutates the active
  /// [Session] in place (rather than replacing it) so the AppShell already
  /// holding that Session reflects the change immediately.
  Future<bool> linkGoogleAccount() async {
    final session = _session;
    if (session == null) {
      lastError = 'Sign in before connecting a Google account.';
      notifyListeners();
      return false;
    }

    try {
      final googleAccount = await _googleSignIn.signIn();
      if (googleAccount == null) {
        lastError = 'Google sign-in was cancelled.';
        notifyListeners();
        return false;
      }

      await _applyGoogleProfileIfSyncEnabled(session.user, googleAccount);
      session.email = googleAccount.email;
      session.photoUrl = googleAccount.photoUrl;
      lastError = null;
      notifyListeners();
      return true;
    } catch (_) {
      lastError =
          'Unable to connect Google. Check the Google OAuth setup for this app.';
      notifyListeners();
      return false;
    }
  }

  /// Removes the Google identity from the active local account without
  /// ending the app session.
  Future<void> unlinkGoogleAccount() async {
    final session = _session;
    if (session == null) return;
    await _googleSignIn.signOut();
    session.email = null;
    session.photoUrl = null;
    lastError = null;
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
  String? updateCredentials(
    String username, {
    String? newUsername,
    String? newPassword,
    String? recoveryEmail,
    required String currentPassword,
  }) {
    final user = userByUsername(username);
    if (user == null) {
      return 'Account not found.';
    }

    if (user.password != currentPassword) {
      return 'Current password is incorrect.';
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
      final oldUsername = user.username;
      user.username = cleanUsername;
      for (final thread in _supportThreads) {
        if (thread.username == oldUsername) {
          thread.username = cleanUsername;
        }
      }
      _clearCctvFiltersForUser(oldUsername);
      unawaited(_migratePersistedLiveCctvStreams(oldUsername, cleanUsername));
    }

    if (wantsPasswordChange) {
      user.password = cleanPassword;
    }
    if (recoveryEmail != null) {
      user.email = recoveryEmail.trim();
    }

    notifyListeners();
    unawaited(_persistAccounts());
    return null;
  }

  Future<void> _migratePersistedLiveCctvStreams(
    String oldUsername,
    String newUsername,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final oldKey = _liveCctvStreamsPrefKey(oldUsername);
    final raw = prefs.getString(oldKey);
    if (raw == null) return;

    await prefs.setString(_liveCctvStreamsPrefKey(newUsername), raw);
    await prefs.remove(oldKey);
  }

  AppUser _userForGoogleAccount(
    GoogleSignInAccount account,
    UserRole expectedRole,
  ) {
    if (expectedRole == UserRole.admin) {
      return _users.firstWhere((user) => user.isAdmin);
    }

    final baseUsername = _googleUsernameBase(account.email);
    final existingUser = userByUsername(baseUsername);
    if (existingUser != null) {
      return existingUser;
    }

    final username = _availableGoogleUsername(baseUsername);
    final displayName = account.displayName?.trim();
    final resolvedDisplayName = displayName == null || displayName.isEmpty
        ? account.email
        : displayName;
    final user = AppUser(
      accountId: _generateAccountId(),
      username: username,
      password: '',
      displayName: resolvedDisplayName,
      role: UserRole.user,
      cameraAccessEnabled: true,
      monitor: MonitorSnapshot.newUser(resolvedDisplayName),
      cctvs: const [
        CctvFeed(
          name: 'Camera A',
          location: 'New Coop',
          status: HealthState.normal,
          online: false,
          note: 'Waiting for the first live feed connection.',
        ),
      ],
    );
    _users.add(user);
    unawaited(_persistAccounts());
    return user;
  }

  String _googleUsernameBase(String email) {
    final localPart = email.split('@').first.toLowerCase();
    final sanitized = localPart.replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
    return sanitized.isEmpty ? 'google_user' : sanitized;
  }

  String _availableGoogleUsername(String baseUsername) {
    var username = baseUsername;
    var suffix = 2;

    while (_users.any((user) => user.username == username)) {
      username = '$baseUsername$suffix';
      suffix += 1;
    }

    return username;
  }

  AppUser? userByUsername(String username) {
    for (final user in _users) {
      if (user.username == username) {
        return user;
      }
    }
    return null;
  }

  bool addUser({
    required String username,
    required String displayName,
    String email = '',
    String farmName = '',
    String contactNumber = '',
    String password = 'farm123',
  }) {
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

    _users.add(
      AppUser(
        accountId: _generateAccountId(),
        username: cleanUsername,
        password: password.trim().isEmpty ? 'farm123' : password.trim(),
        displayName: cleanDisplayName,
        email: email.trim(),
        farmName: farmName.trim(),
        contactNumber: contactNumber.trim(),
        role: UserRole.user,
        cameraAccessEnabled: true,
        tempPasswordIssued: true,
        monitor: MonitorSnapshot.newUser(cleanDisplayName),
        cctvs: const [
          CctvFeed(
            name: 'Camera A',
            location: 'New Coop',
            status: HealthState.normal,
            online: false,
            note: 'Waiting for the first live feed connection.',
          ),
        ],
      ),
    );
    lastError = null;
    notifyListeners();
    unawaited(_persistAccounts());
    return true;
  }

  String _generateAccountId() {
    _accountIdCounter += 1;
    return 'acct-${DateTime.now().microsecondsSinceEpoch}-$_accountIdCounter';
  }

  void removeUser(String username) {
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
  }

  void toggleCameraAccess(String username) {
    final user = userByUsername(username);
    if (user == null || user.isAdmin) return;
    user.cameraAccessEnabled = !user.cameraAccessEnabled;
    notifyListeners();
    unawaited(_persistAccounts());
  }

  /// Issues [username] a new temporary password on the admin's behalf, no
  /// current-password check required. Restarts the 7-day temp-password
  /// grace period tracked by [AppUser.firstLoginAt].
  bool adminResetPassword(String username, String newPassword) {
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

    user.password = cleanPassword;
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

  /// Connects a new live camera for [username], in addition to any cameras
  /// already connected. Returns false (and sets [lastError]) if the URL is
  /// invalid, already connected, or the [maxLiveCctvStreams] cap is reached.
  bool addLiveCctvStream(String username, String streamUrl) {
    final user = userByUsername(username);
    if (user == null || user.isAdmin) return false;

    final cleanStreamUrl = streamUrl.trim();
    if (cleanStreamUrl.isEmpty) {
      lastError = 'Enter a valid RTSP stream URL.';
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
        label: 'CCTV',
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

    user.liveCctvStreams.removeWhere((stream) => stream.id == streamId);
    _clearCctvFilter(username, streamId);
    notifyListeners();
    unawaited(_persistLiveCctvStreams(user));
  }

  static String _liveCctvStreamsPrefKey(String username) =>
      'roostify.cctv_streams.$username';

  /// Persists [user]'s connected RTSP URLs so they survive an app restart.
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

  /// Restores every user's saved RTSP URLs from the previous app session.
  /// Call once after the controller is created; safe to await or fire-and-forget.
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
    notifyListeners();
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

    final wasAlreadyError = stream.inspection.state == CctvInspectionState.error;
    stream.inspection = CctvInspectionResult.error(message);
    notifyListeners();

    if (!wasAlreadyError) {
      unawaited(
        _maybeEmitAlert(
          category: 'cctv_offline',
          title: 'CCTV camera disconnected',
          message: message,
          severity: AlertSeverity.warning,
        ),
      );
    }
  }

  Future<void> inspectCctvFrame(
    String username,
    String streamId,
    Uint8List frameBytes,
  ) async {
    final user = userByUsername(username);
    final stream = user == null ? null : _liveStreamById(user, streamId);
    if (user == null || user.isAdmin || stream == null) {
      return;
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
        return;
      }

      final previousInspection = currentStream.inspection;
      currentStream.inspection = result;
      notifyListeners();

      final isNewConfirmedDetection =
          result.state == CctvInspectionState.completed &&
          result.detected &&
          (previousInspection.state != CctvInspectionState.completed ||
              previousInspection.condition != result.condition);
      if (isNewConfirmedDetection) {
        unawaited(
          _maybeEmitAlert(
            category: 'rooster_detection',
            title: result.condition == HealthState.abnormal
                ? 'Abnormal rooster detected'
                : 'Rooster detection updated',
            message: result.message,
            severity: result.condition == HealthState.abnormal
                ? AlertSeverity.danger
                : AlertSeverity.info,
          ),
        );
      }
    } catch (error) {
      markCctvInspectionError(
        username,
        streamId,
        'Could not inspect the CCTV frame: $error',
      );
    }
  }

  CctvInspectionResult _confirmedCctvInspectionResult(
    String username,
    String streamId,
    CctvInspectionResult result,
  ) {
    final key = '$username::$streamId';
    if (!result.detected) {
      _cctvCandidates.remove(key);
      _cctvCandidateHits.remove(key);
      final emptyFrames = (_cctvEmptyFrames[key] ?? 0) + 1;
      _cctvEmptyFrames[key] = emptyFrames;
      if (emptyFrames >= _emptyCctvFramesBeforeClear) {
        return result;
      }
      final user = userByUsername(username);
      final stream = user == null ? null : _liveStreamById(user, streamId);
      return stream?.inspection ?? result;
    }

    _cctvEmptyFrames[key] = 0;
    final candidate = _cctvCandidates[key];
    final hits =
        candidate != null &&
            _sameDetectedRooster(candidate.detections, result.detections)
        ? (_cctvCandidateHits[key] ?? 1) + 1
        : 1;

    _cctvCandidates[key] = result;
    _cctvCandidateHits[key] = hits;
    return hits >= _requiredCctvHits
        ? result
        : CctvInspectionResult.inspecting();
  }

  void _clearCctvFilter(String username, String streamId) {
    final key = '$username::$streamId';
    _cctvCandidates.remove(key);
    _cctvCandidateHits.remove(key);
    _cctvEmptyFrames.remove(key);
  }

  void _clearCctvFiltersForUser(String username) {
    final prefix = '$username::';
    _cctvCandidates.removeWhere((key, _) => key.startsWith(prefix));
    _cctvCandidateHits.removeWhere((key, _) => key.startsWith(prefix));
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

  void _applyEsp32Reading(String username, Esp32SensorReading reading) {
    final user = userByUsername(username);
    if (user == null || user.isAdmin) return;

    final previousAlerts = user.monitor.alerts;
    final updatedMonitor = user.monitor.withEnvironmentReading(reading);
    user.monitor = updatedMonitor;
    notifyListeners();

    for (final alert in updatedMonitor.alerts) {
      final isNew = !previousAlerts.any(
        (old) => old.title == alert.title && old.category == alert.category,
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
    _sensorClient.removeListener(notifyListeners);
    _sensorClient.dispose();
    _yoloDetector.close();
    unawaited(_alertController.close());
    super.dispose();
  }
}
