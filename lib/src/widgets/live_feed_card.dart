part of '../../main.dart';

class LiveFeedCard extends StatefulWidget {
  const LiveFeedCard({
    super.key,
    required this.streamUrl,
    required this.recordingOwnerUsername,
    required this.controller,
    this.detections = const [],
    this.inspectionInterval,
    this.onFrameCaptureStarted,
    this.onFrameReady,
    this.onFrameCaptureFailed,
    this.expand = false,
    this.displayLabel,
  });

  final String streamUrl;

  /// Username that any recording started from this card is saved under, so
  /// only that user (and the admin) can see it in the Recordings list.
  final String recordingOwnerUsername;

  /// Used to read the Auto-play/Data Saver preferences and to emit a gated
  /// "Recording Updates" alert when a clip finishes saving.
  final AppController controller;
  final List<ChickenDetection> detections;

  /// Minimum time between frame captures; defaults to a device-scaled cadence.
  final Duration? inspectionInterval;
  final VoidCallback? onFrameCaptureStarted;
  final Future<void> Function(Uint8List frameBytes)? onFrameReady;
  final ValueChanged<String>? onFrameCaptureFailed;

  /// When true, the card fills whatever bounded space its parent gives it
  /// (a full-screen tab body, a grid cell) instead of using a fixed preview
  /// height, and drops its rounded corners so the video sits edge to edge.
  final bool expand;

  /// Overrides the default "LIVE CCTV" tag, e.g. with "CCTV 1" when several
  /// cameras are shown at once.
  final String? displayLabel;

  @override
  State<LiveFeedCard> createState() => _LiveFeedCardState();
}

class ChickenDetectionPainter extends CustomPainter {
  ChickenDetectionPainter({required this.detections});

  final List<ChickenDetection> detections;

  /*
    red   = 0xFFFF5B6E
    green = 0xFF43E39C
  */

  @override
  void paint(Canvas canvas, Size size) {
    for (final detection in detections) {
      final color = detection.condition == HealthState.abnormal
          ? _appAccent
          : const Color(0xFF43E39C);
      final rect = Rect.fromLTRB(
        detection.box.left * size.width,
        detection.box.top * size.height,
        detection.box.right * size.width,
        detection.box.bottom * size.height,
      );
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawRect(rect, paint);

      final label =
          '${detection.label} ${(detection.confidence * 100).toStringAsFixed(0)}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(48, size.width - rect.left - 8));
      final labelRect = Rect.fromLTWH(
        rect.left,
        math.max(0, rect.top - textPainter.height - 6),
        textPainter.width + 10,
        textPainter.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(6)),
        Paint()..color = color.withValues(alpha: 0.9),
      );
      textPainter.paint(canvas, labelRect.topLeft + const Offset(5, 3));
    }
  }

  @override
  bool shouldRepaint(covariant ChickenDetectionPainter oldDelegate) {
    return !listEquals(oldDelegate.detections, detections);
  }
}

enum _LiveFeedPlaybackProfile {
  auto('Auto', 'Fijk auto', Icons.auto_mode),
  tcp('TCP', 'Force RTSP over TCP', Icons.settings_ethernet),
  udp('UDP', 'Prefer RTP/UDP', Icons.swap_horiz),
  software('SW', 'Software decoding', Icons.memory);

  const _LiveFeedPlaybackProfile(this.label, this.menuLabel, this.icon);

  final String label;
  final String menuLabel;
  final IconData icon;
}

class _LiveFeedCardState extends State<LiveFeedCard> {
  FijkPlayer? _controller;
  Timer? _diagnosticTimer;
  Timer? _recoveryTimer;
  Timer? _inspectionTimer;

  static const _streamCachingMs = 2000;
  static const _maxInspectionInterval = Duration(seconds: 4);
  static const _captureFailuresBeforePlayerRestart = 3;
  static const _slowStartDiagnosticDelay = Duration(seconds: 8);
  static const _startupRecoveryDelay = Duration(seconds: 14);
  static const _errorRecoveryDelay = Duration(seconds: 3);
  static const _maxAutomaticRecoveryAttempts = 4;
  static const _automaticRecoveryProfiles = [
    _LiveFeedPlaybackProfile.tcp,
    _LiveFeedPlaybackProfile.auto,
    _LiveFeedPlaybackProfile.udp,
    _LiveFeedPlaybackProfile.software,
  ];

  _LiveFeedPlaybackProfile _playbackProfile = _LiveFeedPlaybackProfile.tcp;
  bool _diagnosticRunning = false;
  String? _streamProbeStatus;
  int _controllerGeneration = 0;
  int _automaticRecoveryAttempt = 0;
  bool _hasPlayedCurrentController = false;
  bool _inspectionRunning = false;
  Duration _lastInspectionCost = Duration.zero;
  int _consecutiveCaptureFailures = 0;

  final RtspRecorderService _recorder = RtspRecorderService();
  Timer? _recordingTicker;
  bool _isRecording = false;
  bool _recordingBusy = false;
  Duration _recordingElapsed = Duration.zero;

  bool _wasFullScreen = false;
  Timer? _orientationResetTimer;
  int? _pendingFullScreenRestoreGeneration;

  bool _showPtzControls = true;
  bool _dataSaverEnabled = false;

  void _togglePtzControls() {
    setState(() {
      _showPtzControls = !_showPtzControls;
    });
  }

  Duration get _baseInspectionInterval =>
      widget.inspectionInterval ?? _defaultInspectionInterval();

  bool get _supportsFijkPlayer {
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
    unawaited(_loadPreviewPreferences());
  }

  /// Honors the "Auto-play CCTV Preview" and "Data Saver" app settings: when
  /// Data Saver is on, or Auto-play is off, the stream isn't opened until
  /// the viewer explicitly taps play (see [_startManually]), instead of
  /// pulling live video automatically.
  Future<void> _loadPreviewPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final autoPlay = prefs.getBool('roostify.app.autoplay') ?? true;
    final dataSaver = prefs.getBool('roostify.app.data_saver') ?? false;
    setState(() => _dataSaverEnabled = dataSaver);
    if (autoPlay && !dataSaver && _supportsFijkPlayer) {
      _replaceController();
    }
  }

  void _startManually() {
    if (_controller != null || !_supportsFijkPlayer) return;
    setState(() => _replaceController());
  }

  @override
  void didUpdateWidget(covariant LiveFeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl &&
        _supportsFijkPlayer &&
        _controller != null) {
      _playbackProfile = _LiveFeedPlaybackProfile.tcp;
      _replaceController(resetRecovery: true);
    }
  }

  void _replaceController({bool resetRecovery = false}) {
    final currentController = _controller;
    final wasFullScreen = currentController?.value.fullScreen ?? false;
    if (currentController != null && wasFullScreen) {
      // fijkplayer_plus pushes its own fullscreen route and only pops it
      // (restoring system UI/orientation) when it sees fullScreen flip back
      // to false on this exact player. If a stall/error triggers automatic
      // recovery while the user is still in fullscreen, tearing down the
      // player out from under that pushed route leaves it stuck on screen
      // referencing a disposed player. Exit first so the route closes
      // cleanly before we swap players; once the new player is actually
      // playing again (see _handlePlayerValueChanged), we re-enter
      // fullscreen on it, so this is just a brief flicker rather than
      // dropping out for good.
      currentController.exitFullScreen();
    }

    _diagnosticTimer?.cancel();
    _recoveryTimer?.cancel();
    _inspectionTimer?.cancel();
    if (resetRecovery) {
      _automaticRecoveryAttempt = 0;
    }
    _hasPlayedCurrentController = false;
    _inspectionRunning = false;
    _consecutiveCaptureFailures = 0;
    _controllerGeneration += 1;
    final generation = _controllerGeneration;
    _pendingFullScreenRestoreGeneration = wasFullScreen ? generation : null;

    final previousController = _controller;
    if (previousController != null) {
      previousController.removeListener(_handlePlayerValueChanged);
      unawaited(previousController.release().catchError((_) {}));
    }

    final controller = FijkPlayer();
    controller.addListener(_handlePlayerValueChanged);
    _controller = controller;
    unawaited(_configureAndStartController(controller, generation));
    _scheduleSlowStartDiagnostic(generation);
    _schedulePlaybackRecovery(generation, delay: _startupRecoveryDelay);
  }

  void _restoreFullScreenIfPending(FijkPlayer controller, int generation) {
    if (_pendingFullScreenRestoreGeneration != generation || !mounted) {
      return;
    }
    _pendingFullScreenRestoreGeneration = null;
    // By now the new player actually has real video dimensions (it's
    // playing), so fijkplayer_plus's fullscreen orientation lock uses the
    // real aspect ratio instead of guessing. Force a frame first so the
    // FijkView for this generation is mounted and its own fullscreen
    // listener is attached before we ask the player to enter fullscreen.
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isCurrentController(controller, generation)) {
        return;
      }
      controller.enterFullScreen();
    });
  }

  Future<void> _configureAndStartController(
    FijkPlayer controller,
    int generation,
  ) async {
    try {
      await controller.applyOptions(_playerOptionsForProfile());
      if (!_isCurrentController(controller, generation)) {
        return;
      }
      await controller.setDataSource(widget.streamUrl, autoPlay: true);
    } catch (error) {
      if (!_isCurrentController(controller, generation)) {
        return;
      }
      _startStreamProbe();
      _schedulePlaybackRecovery(generation, delay: _errorRecoveryDelay);
      _setStreamProbeStatus('Fijk could not open the RTSP stream: $error');
    }
  }

  bool _isCurrentController(FijkPlayer controller, int generation) {
    return mounted &&
        generation == _controllerGeneration &&
        identical(_controller, controller);
  }

  FijkOption _playerOptionsForProfile() {
    final options = FijkOption()
      ..setHostOption('request-screen-on', 1)
      ..setHostOption('request-audio-focus', 1)
      ..setHostOption('enable-snapshot', 1)
      ..setPlayerOption('framedrop', 1)
      ..setPlayerOption('infbuf', 1)
      ..setPlayerOption('packet-buffering', 0)
      ..setPlayerOption(
        'mediacodec-all-videos',
        _playbackProfile == _LiveFeedPlaybackProfile.software ? 0 : 1,
      )
      ..setFormatOption(
        'max_delay',
        (_dataSaverEnabled ? _streamCachingMs ~/ 2 : _streamCachingMs) * 1000,
      )
      ..setFormatOption('stimeout', 5000000)
      ..setFormatOption('reconnect', 1);

    switch (_playbackProfile) {
      case _LiveFeedPlaybackProfile.tcp:
      case _LiveFeedPlaybackProfile.software:
        options.setFormatOption('rtsp_transport', 'tcp');
        break;
      case _LiveFeedPlaybackProfile.udp:
        options.setFormatOption('rtsp_transport', 'udp');
        break;
      case _LiveFeedPlaybackProfile.auto:
        break;
    }

    return options;
  }

  void _handlePlayerValueChanged() {
    final controller = _controller;
    final value = controller?.value;
    if (!mounted || controller == null || value == null) {
      return;
    }

    if (_wasFullScreen && !value.fullScreen) {
      _scheduleOrientationReset();
    }
    _wasFullScreen = value.fullScreen;

    if (_isPlaying(value)) {
      _hasPlayedCurrentController = true;
      _ensureRepeatedFrameInspection(controller, _controllerGeneration);
      _automaticRecoveryAttempt = 0;
      _diagnosticTimer?.cancel();
      _recoveryTimer?.cancel();
      if (_streamProbeStatus != null &&
          !_streamProbeStatus!.startsWith('RTSP stream accepted')) {
        setState(() {
          _streamProbeStatus = null;
        });
      }
      _restoreFullScreenIfPending(controller, _controllerGeneration);
      return;
    }

    if (_hasFijkError(value)) {
      _diagnosticTimer?.cancel();
      _startStreamProbe();
      _schedulePlaybackRecovery(
        _controllerGeneration,
        delay: _errorRecoveryDelay,
      );
      return;
    }

    if (_hasPlayedCurrentController && _isRecoverableStall(controller, value)) {
      _ensurePlaybackRecoveryScheduled(
        _controllerGeneration,
        delay: _startupRecoveryDelay,
      );
    }
  }

  void _scheduleOrientationReset() {
    _orientationResetTimer?.cancel();
    // fijkplayer_plus locks device rotation to whichever two orientations
    // match the video's aspect ratio when entering fullscreen (landscape
    // for typical 16:9 CCTV footage), then on exit "restores" it by locking
    // to the *other* pair instead of clearing the restriction — so the
    // whole app is left rotation-locked after the first fullscreen use.
    // Its own restore call runs asynchronously right after this listener
    // fires, so clear the restriction shortly after rather than
    // immediately, or this reset gets clobbered by that call.
    _orientationResetTimer = Timer(const Duration(milliseconds: 400), () {
      SystemChrome.setPreferredOrientations(const []);
    });
  }

  void _ensureRepeatedFrameInspection(FijkPlayer controller, int generation) {
    if (_inspectionTimer?.isActive ?? false) {
      return;
    }

    unawaited(_captureInspectionFrame(controller, generation));
    _scheduleNextInspection(controller, generation);
  }

  void _scheduleNextInspection(FijkPlayer controller, int generation) {
    _inspectionTimer = Timer(_nextInspectionDelay(), () {
      if (!_isCurrentController(controller, generation)) {
        return;
      }
      if (_isPlaying(controller.value)) {
        unawaited(_captureInspectionFrame(controller, generation));
      }
      _scheduleNextInspection(controller, generation);
    });
  }

  Duration _nextInspectionDelay() {
    // Back off when capture plus inference is the bottleneck, so weak devices
    // never queue inspections faster than they can process them.
    final backoff = _lastInspectionCost * 2;
    if (backoff <= _baseInspectionInterval) {
      return _baseInspectionInterval;
    }
    return backoff > _maxInspectionInterval ? _maxInspectionInterval : backoff;
  }

  Future<void> _captureInspectionFrame(
    FijkPlayer controller,
    int generation,
  ) async {
    if (_inspectionRunning) {
      return;
    }

    _inspectionRunning = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!_isCurrentController(controller, generation)) {
        return;
      }

      final stopwatch = Stopwatch()..start();
      final frameBytes = await controller.takeSnapShot().timeout(
        const Duration(seconds: 5),
      );
      if (!_isCurrentController(controller, generation)) {
        return;
      }
      if (frameBytes.isEmpty) {
        throw StateError('The CCTV frame snapshot was empty.');
      }

      widget.onFrameCaptureStarted?.call();
      await widget.onFrameReady?.call(frameBytes);
      _lastInspectionCost = stopwatch.elapsed;
      _consecutiveCaptureFailures = 0;
    } catch (error) {
      if (!_isCurrentController(controller, generation)) {
        return;
      }

      widget.onFrameCaptureFailed?.call('Could not capture CCTV frame: $error');

      // fijkplayer keeps a single pending snapshot completer internally; if
      // one native reply is lost, every later takeSnapShot fails with "last
      // snapShot is not finished" until the player is rebuilt.
      _consecutiveCaptureFailures += 1;
      if (_consecutiveCaptureFailures >= _captureFailuresBeforePlayerRestart) {
        _replaceController();
      }
    } finally {
      _inspectionRunning = false;
    }
  }

  bool _isPlaying(FijkValue value) {
    return value.state == FijkState.started && value.videoRenderStart;
  }

  bool _hasFijkError(FijkValue value) {
    return value.state == FijkState.error ||
        value.exception.code != FijkException.ok;
  }

  bool _isRecoverableStall(FijkPlayer controller, FijkValue value) {
    return controller.isBuffering ||
        value.state == FijkState.stopped ||
        value.state == FijkState.completed ||
        value.state == FijkState.error ||
        value.completed;
  }

  void _scheduleSlowStartDiagnostic(int generation) {
    _diagnosticTimer = Timer(_slowStartDiagnosticDelay, () {
      final value = _controller?.value;
      if (!mounted ||
          generation != _controllerGeneration ||
          value == null ||
          _isPlaying(value)) {
        return;
      }

      setState(() {
        _streamProbeStatus =
            'Still waiting for video using ${_playbackProfile.menuLabel}.';
      });
    });
  }

  void _schedulePlaybackRecovery(int generation, {required Duration delay}) {
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(delay, () {
      final controller = _controller;
      final value = controller?.value;
      if (!mounted ||
          controller == null ||
          generation != _controllerGeneration ||
          value == null ||
          _isPlaying(value)) {
        return;
      }

      _recoverStalledPlayback(controller, value);
    });
  }

  void _ensurePlaybackRecoveryScheduled(
    int generation, {
    required Duration delay,
  }) {
    if (_recoveryTimer?.isActive ?? false) {
      return;
    }

    _schedulePlaybackRecovery(generation, delay: delay);
  }

  void _recoverStalledPlayback(FijkPlayer controller, FijkValue value) {
    _startStreamProbe();

    if (_automaticRecoveryAttempt >= _maxAutomaticRecoveryAttempts) {
      setState(() {
        _streamProbeStatus =
            'Video is still not playing after automatic retries. Check the stream URL, credentials, and camera RTSP setting.';
      });
      return;
    }

    final previousProfile = _playbackProfile;
    final nextProfile = _nextRecoveryProfile();
    final action = nextProfile == previousProfile
        ? 'restarting ${nextProfile.menuLabel}'
        : 'switching to ${nextProfile.menuLabel}';

    setState(() {
      _playbackProfile = nextProfile;
      _streamProbeStatus =
          'Video stalled at ${_playbackStateLabel(controller, value)}; $action.';
    });
    _replaceController();
  }

  _LiveFeedPlaybackProfile _nextRecoveryProfile() {
    final attempt = _automaticRecoveryAttempt;
    _automaticRecoveryAttempt += 1;

    if (attempt == 0) {
      return _playbackProfile;
    }

    final fallbackProfiles = _automaticRecoveryProfiles
        .where((profile) => profile != _playbackProfile)
        .toList();
    return fallbackProfiles[(attempt - 1) % fallbackProfiles.length];
  }

  String _playbackStateLabel(FijkPlayer controller, FijkValue value) {
    if (_hasFijkError(value)) {
      return 'error';
    }
    if (controller.isBuffering) {
      return 'buffering ${controller.bufferPercent}%';
    }

    return value.state.name;
  }

  void _selectPlaybackProfile(_LiveFeedPlaybackProfile profile) {
    if (profile == _playbackProfile) {
      _retryPlayback();
      return;
    }

    setState(() {
      _playbackProfile = profile;
      _streamProbeStatus = 'Trying ${profile.menuLabel}.';
    });
    _replaceController(resetRecovery: true);
  }

  void _retryPlayback() {
    setState(() {
      _streamProbeStatus = 'Retrying ${_playbackProfile.menuLabel}.';
    });
    _replaceController(resetRecovery: true);
  }

  void _startStreamProbe() {
    if (_diagnosticRunning) {
      return;
    }

    _diagnosticRunning = true;
    unawaited(
      _probeStreamEndpoint().whenComplete(() {
        _diagnosticRunning = false;
      }),
    );
  }

  Future<void> _probeStreamEndpoint() async {
    final uri = Uri.tryParse(widget.streamUrl);
    final host = uri?.host;
    final port = uri?.hasPort == true ? uri!.port : 554;
    final emulatorHostWarning = host == null
        ? null
        : _physicalDeviceHostWarning(host);

    if (uri == null || uri.scheme.toLowerCase() != 'rtsp') {
      if (!mounted) {
        return;
      }
      setState(() {
        _streamProbeStatus = 'Invalid RTSP URL.';
      });
      return;
    }

    if (host == null || host.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _streamProbeStatus = 'RTSP URL is missing a CCTV host.';
      });
      return;
    }

    try {
      final optionsResponse = await _sendRtspRequest(
        uri,
        method: 'OPTIONS',
        cSeq: 1,
      );

      if (!optionsResponse.isRtspResponse) {
        _setStreamProbeStatus(
          'Port $port is open on $host, but it did not answer as RTSP. Check that this IP is the CCTV, not the router.',
        );
        return;
      }

      if (optionsResponse.statusCode == 401) {
        _setStreamProbeStatus(_authFailureMessage(optionsResponse));
        return;
      }

      if (optionsResponse.statusCode != null &&
          optionsResponse.statusCode! >= 400 &&
          optionsResponse.statusCode != 405) {
        _setStreamProbeStatus(
          'CCTV reached, but RTSP OPTIONS was rejected: ${optionsResponse.statusSummary}.',
        );
        return;
      }

      final describeResponse = await _sendRtspRequest(
        uri,
        method: 'DESCRIBE',
        cSeq: 2,
        includeSdpAccept: true,
      );

      if (describeResponse.statusCode == 200) {
        _setStreamProbeStatus(
          'RTSP stream accepted by CCTV at $host:$port. Fijk is using ${_playbackProfile.menuLabel}.',
        );
        return;
      }

      if (describeResponse.statusCode == 401) {
        _setStreamProbeStatus(_authFailureMessage(describeResponse));
        return;
      }

      if (describeResponse.statusCode == 404) {
        _setStreamProbeStatus(
          'CCTV reached, but this stream path was not found. Verify ${uri.path}.',
        );
        return;
      }

      if (describeResponse.isRtspResponse) {
        _setStreamProbeStatus(
          'CCTV reached, but the stream URL was rejected: ${describeResponse.statusSummary}.',
        );
        return;
      }

      _setStreamProbeStatus(
        'Port $port is open on $host, but the stream request did not return RTSP.',
      );
    } on SocketException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _streamProbeStatus =
            emulatorHostWarning ??
            'Cannot connect to CCTV at $host:$port: ${error.message}.';
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() {
        _streamProbeStatus =
            emulatorHostWarning ??
            'CCTV at $host:$port did not answer the RTSP handshake in time.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _streamProbeStatus =
            'CCTV RTSP handshake failed for $host:$port: $error';
      });
    }
  }

  String? _physicalDeviceHostWarning(String host) {
    final normalizedHost = host.toLowerCase();
    final isLoopbackHost =
        normalizedHost == 'localhost' ||
        normalizedHost == '127.0.0.1' ||
        normalizedHost == '::1';
    final isAndroidEmulatorHost = normalizedHost == '10.0.2.2';

    if (!isLoopbackHost && !isAndroidEmulatorHost) {
      return null;
    }

    return isAndroidEmulatorHost
        ? '10.0.2.2 only points to the computer from an Android emulator. On a physical phone, use the CCTV camera LAN IP address instead.'
        : '$host points to this phone. On a physical device, use the CCTV camera LAN IP address instead.';
  }

  Future<_RtspProbeResponse> _sendRtspRequest(
    Uri uri, {
    required String method,
    required int cSeq,
    bool includeSdpAccept = false,
  }) async {
    final host = uri.host;
    final port = uri.hasPort ? uri.port : 554;
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 3),
    );

    try {
      final headers = <String>[
        '$method ${_rtspRequestTarget(uri)} RTSP/1.0',
        'CSeq: $cSeq',
        'User-Agent: RoosterWatch/1.0',
        if (includeSdpAccept) 'Accept: application/sdp',
        if (_basicRtspAuthorization(uri) case final authorization?)
          'Authorization: $authorization',
        'Connection: close',
      ];
      socket.add(utf8.encode('${headers.join('\r\n')}\r\n\r\n'));
      await socket.flush();

      final responseBytes = <int>[];
      await for (final chunk in socket.timeout(const Duration(seconds: 4))) {
        responseBytes.addAll(chunk);
        final responseText = latin1.decode(responseBytes, allowInvalid: true);
        if (responseText.contains('\r\n\r\n') || responseBytes.length > 8192) {
          break;
        }
      }

      return _RtspProbeResponse.parse(
        latin1.decode(responseBytes, allowInvalid: true),
      );
    } finally {
      socket.destroy();
    }
  }

  void _setStreamProbeStatus(String status) {
    if (!mounted) {
      return;
    }
    setState(() {
      _streamProbeStatus = status;
    });
  }

  String _rtspRequestTarget(Uri uri) {
    final path = uri.path.isEmpty ? '/' : uri.path;
    final buffer = StringBuffer('${uri.scheme}://${uri.host}');
    if (uri.hasPort) {
      buffer.write(':${uri.port}');
    }
    buffer.write(path);
    if (uri.hasQuery) {
      buffer.write('?${uri.query}');
    }
    return buffer.toString();
  }

  String? _basicRtspAuthorization(Uri uri) {
    if (uri.userInfo.isEmpty) {
      return null;
    }

    final separatorIndex = uri.userInfo.indexOf(':');
    final username = separatorIndex == -1
        ? uri.userInfo
        : uri.userInfo.substring(0, separatorIndex);
    final password = separatorIndex == -1
        ? ''
        : uri.userInfo.substring(separatorIndex + 1);
    final credentials =
        '${Uri.decodeComponent(username)}:${Uri.decodeComponent(password)}';

    return 'Basic ${base64Encode(utf8.encode(credentials))}';
  }

  String _authFailureMessage(_RtspProbeResponse response) {
    final authHeader = response.headers['www-authenticate'] ?? '';
    if (authHeader.toLowerCase().contains('digest')) {
      return 'CCTV reached, but it requires Digest authentication. Fijk will still try to negotiate it; if video fails, check the username, password, and RTSP settings.';
    }

    return 'CCTV reached, but RTSP authentication was rejected. Check the username and password.';
  }

  Future<void> _toggleRecording() async {
    if (_recordingBusy) {
      return;
    }
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    setState(() => _recordingBusy = true);
    try {
      await _recorder.startRecording(
        widget.streamUrl,
        username: widget.recordingOwnerUsername,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = true;
        _recordingElapsed = Duration.zero;
      });
      _recordingTicker?.cancel();
      _recordingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          return;
        }
        setState(() => _recordingElapsed = _recorder.recordingDuration);
      });
      _showRecordingSnack('Recording started.');
    } catch (error) {
      if (mounted) {
        _showRecordingSnack('Could not start recording: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _recordingBusy = false);
      }
    }
  }

  Future<void> _stopRecording() async {
    setState(() => _recordingBusy = true);
    _recordingTicker?.cancel();
    _recordingTicker = null;
    try {
      final outputPath = await _recorder.stopRecording();
      if (!mounted) {
        return;
      }
      if (outputPath == null) {
        _showRecordingSnack(
          'Recording stopped, but no video was saved (the stream may have failed).',
        );
      } else {
        _showRecordingSnack('Recording saved to the Roostify gallery album.');
        unawaited(
          widget.controller.notifyRecordingSaved(
            widget.recordingOwnerUsername,
            outputPath,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _showRecordingSnack('Could not finalize recording: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingBusy = false;
          _recordingElapsed = Duration.zero;
        });
      }
    }
  }

  void _showRecordingSnack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatRecordingElapsed(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _enterFullScreen() {
    final controller = _controller;
    if (!_supportsFijkPlayer || controller == null) {
      return;
    }
    controller.enterFullScreen();
  }

  Widget _liveFeedPanelBuilder(
    FijkPlayer player,
    FijkData data,
    BuildContext context,
    Size viewSize,
    Rect texturePos,
  ) {
    if (!player.value.fullScreen) {
      return const SizedBox.shrink();
    }

    // fijkplayer_plus inserts this widget as an unpositioned child of its
    // own internal Stack, which lays it out with loose constraints. Since
    // every child here is a Positioned with no unpositioned sibling, the
    // Stack would otherwise collapse to zero size, making any right/bottom
    // anchored child (the exit button, the PTZ panel) resolve its offset
    // against a 0x0 box and render off-canvas. Pin it to the real video
    // viewport size so those offsets are computed correctly.
    return SizedBox.fromSize(
      size: viewSize,
      child: Stack(
        children: [
          if (widget.detections.isNotEmpty)
            Positioned.fromRect(
              rect: texturePos,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: ChickenDetectionPainter(
                    detections: widget.detections,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              bottom: false,
              right: false,
              child: const SeverityTag(
                label: 'LIVE CCTV',
                color: Color(0xFF43E39C),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              left: false,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LiveFeedIconButton(
                    tooltip: _showPtzControls
                        ? 'Hide PTZ controls'
                        : 'Show PTZ controls',
                    icon: _showPtzControls
                        ? Icons.control_camera
                        : Icons.control_camera_outlined,
                    onPressed: _togglePtzControls,
                  ),
                  const SizedBox(width: 8),
                  _LiveFeedIconButton(
                    tooltip: 'Exit full screen',
                    icon: Icons.fullscreen_exit,
                    onPressed: player.exitFullScreen,
                  ),
                ],
              ),
            ),
          ),
          if (_showPtzControls)
            Positioned(
              top: 0,
              bottom: 0,
              right: 16,
              child: Center(
                child: SafeArea(
                  child: Theme(
                    data: buildAppTheme(Brightness.dark),
                    child: V380PtzControlPanel(
                      streamUrl: widget.streamUrl,
                      compactOverlay: true,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.46),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  widget.streamUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fijkErrorDescription(FijkValue value) {
    final message = value.exception.message;
    if (message != null && message.trim().isNotEmpty) {
      return message;
    }

    if (value.exception.code != FijkException.ok) {
      return value.exception.toString();
    }

    return 'Fijk entered ${value.state.name} state before video started.';
  }

  @override
  void dispose() {
    _diagnosticTimer?.cancel();
    _recoveryTimer?.cancel();
    _inspectionTimer?.cancel();
    _recordingTicker?.cancel();
    _orientationResetTimer?.cancel();
    _recorder.dispose();
    _controller?.removeListener(_handlePlayerValueChanged);
    if (_controller case final controller?) {
      unawaited(controller.release().catchError((_) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final borderRadius = widget.expand
        ? BorderRadius.zero
        : BorderRadius.circular(24);
    return Container(
      height: widget.expand ? null : 220,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B365F), Color(0xFF151B31)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: borderRadius,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: _supportsFijkPlayer && controller != null
                      ? ValueListenableBuilder<FijkValue>(
                          valueListenable: controller,
                          builder: (context, value, _) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                KeyedSubtree(
                                  key: ValueKey(
                                    '${widget.streamUrl}|${_playbackProfile.name}|$_controllerGeneration',
                                  ),
                                  child: FijkView(
                                    player: controller,
                                    fit: FijkFit.cover,
                                    fsFit: FijkFit.contain,
                                    fs: true,
                                    color: Colors.black,
                                    panelBuilder: _liveFeedPanelBuilder,
                                  ),
                                ),
                                if (!value.videoRenderStart &&
                                    !_hasFijkError(value))
                                  const _LiveFeedPlaceholder(),
                                IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.16,
                                        ),
                                      ),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0x00000000),
                                          Color(0x16000000),
                                          Color(0x55000000),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                ),
                                if (widget.detections.isNotEmpty)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: ChickenDetectionPainter(
                                          detections: widget.detections,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_hasFijkError(value))
                                  _LiveFeedErrorState(
                                    message: _fijkErrorDescription(value),
                                  ),
                              ],
                            );
                          },
                        )
                      : _supportsFijkPlayer
                      ? _LiveFeedManualStartState(
                          dataSaver: _dataSaverEnabled,
                          onTap: _startManually,
                        )
                      : const _LiveFeedUnsupportedState(),
                ),
              ),
              Positioned(
                top: 18,
                left: 18,
                child: SeverityTag(
                  label: widget.displayLabel ?? 'LIVE CCTV',
                  color: const Color(0xFF43E39C),
                ),
              ),
              if (_isRecording)
                Positioned(
                  top: 52,
                  left: 18,
                  child: _RecordingIndicator(
                    label: _formatRecordingElapsed(_recordingElapsed),
                  ),
                ),
              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LiveFeedRecordButton(
                      isRecording: _isRecording,
                      busy: _recordingBusy,
                      onPressed: _supportsFijkPlayer && controller != null
                          ? _toggleRecording
                          : null,
                    ),
                    const SizedBox(width: 8),
                    _LiveFeedIconButton(
                      tooltip: 'Full screen',
                      icon: Icons.fullscreen,
                      onPressed: _supportsFijkPlayer && controller != null
                          ? _enterFullScreen
                          : null,
                    ),
                    const SizedBox(width: 8),
                    _LiveFeedPlaybackMenu(
                      selectedProfile: _playbackProfile,
                      onSelected: _selectPlaybackProfile,
                    ),
                  ],
                ),
              ),
              const Positioned(
                top: 56,
                right: 12,
                child: SeverityTag(
                  label: 'YOLOv8 ACTIVE',
                  color: Color(0xFFFFCE67),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      widget.streamUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              if (_streamProbeStatus case final status?)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 58,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: status.startsWith('RTSP stream accepted')
                            ? const Color(0xCC134F36)
                            : const Color(0xCC5A1D24),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LiveFeedIconButton extends StatelessWidget {
  const _LiveFeedIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: onPressed == null ? 0.26 : 0.46),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: onPressed == null ? Colors.white38 : Colors.white,
        ),
        iconSize: 20,
        constraints: const BoxConstraints.tightFor(width: 42, height: 38),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _LiveFeedRecordButton extends StatelessWidget {
  const _LiveFeedRecordButton({
    required this.isRecording,
    required this.busy,
    required this.onPressed,
  });

  final bool isRecording;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final baseColor = isRecording
        ? _appAccent
        : Colors.black.withValues(alpha: enabled ? 0.46 : 0.26);

    return Material(
      color: baseColor,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: isRecording ? 'Stop recording' : 'Record',
        onPressed: enabled ? onPressed : null,
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Icon(
                isRecording ? Icons.stop : Icons.fiber_manual_record,
                color: enabled || isRecording ? Colors.white : Colors.white38,
              ),
        iconSize: 20,
        constraints: const BoxConstraints.tightFor(width: 42, height: 38),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: _appAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'REC',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveFeedPlaybackMenu extends StatelessWidget {
  const _LiveFeedPlaybackMenu({
    required this.selectedProfile,
    required this.onSelected,
  });

  final _LiveFeedPlaybackProfile selectedProfile;
  final ValueChanged<_LiveFeedPlaybackProfile> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.46),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<_LiveFeedPlaybackProfile>(
        tooltip: 'Playback mode',
        initialValue: selectedProfile,
        color: const Color(0xFF11162A),
        onSelected: onSelected,
        itemBuilder: (context) {
          return [
            for (final profile in _LiveFeedPlaybackProfile.values)
              PopupMenuItem<_LiveFeedPlaybackProfile>(
                value: profile,
                child: _LiveFeedPlaybackMenuItem(
                  profile: profile,
                  selected: profile == selectedProfile,
                ),
              ),
          ];
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selectedProfile.icon, color: Colors.white, size: 17),
              const SizedBox(width: 6),
              Text(
                selectedProfile.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.expand_more, color: Colors.white70, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveFeedPlaybackMenuItem extends StatelessWidget {
  const _LiveFeedPlaybackMenuItem({
    required this.profile,
    required this.selected,
  });

  final _LiveFeedPlaybackProfile profile;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF43E39C) : Colors.white70;
    return Row(
      children: [
        Icon(profile.icon, color: color, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            profile.menuLabel,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        if (selected)
          const Icon(Icons.check, color: Color(0xFF43E39C), size: 18),
      ],
    );
  }
}

class _RtspProbeResponse {
  const _RtspProbeResponse({
    required this.statusLine,
    required this.statusCode,
    required this.headers,
  });

  factory _RtspProbeResponse.parse(String responseText) {
    final headerText = responseText.split('\r\n\r\n').first;
    final lines = const LineSplitter()
        .convert(headerText.replaceAll('\r\n', '\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return const _RtspProbeResponse(
        statusLine: 'No response',
        statusCode: null,
        headers: {},
      );
    }

    final statusLine = lines.first.trim();
    final statusCodeText = RegExp(
      r'^RTSP/\d\.\d\s+(\d{3})',
    ).firstMatch(statusLine)?.group(1);
    final headers = <String, String>{};

    for (final line in lines.skip(1)) {
      final separatorIndex = line.indexOf(':');
      if (separatorIndex <= 0) {
        continue;
      }

      headers[line.substring(0, separatorIndex).trim().toLowerCase()] = line
          .substring(separatorIndex + 1)
          .trim();
    }

    return _RtspProbeResponse(
      statusLine: statusLine,
      statusCode: int.tryParse(statusCodeText ?? ''),
      headers: headers,
    );
  }

  final String statusLine;
  final int? statusCode;
  final Map<String, String> headers;

  bool get isRtspResponse => statusLine.startsWith('RTSP/');

  String get statusSummary {
    if (!isRtspResponse) {
      return statusLine;
    }

    return statusLine.replaceFirst(RegExp(r'^RTSP/\d\.\d\s+'), '');
  }
}

class _LiveFeedPlaceholder extends StatelessWidget {
  const _LiveFeedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF11162A),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          SizedBox(height: 12),
          Text(
            'Connecting to CCTV stream...',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveFeedManualStartState extends StatelessWidget {
  const _LiveFeedManualStartState({
    required this.dataSaver,
    required this.onTap,
  });

  final bool dataSaver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF11162A),
      alignment: Alignment.center,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              dataSaver
                  ? 'Data Saver is on — tap to load this preview'
                  : 'Auto-play is off — tap to start this preview',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveFeedUnsupportedState extends StatelessWidget {
  const _LiveFeedUnsupportedState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF11162A),
      padding: const EdgeInsets.all(20),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 34),
          SizedBox(height: 12),
          Text(
            'Live RTSP playback is enabled for Android and iOS builds.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveFeedErrorState extends StatelessWidget {
  const _LiveFeedErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF8D8D), size: 34),
          const SizedBox(height: 12),
          const Text(
            'CCTV stream failed to open',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
