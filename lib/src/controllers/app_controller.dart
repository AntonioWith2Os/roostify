part of '../../main.dart';

class AppController extends ChangeNotifier {
  static const _requiredCctvHits = 2;
  static const _emptyCctvFramesBeforeClear = 2;

  AppController({required this.cameras})
    : _users = [
        AppUser(
          username: 'admin',
          password: 'admin123',
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
          liveCctvStreamUrl: _testRtspStreamUrl,
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
  }

  final List<CameraDescription> cameras;
  final List<AppUser> _users;
  final List<SupportThread> _supportThreads;
  final Esp32SensorClient _sensorClient = Esp32SensorClient();
  final OnDeviceYoloDetector _yoloDetector = OnDeviceYoloDetector();
  final Map<String, CctvInspectionResult> _cctvCandidates = {};
  final Map<String, int> _cctvCandidateHits = {};
  final Map<String, int> _cctvEmptyFrames = {};
  AppThemePreference _themePreference = AppThemePreference.light;
  String? lastError;
  Session? _session;

  List<AppUser> get farmUsers =>
      List.unmodifiable(_users.where((user) => !user.isAdmin));
  List<SupportThread> get supportThreads =>
      List.unmodifiable(_supportThreads.reversed);
  Session? get session => _session;
  int get totalCctvCount =>
      farmUsers.fold<int>(0, (sum, user) => sum + user.cctvs.length);
  int get openSupportCount =>
      _supportThreads.where((thread) => !thread.resolved).length;
  Esp32SensorConnectionStatus get sensorConnectionStatus =>
      _sensorClient.status;
  Esp32SensorReading? get latestSensorReading => _sensorClient.latestReading;
  String get sensorStatusLabel => _sensorClient.statusLabel;
  AppThemePreference get themePreference => _themePreference;

  void setThemePreference(AppThemePreference preference) {
    if (_themePreference == preference) return;
    _themePreference = preference;
    notifyListeners();
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
    notifyListeners();
    return _session;
  }

  void signOut() {
    _session = null;
    notifyListeners();
  }

  AppUser? userByUsername(String username) {
    for (final user in _users) {
      if (user.username == username) {
        return user;
      }
    }
    return null;
  }

  bool addUser({required String username, required String displayName}) {
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
        username: cleanUsername,
        password: 'farm123',
        displayName: cleanDisplayName,
        role: UserRole.user,
        cameraAccessEnabled: true,
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
    return true;
  }

  void removeUser(String username) {
    _users.removeWhere((user) => user.username == username && !user.isAdmin);
    _supportThreads.removeWhere((thread) => thread.username == username);
    _clearCctvFiltersForUser(username);
    notifyListeners();
  }

  void toggleCameraAccess(String username) {
    final user = userByUsername(username);
    if (user == null || user.isAdmin) return;
    user.cameraAccessEnabled = !user.cameraAccessEnabled;
    notifyListeners();
  }

  void setLiveCctvStreamUrl(String username, String? streamUrl) {
    final user = userByUsername(username);
    if (user == null || user.isAdmin) return;

    final previousStreamUrl = user.liveCctvStreamUrl;
    if (previousStreamUrl != null) {
      _clearCctvFilter(username, previousStreamUrl);
    }

    final cleanStreamUrl = streamUrl?.trim();
    user.liveCctvStreamUrl = cleanStreamUrl == null || cleanStreamUrl.isEmpty
        ? null
        : cleanStreamUrl;
    user.cctvInspection = user.liveCctvStreamUrl == null
        ? CctvInspectionResult.idle()
        : CctvInspectionResult.waitingForFrame();
    notifyListeners();
  }

  void markCctvInspectionCapturing(String username, String streamUrl) {
    final user = userByUsername(username);
    if (user == null || user.isAdmin || user.liveCctvStreamUrl != streamUrl) {
      return;
    }

    user.cctvInspection = CctvInspectionResult.capturing();
    notifyListeners();
  }

  void markCctvInspectionError(
    String username,
    String streamUrl,
    String message,
  ) {
    final user = userByUsername(username);
    if (user == null || user.isAdmin || user.liveCctvStreamUrl != streamUrl) {
      return;
    }

    user.cctvInspection = CctvInspectionResult.error(message);
    notifyListeners();
  }

  Future<void> inspectCctvFrame(
    String username,
    String streamUrl,
    Uint8List frameBytes,
  ) async {
    final user = userByUsername(username);
    if (user == null || user.isAdmin || user.liveCctvStreamUrl != streamUrl) {
      return;
    }

    user.cctvInspection = CctvInspectionResult.inspecting();
    notifyListeners();

    try {
      final rawResult = await _yoloDetector.inspectFrame(frameBytes);
      final result = _confirmedCctvInspectionResult(
        username,
        streamUrl,
        rawResult,
      );
      final currentUser = userByUsername(username);
      if (currentUser == null ||
          currentUser.isAdmin ||
          currentUser.liveCctvStreamUrl != streamUrl) {
        return;
      }

      currentUser.cctvInspection = result;
      notifyListeners();
    } catch (error) {
      markCctvInspectionError(
        username,
        streamUrl,
        'Could not inspect the CCTV frame: $error',
      );
    }
  }

  CctvInspectionResult _confirmedCctvInspectionResult(
    String username,
    String streamUrl,
    CctvInspectionResult result,
  ) {
    final key = '$username::$streamUrl';
    if (!result.detected) {
      _cctvCandidates.remove(key);
      _cctvCandidateHits.remove(key);
      final emptyFrames = (_cctvEmptyFrames[key] ?? 0) + 1;
      _cctvEmptyFrames[key] = emptyFrames;
      if (emptyFrames >= _emptyCctvFramesBeforeClear) {
        return result;
      }
      return userByUsername(username)?.cctvInspection ?? result;
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

  void _clearCctvFilter(String username, String streamUrl) {
    final key = '$username::$streamUrl';
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

    user.monitor = user.monitor.withEnvironmentReading(reading);
    notifyListeners();
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
        id: 'thread-${_supportThreads.length + 1}',
        username: username,
        messages: const [],
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
    notifyListeners();
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
    notifyListeners();
  }

  void resolveThread(String threadId) {
    final thread = threadById(threadId);
    if (thread == null) return;
    thread.resolved = true;
    notifyListeners();
  }

  ManualScanResult generateManualScan(String username) {
    final user = userByUsername(username);
    final monitor = user?.monitor ?? MonitorSnapshot.sampleOne();
    return ManualScanResult(
      condition: monitor.cctvStatus,
      breed: monitor.detectedBreed,
      movement: monitor.movementLabel,
      detectionCount: monitor.cctvStatus == HealthState.abnormal ? 1 : 0,
      note:
          'Camera preview is unavailable, so the app is showing the latest farm monitoring estimate for ${monitor.detectedBreed}.',
    );
  }

  @override
  void dispose() {
    _sensorClient.removeListener(notifyListeners);
    _sensorClient.dispose();
    _yoloDetector.close();
    super.dispose();
  }
}
