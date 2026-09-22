part of '../../main.dart';

class LiveFeedCard extends StatefulWidget {
  const LiveFeedCard({
    super.key,
    required this.streamUrl,
    required this.recordingOwnerUsername,
    required this.controller,
    this.detections = const [],
    this.onFrameReady,
    this.onConnectionChanged,
    this.expand = false,
    this.displayLabel,
    this.videoFit = BoxFit.cover,
    this.showEndpointOverlay = true,
    this.showLabelOverlay = true,
    this.showStreamProbeOverlay = true,
    this.onStreamStatusChanged,
  });

  final String streamUrl;

  /// Username that any recording started from this card is saved under, so
  /// only that user (and the admin) can see it in the Recordings list.
  final String recordingOwnerUsername;

  /// Used to read the Auto-play/Data Saver preferences and to emit a gated
  /// "Recording Updates" alert when a clip finishes saving.
  final AppController controller;
  final List<ChickenDetection> detections;
  final Future<CctvInspectionResult?> Function(Uint8List frameBytes)?
  onFrameReady;
  final ValueChanged<bool>? onConnectionChanged;

  /// When true, the card fills whatever bounded space its parent gives it
  /// (a full-screen tab body, a grid cell) instead of using a fixed preview
  /// height, and drops its rounded corners so the video sits edge to edge.
  final bool expand;

  /// Overrides the default "LIVE CCTV" tag, e.g. with "CCTV 1" when several
  /// cameras are shown at once.
  final String? displayLabel;

  /// How the camera frame is fitted inside the available viewport. The
  /// standalone viewer uses [BoxFit.contain] so portrait feeds are never
  /// cropped; compact previews retain the existing edge-to-edge treatment.
  final BoxFit videoFit;

  /// Lets a parent present the endpoint in its own information panel instead
  /// of duplicating it over the video.
  final bool showEndpointOverlay;

  /// Lets a parent that already shows the camera name and live status
  /// elsewhere (e.g. its own app bar) hide the redundant name tag over the
  /// video, freeing that space so it can never collide with the AI/record/
  /// fullscreen controls pinned to the top-right.
  final bool showLabelOverlay;

  /// Lets a parent render the connection/recovery status banner itself
  /// (e.g. pinned to the bottom of the whole screen) instead of it floating
  /// over the video. Pair with [onStreamStatusChanged] to receive updates.
  final bool showStreamProbeOverlay;

  /// Fires whenever the connection/recovery status message changes, so a
  /// parent that sets [showStreamProbeOverlay] to false can still show it
  /// somewhere of its own choosing. `null` means there's nothing to show.
  final void Function(String? message, bool succeeded)? onStreamStatusChanged;

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
  auto('Auto', 'Video server auto', Icons.auto_mode),
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
  Timer? _stablePlaybackTimer;
  Timer? _playbackWatchdogTimer;
  Timer? _inspectionTimer;
  StreamSubscription<bool>? _bufferStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  static const _streamCachingMs = 2000;
  // ffmpeg's rtsp demuxer is given this long to sit on a silent socket
  // (connecting or mid-stream) before it reports a failure on its own — see
  // the 'stimeout'/'rw_timeout' options below. Every recovery delay that
  // might tear down and restart a still-connecting-or-playing controller
  // must stay comfortably longer than this, or the app's own watchdog
  // preempts ffmpeg's timeout and turns an ordinary slow-but-working
  // handshake or a V380 burst pause into an endless restart loop.
  static const _networkSocketTimeout = Duration(seconds: 30);
  static const _slowStartDiagnosticDelay = Duration(seconds: 8);
  static const _startupRecoveryDelay = Duration(seconds: 34);
  static const _stallRecoveryDelay = Duration(seconds: 34);
  static const _playbackWatchdogInterval = Duration(seconds: 3);
  static const _playbackProgressTimeout = Duration(seconds: 34);
  static const _errorRecoveryDelay = Duration(seconds: 5);
  static const _stablePlaybackResetDelay = Duration(minutes: 2);
  static const _inspectionWarmupDelay = Duration(seconds: 3);
  static const _inspectionFailureLimit = 1;
  static const _maxAutomaticRecoveryAttempts = 4;
  // Once automatic recovery exhausts every playback profile without success,
  // keep trying at this slower cadence instead of giving up for good — a
  // camera that comes back online (reboot, Wi-Fi blip) should reconnect on
  // its own rather than sitting on a dead error message until someone
  // notices and manually retries.
  static const _exhaustedRecoveryCooldown = Duration(minutes: 1);
  static const _automaticRecoveryProfiles = [
    _LiveFeedPlaybackProfile.tcp,
    _LiveFeedPlaybackProfile.auto,
    _LiveFeedPlaybackProfile.udp,
    _LiveFeedPlaybackProfile.software,
  ];

  _LiveFeedPlaybackProfile _playbackProfile = _LiveFeedPlaybackProfile.tcp;
  bool _diagnosticRunning = false;
  String? _streamProbeStatus;
  bool _streamProbeSucceeded = false;
  // Tracks what was last handed to widget.onStreamStatusChanged so build()
  // only notifies the parent when the status actually changed, rather than
  // on every rebuild.
  String? _lastNotifiedStreamProbeStatus;
  bool _lastNotifiedStreamProbeSucceeded = false;
  int _controllerGeneration = 0;
  int _automaticRecoveryAttempt = 0;
  bool _hasPlayedCurrentController = false;
  bool? _reportedConnectionOnline;
  Duration? _lastPlaybackPosition;
  DateTime? _lastPlaybackProgressAt;
  bool _hasObservedPlaybackProgress = false;
  // Defaults on so live detection actually runs the moment a camera opens,
  // instead of needing to be discovered and switched on by hand; the
  // per-camera preference below still lets someone turn it back off.
  bool _aiScanningEnabled = true;
  bool _inspectionRunning = false;
  int _consecutiveInspectionFailures = 0;
  String? _aiStatusMessage;
  late List<ChickenDetection> _liveDetections;

  final RtspRecorderService _recorder = RtspRecorderService();
  Timer? _recordingTicker;
  bool _isRecording = false;
  bool _recordingRequested = false;
  bool _recordingPausedForDisconnect = false;
  bool _recordingBusy = false;
  Duration _recordingElapsed = Duration.zero;
  int _recordingSegmentId = 0;

  bool _wasFullScreen = false;
  Timer? _orientationResetTimer;
  int? _pendingFullScreenRestoreGeneration;

  bool _showPtzControls = false;
  bool _dataSaverEnabled = false;
  String? _resolvedStreamUrl;

  void _togglePtzControls() {
    setState(() {
      _showPtzControls = !_showPtzControls;
    });
  }

  bool get _isV380Cloud =>
      videoDeliveryProtocolFor(widget.streamUrl) ==
      VideoDeliveryProtocol.v380Cloud;

  bool get _isRtspDelivery =>
      videoDeliveryProtocolFor(widget.streamUrl) == VideoDeliveryProtocol.rtsp;

  // The on-device V380 engine's local RTSP server only ever speaks
  // TCP-interleaved RTP (see V380LocalRtspServer), so playback needs the
  // same forced-tcp transport as a real RTSP camera, even though it isn't
  // ONVIF-capable like one (see _supportsOnvifPtz below).
  bool get _requiresTcpTransport => _isRtspDelivery || _isV380Cloud;

  // Real RTSP cameras default to hardware (MediaCodec) decode via the "tcp"
  // profile, which real camera RTP streams tolerate fine. The V380 engine's
  // RTP muxer is a from-scratch, in-app implementation rather than a
  // battle-tested camera firmware's, so default it to "software" decode
  // instead - hardware decoders are far less forgiving of any bitstream
  // imperfection and have been observed to crash the player on it, whereas
  // ffmpeg's software decoder degrades gracefully. Users can still switch
  // profiles manually (see _availablePlaybackProfiles).
  _LiveFeedPlaybackProfile get _defaultPlaybackProfile {
    if (_isRtspDelivery) return _LiveFeedPlaybackProfile.tcp;
    if (_isV380Cloud) return _LiveFeedPlaybackProfile.software;
    return _LiveFeedPlaybackProfile.auto;
  }

  bool get _supportsOnvifPtz =>
      videoDeliveryProtocolFor(widget.streamUrl) == VideoDeliveryProtocol.rtsp;

  // Gated on _requiresTcpTransport, not _isRtspDelivery: that's exactly the
  // set of protocols _playerOptionsForProfile actually applies rtsp_transport
  // for, so it's also exactly the set where "TCP" vs "UDP" is a real choice
  // rather than a no-op. V380 Cloud qualifies (its resolved playback URL is
  // itself an rtsp:// URL, served by the on-device V380LocalRtspServer),
  // getting the same four options a local RTSP camera does; HLS/HTTP and
  // RTMP streams stay restricted since rtsp_transport never applies to them.
  List<_LiveFeedPlaybackProfile> get _availablePlaybackProfiles =>
      _requiresTcpTransport
      ? _LiveFeedPlaybackProfile.values
      : const [
          _LiveFeedPlaybackProfile.auto,
          _LiveFeedPlaybackProfile.software,
        ];

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
    _playbackProfile = _defaultPlaybackProfile;
    _liveDetections = List.of(widget.detections);
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
    final aiScanningEnabled = prefs.getBool(_aiScanningPreferenceKey) ?? true;
    setState(() {
      _dataSaverEnabled = dataSaver;
      _aiScanningEnabled = aiScanningEnabled;
    });
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
    if (!listEquals(oldWidget.detections, widget.detections) &&
        !_inspectionRunning) {
      _liveDetections = List.of(widget.detections);
    }
    if (oldWidget.streamUrl != widget.streamUrl &&
        _supportsFijkPlayer &&
        _controller != null) {
      _playbackProfile = _defaultPlaybackProfile;
      _resolvedStreamUrl = null;
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
    _stablePlaybackTimer?.cancel();
    _playbackWatchdogTimer?.cancel();
    _inspectionTimer?.cancel();
    unawaited(_bufferStateSubscription?.cancel());
    unawaited(_positionSubscription?.cancel());
    _bufferStateSubscription = null;
    _positionSubscription = null;
    _stablePlaybackTimer = null;
    if (resetRecovery) {
      _automaticRecoveryAttempt = 0;
    }
    _hasPlayedCurrentController = false;
    _lastPlaybackPosition = null;
    _lastPlaybackProgressAt = null;
    _hasObservedPlaybackProgress = false;
    _inspectionRunning = false;
    _consecutiveInspectionFailures = 0;
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
    _monitorPlaybackHealth(controller, generation);
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
      final playbackUrl = await resolveCameraPlaybackUrl(widget.streamUrl);
      if (!_isCurrentController(controller, generation)) {
        return;
      }
      _resolvedStreamUrl = playbackUrl;
      await controller.setDataSource(playbackUrl, autoPlay: true);
    } catch (error) {
      if (!_isCurrentController(controller, generation)) {
        return;
      }
      _startStreamProbe();
      _schedulePlaybackRecovery(generation, delay: _errorRecoveryDelay);
      _setStreamProbeStatus(
        'The player could not open the camera stream: $error',
      );
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
      ..setPlayerOption('framedrop', 1)
      // A small packet buffer absorbs ordinary Wi-Fi jitter. The previous
      // zero-buffer live tuning treated brief packet gaps like disconnects.
      ..setPlayerOption('infbuf', 0)
      ..setPlayerOption('packet-buffering', 1)
      ..setPlayerOption(
        'mediacodec-all-videos',
        _playbackProfile == _LiveFeedPlaybackProfile.software ? 0 : 1,
      )
      ..setFormatOption(
        'max_delay',
        (_dataSaverEnabled ? _streamCachingMs ~/ 2 : _streamCachingMs) * 1000,
      )
      // V380-class cameras can pause between bursts for longer than five
      // seconds. Allow a genuine network silence before failing — see
      // _networkSocketTimeout for why every app-level recovery delay must
      // stay longer than this.
      ..setFormatOption('stimeout', _networkSocketTimeout.inMicroseconds)
      ..setFormatOption('rw_timeout', _networkSocketTimeout.inMicroseconds)
      ..setFormatOption('reconnect', 1);

    if (_aiScanningEnabled) {
      options.setHostOption('enable-snapshot', 1);
    }

    if (_requiresTcpTransport) {
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
    }

    return options;
  }

  String get _aiScanningPreferenceKey {
    final identity = '${widget.recordingOwnerUsername}|${widget.streamUrl}';
    return 'roostify.cctv.ai_scanning.${sha1.convert(utf8.encode(identity))}';
  }

  Future<void> _setAiScanningEnabled(bool enabled) async {
    if (_aiScanningEnabled == enabled) {
      return;
    }

    _inspectionTimer?.cancel();
    _inspectionTimer = null;
    setState(() {
      _aiScanningEnabled = enabled;
      _aiStatusMessage = enabled
          ? 'AI scanning enabled'
          : 'AI scanning disabled';
      if (!enabled) {
        _liveDetections = const [];
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiScanningPreferenceKey, enabled);
    if (!mounted) return;

    final controller = _controller;
    if (controller != null) {
      try {
        await controller.setOption(
          FijkOption.hostCategory,
          'enable-snapshot',
          enabled ? 1 : 0,
        );
      } catch (_) {
        if (enabled && mounted) {
          await _turnOffAiAfterFailure(
            'AI scanning could not start. Live playback remains active.',
          );
          return;
        }
      }
    }

    if (enabled &&
        controller != null &&
        _isPlaying(controller, controller.value)) {
      _scheduleNextInspection(
        controller,
        _controllerGeneration,
        delay: _inspectionWarmupDelay,
      );
    }
  }

  void _toggleAiScanning() {
    unawaited(_setAiScanningEnabled(!_aiScanningEnabled));
  }

  void _ensureInspectionScheduled(FijkPlayer controller, int generation) {
    if (!_aiScanningEnabled ||
        widget.onFrameReady == null ||
        _inspectionRunning ||
        (_inspectionTimer?.isActive ?? false)) {
      return;
    }

    _scheduleNextInspection(
      controller,
      generation,
      delay: _inspectionWarmupDelay,
    );
  }

  void _scheduleNextInspection(
    FijkPlayer controller,
    int generation, {
    Duration? delay,
  }) {
    _inspectionTimer?.cancel();
    _inspectionTimer = Timer(delay ?? _defaultInspectionInterval(), () {
      _inspectionTimer = null;
      if (!_aiScanningEnabled ||
          !_isCurrentController(controller, generation) ||
          !_isPlaying(controller, controller.value)) {
        return;
      }
      unawaited(_captureInspectionFrame(controller, generation));
    });
  }

  Future<void> _captureInspectionFrame(
    FijkPlayer controller,
    int generation,
  ) async {
    if (_inspectionRunning || !_aiScanningEnabled) {
      return;
    }

    _inspectionRunning = true;
    try {
      final frameBytes = await controller.takeSnapShot().timeout(
        const Duration(seconds: 4),
      );
      if (!_isCurrentController(controller, generation) ||
          !_aiScanningEnabled) {
        return;
      }
      if (frameBytes.isEmpty) {
        throw StateError('The CCTV snapshot was empty.');
      }

      final result = await widget.onFrameReady?.call(frameBytes);
      if (!_isCurrentController(controller, generation) ||
          !_aiScanningEnabled) {
        return;
      }

      _consecutiveInspectionFailures = 0;
      if (result != null) {
        setState(() {
          _liveDetections = List.of(result.detections);
          _aiStatusMessage = result.resultLabel;
        });
      }
    } catch (error) {
      if (!_isCurrentController(controller, generation)) {
        return;
      }

      _consecutiveInspectionFailures += 1;
      if (_consecutiveInspectionFailures >= _inspectionFailureLimit) {
        await _turnOffAiAfterFailure(
          'AI scanning was turned off after a frame-capture failure. Live playback remains active.',
          restartPlayback: true,
        );
      }
    } finally {
      _inspectionRunning = false;
      if (_aiScanningEnabled && _isCurrentController(controller, generation)) {
        _scheduleNextInspection(controller, generation);
      }
    }
  }

  Future<void> _turnOffAiAfterFailure(
    String message, {
    bool restartPlayback = false,
  }) async {
    _inspectionTimer?.cancel();
    _inspectionTimer = null;
    if (mounted) {
      setState(() {
        _aiScanningEnabled = false;
        _aiStatusMessage = message;
        _liveDetections = const [];
      });
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiScanningPreferenceKey, false);
    if (restartPlayback && mounted && _controller != null) {
      _replaceController(resetRecovery: true);
    }
  }

  void _monitorPlaybackHealth(FijkPlayer controller, int generation) {
    _bufferStateSubscription = controller.onBufferStateUpdate.listen((
      isBuffering,
    ) {
      if (!_isCurrentController(controller, generation)) {
        return;
      }

      if (isBuffering && _hasPlayedCurrentController) {
        _ensurePlaybackRecoveryScheduled(
          generation,
          delay: _stallRecoveryDelay,
        );
        return;
      }

      if (!isBuffering && _isPlaying(controller, controller.value)) {
        _recoveryTimer?.cancel();
        _reportConnectionStatus(true);
      }
    });

    _positionSubscription = controller.onCurrentPosUpdate.listen((position) {
      if (!_isCurrentController(controller, generation)) {
        return;
      }

      final previousPosition = _lastPlaybackPosition;
      _lastPlaybackPosition = position;
      if (previousPosition == null || position == previousPosition) {
        return;
      }

      _hasObservedPlaybackProgress = true;
      _lastPlaybackProgressAt = DateTime.now();
      if (_hasPlayedCurrentController && !controller.isBuffering) {
        _recoveryTimer?.cancel();
        _reportConnectionStatus(true);
      }
    });

    _playbackWatchdogTimer = Timer.periodic(_playbackWatchdogInterval, (_) {
      if (!_isCurrentController(controller, generation) ||
          !_hasPlayedCurrentController) {
        return;
      }

      if (controller.isBuffering) {
        _ensurePlaybackRecoveryScheduled(
          generation,
          delay: _stallRecoveryDelay,
        );
        return;
      }

      final lastProgressAt = _lastPlaybackProgressAt;
      if (!_hasObservedPlaybackProgress || lastProgressAt == null) {
        return;
      }

      if (DateTime.now().difference(lastProgressAt) >=
          _playbackProgressTimeout) {
        _ensurePlaybackRecoveryScheduled(generation, delay: Duration.zero);
      }
    });
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

    if (_isPlaying(controller, value)) {
      _reportConnectionStatus(true);
      _hasPlayedCurrentController = true;
      _ensureInspectionScheduled(controller, _controllerGeneration);
      _stablePlaybackTimer ??= Timer(_stablePlaybackResetDelay, () {
        _automaticRecoveryAttempt = 0;
        _stablePlaybackTimer = null;
      });
      _diagnosticTimer?.cancel();
      _recoveryTimer?.cancel();
      if (_streamProbeStatus != null && !_streamProbeSucceeded) {
        setState(() {
          _streamProbeStatus = null;
          _streamProbeSucceeded = false;
        });
      }
      _restoreFullScreenIfPending(controller, _controllerGeneration);
      return;
    }

    if (_hasFijkError(value)) {
      _reportConnectionStatus(false);
      _stablePlaybackTimer?.cancel();
      _stablePlaybackTimer = null;
      _diagnosticTimer?.cancel();
      _startStreamProbe();
      _schedulePlaybackRecovery(
        _controllerGeneration,
        delay: _errorRecoveryDelay,
      );
      return;
    }

    if (_hasPlayedCurrentController && _isRecoverableStall(controller, value)) {
      _stablePlaybackTimer?.cancel();
      _stablePlaybackTimer = null;
      _ensurePlaybackRecoveryScheduled(
        _controllerGeneration,
        delay: _stallRecoveryDelay,
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

  bool _isPlaying(FijkPlayer controller, FijkValue value) {
    return value.state == FijkState.started &&
        value.videoRenderStart &&
        !controller.isBuffering;
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
      final controller = _controller;
      final value = controller?.value;
      if (!mounted ||
          generation != _controllerGeneration ||
          controller == null ||
          value == null ||
          _isPlaying(controller, value)) {
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
          _isPlaying(controller, value)) {
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
    _reportConnectionStatus(false);
    _startStreamProbe();

    if (_automaticRecoveryAttempt >= _maxAutomaticRecoveryAttempts) {
      // Don't sit on a dead error forever — a camera that reboots or a
      // Wi-Fi blip that clears should reconnect on its own. Reset the
      // attempt budget and run the full profile cycle again after a longer
      // cooldown instead of requiring the viewer to notice and retry by
      // hand.
      _automaticRecoveryAttempt = 0;
      setState(() {
        _streamProbeStatus =
            'Video is still not playing after automatic retries. Check the edge gateway, video server, and playback URL — will keep retrying in the background.';
        _streamProbeSucceeded = false;
      });
      _schedulePlaybackRecovery(
        _controllerGeneration,
        delay: _exhaustedRecoveryCooldown,
      );
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
        .where(_availablePlaybackProfiles.contains)
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

  void _reportConnectionStatus(bool online) {
    if (_reportedConnectionOnline == online) return;
    _reportedConnectionOnline = online;
    widget.onConnectionChanged?.call(online);
    if (online) {
      unawaited(_resumeRecordingAfterReconnect());
    } else {
      unawaited(_pauseRecordingForDisconnect());
    }
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
    String playbackUrl;
    try {
      playbackUrl =
          _resolvedStreamUrl ??
          await resolveCameraPlaybackUrl(widget.streamUrl);
      _resolvedStreamUrl = playbackUrl;
    } catch (error) {
      _setStreamProbeStatus('Could not start the V380 decoder backend: $error');
      return;
    }
    final uri = Uri.tryParse(playbackUrl);
    final host = uri?.host;
    final scheme = uri?.scheme.toLowerCase();
    final port = uri?.hasPort == true
        ? uri!.port
        : switch (scheme) {
            'http' => 80,
            'https' || 'rtmps' => 443,
            'rtmp' => 1935,
            _ => 554,
          };
    final emulatorHostWarning = host == null
        ? null
        : _physicalDeviceHostWarning(host);

    if (videoDeliveryProtocolFor(widget.streamUrl) ==
        VideoDeliveryProtocol.v380Cloud) {
      final status = await V380CloudBridgeRegistry.instance.statusFor(
        widget.streamUrl,
      );
      if (status != null) {
        _setStreamProbeStatus(
          status,
          success: status.contains(' is streaming'),
        );
        return;
      }
    }

    if (uri == null || cloudPlaybackUrlValidationError(playbackUrl) != null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _streamProbeStatus = 'Invalid cloud playback URL.';
        _streamProbeSucceeded = false;
      });
      return;
    }

    if (host == null || host.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _streamProbeStatus = 'Playback URL is missing a video server host.';
        _streamProbeSucceeded = false;
      });
      return;
    }

    if (!_isRtspDelivery) {
      try {
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 4),
        );
        socket.destroy();
        _setStreamProbeStatus(
          'Video server reached at $host:$port. Retrying playback.',
          success: true,
        );
      } on SocketException catch (error) {
        _setStreamProbeStatus(
          emulatorHostWarning ??
              'Cannot reach the video server at $host:$port: ${error.message}.',
        );
      } on TimeoutException {
        _setStreamProbeStatus(
          emulatorHostWarning ??
              'The video server at $host:$port did not respond in time.',
        );
      }
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
          'The video server port $port is open on $host, but it did not answer as RTSP.',
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
          'Video server reached, but RTSP OPTIONS was rejected: ${optionsResponse.statusSummary}.',
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
          'RTSP delivery accepted by the video server at $host:$port.',
          success: true,
        );
        return;
      }

      if (describeResponse.statusCode == 401) {
        _setStreamProbeStatus(_authFailureMessage(describeResponse));
        return;
      }

      if (describeResponse.statusCode == 404) {
        _setStreamProbeStatus(
          'Video server reached, but this playback path was not found. Verify ${uri.path}.',
        );
        return;
      }

      if (describeResponse.isRtspResponse) {
        _setStreamProbeStatus(
          'Video server reached, but the playback URL was rejected: ${describeResponse.statusSummary}.',
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
            'Cannot connect to the video server at $host:$port: ${error.message}.';
        _streamProbeSucceeded = false;
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() {
        _streamProbeStatus =
            emulatorHostWarning ??
            'The video server at $host:$port did not answer the RTSP handshake in time.';
        _streamProbeSucceeded = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _streamProbeStatus =
            'Video server RTSP handshake failed for $host:$port: $error';
        _streamProbeSucceeded = false;
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
        ? '10.0.2.2 only points to the development computer from an Android emulator. Use the video server hostname on a physical phone.'
        : '$host points to this phone. Use the reachable video server hostname instead.';
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

  void _setStreamProbeStatus(String status, {bool success = false}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _streamProbeStatus = status;
      _streamProbeSucceeded = success;
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
      return 'Video server reached, but it requires Digest authentication. Use the server-provided playback URL or token.';
    }

    return 'Video server reached, but RTSP authentication was rejected. Check the server playback credentials.';
  }

  Future<void> _toggleRecording() async {
    if (_recordingBusy) {
      return;
    }
    if (_recordingRequested) {
      await _stopRecording();
    } else {
      setState(() => _recordingRequested = true);
      await _startRecording();
    }
  }

  Future<void> _startRecording({bool resumedAfterReconnect = false}) async {
    if (_recordingBusy || _isRecording || !_recordingRequested) {
      return;
    }

    setState(() => _recordingBusy = true);
    try {
      await _recorder.startRecording(
        _resolvedStreamUrl ?? await resolveCameraPlaybackUrl(widget.streamUrl),
        username: widget.recordingOwnerUsername,
      );
      final completion = _recorder.recordingCompletion;
      final segmentId = ++_recordingSegmentId;
      if (!mounted) {
        return;
      }
      final shouldPauseImmediately = _reportedConnectionOnline == false;
      setState(() {
        _isRecording = true;
        _recordingPausedForDisconnect = shouldPauseImmediately;
        _recordingElapsed = Duration.zero;
      });
      _recordingTicker?.cancel();
      _recordingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          return;
        }
        setState(() => _recordingElapsed = _recorder.recordingDuration);
      });
      if (completion != null) {
        unawaited(_watchRecordingCompletion(completion, segmentId));
      }
      _showRecordingSnack(
        resumedAfterReconnect
            ? 'Camera reconnected. Recording resumed in a new clip.'
            : 'Recording started in temporary internal storage for up to 24 hours. Keep this viewer open.',
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _recordingRequested = resumedAfterReconnect;
          _recordingPausedForDisconnect = resumedAfterReconnect;
        });
        _showRecordingSnack('Could not start recording: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _recordingBusy = false);
        if (_recordingPausedForDisconnect && _isRecording) {
          unawaited(_pauseRecordingForDisconnect());
        }
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_recordingRequested) return;
    setState(() => _recordingBusy = true);
    _recordingTicker?.cancel();
    _recordingTicker = null;
    setState(() {
      _recordingRequested = false;
      _recordingPausedForDisconnect = false;
    });
    if (!_recorder.isRecording) {
      setState(() {
        _isRecording = false;
        _recordingBusy = false;
        _recordingElapsed = Duration.zero;
      });
      return;
    }
    try {
      await _recorder.stopRecording();
    } catch (error) {
      if (mounted) {
        setState(() => _recordingBusy = false);
        _showRecordingSnack('Could not finalize recording: $error');
        if (_recorder.isRecording) {
          setState(() {
            _recordingRequested = true;
            _recordingPausedForDisconnect = false;
          });
          _recordingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) {
              setState(() => _recordingElapsed = _recorder.recordingDuration);
            }
          });
        }
      }
    }
  }

  /// FFmpeg cannot pause a live-stream-to-MP4 remux safely. Finalizing the current
  /// fragmented MP4 preserves the footage before a disconnect; a fresh clip
  /// is started once playback reconnects.
  Future<void> _pauseRecordingForDisconnect() async {
    if (!_recordingRequested) return;

    if (_recordingBusy) {
      if (mounted) {
        setState(() => _recordingPausedForDisconnect = true);
      }
      return;
    }

    if (!_isRecording || !_recorder.isRecording) {
      if (mounted) {
        setState(() => _recordingPausedForDisconnect = true);
      }
      return;
    }

    setState(() {
      _recordingPausedForDisconnect = true;
      _recordingBusy = true;
      _recordingElapsed = _recorder.recordingDuration;
    });
    _recordingTicker?.cancel();
    _recordingTicker = null;

    try {
      await _recorder.stopRecording();
      if (mounted) {
        _showRecordingSnack(
          'Camera disconnected. Recording paused and will resume when it reconnects.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _recordingBusy = false);
        _showRecordingSnack('Could not pause recording: $error');
      }
    }
  }

  Future<void> _resumeRecordingAfterReconnect() async {
    if (!_recordingRequested ||
        !_recordingPausedForDisconnect ||
        _recordingBusy ||
        _isRecording) {
      return;
    }
    await _startRecording(resumedAfterReconnect: true);
  }

  Future<void> _watchRecordingCompletion(
    Future<String?> completion,
    int segmentId,
  ) async {
    final outputPath = await completion;
    final completedCurrentSegment = segmentId == _recordingSegmentId;
    if (mounted && completedCurrentSegment) {
      _recordingTicker?.cancel();
      _recordingTicker = null;
      setState(() {
        _isRecording = false;
        _recordingBusy = false;
        if (!_recordingRequested) {
          _recordingElapsed = Duration.zero;
        } else {
          // A recorder exit while still armed is treated as an interrupted
          // segment. This also covers FFmpeg observing a dropped stream socket
          // a moment before the player reports the camera offline.
          _recordingPausedForDisconnect = true;
        }
      });
    }

    if (completedCurrentSegment &&
        _recordingRequested &&
        _recordingPausedForDisconnect &&
        _reportedConnectionOnline == true) {
      unawaited(_resumeRecordingAfterReconnect());
    }

    if (outputPath == null) {
      if (mounted) {
        _showRecordingSnack(
          'Recording stopped, but no video was saved (the stream may have failed).',
        );
      }
      return;
    }

    if (mounted) {
      _showRecordingSnack('Recording complete. Uploading to the server...');
    }
    final uploaded = await widget.controller.publishRecording(
      widget.recordingOwnerUsername,
      outputPath,
    );
    if (!mounted) return;
    _showRecordingSnack(
      uploaded
          ? 'Recording uploaded. It is now available to administrators.'
          : 'Upload pending. The recording is safe internally and will retry.',
    );
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

  Widget _detectionOverlay(Rect videoRect) {
    return Positioned.fromRect(
      rect: videoRect,
      child: IgnorePointer(
        child: CustomPaint(
          painter: ChickenDetectionPainter(detections: _liveDetections),
        ),
      ),
    );
  }

  String get _fullscreenAiStatus {
    if (!_aiScanningEnabled) {
      return _aiStatusMessage ??
          'AI scanning is off — live playback has priority.';
    }
    if (_inspectionRunning) {
      return 'AI is checking the current frame…';
    }
    return _aiStatusMessage ?? 'AI scanning is on.';
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
    final compactControls = viewSize.width < 600;

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
        clipBehavior: Clip.hardEdge,
        children: [
          if (_liveDetections.isNotEmpty) _detectionOverlay(texturePos),
          Positioned(
            // This panel only ever exists in the fully immersive fullscreen
            // route (system status/nav bars are hidden — see
            // _pushFullScreenWidget's `overlays: []`), so there's no real
            // system chrome left to dodge here — anchor straight to the
            // physical edges.
            top: 12,
            left: 12,
            right: 12,
            // mainAxisAlignment.spaceBetween, not a Spacer(), is what
            // actually guarantees the button cluster sits flush against the
            // right edge here. A Spacer() next to a same-flex Flexible(label)
            // splits the row's free space 50/50 between them up front; the
            // label (loose fit) then renders at its own smaller intrinsic
            // width and leaves its unused half of that split as dead space
            // in front of the buttons instead of handing it to the Spacer —
            // confirmed on-device: the row itself measured the full expected
            // width, but the button cluster stopped ~250px short of it, and
            // that gap was inert to taps. Grouping the buttons into their
            // own unflexed Row and letting spaceBetween place the two groups
            // avoids that flex split entirely.
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!compactControls)
                  Flexible(
                    child: SeverityTag(
                      label: widget.displayLabel ?? 'LIVE CCTV',
                      color: const Color(0xFF43E39C),
                    ),
                  )
                else
                  const Icon(Icons.circle, color: Color(0xFF43E39C), size: 11),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LiveFeedAiToggle(
                      enabled: _aiScanningEnabled,
                      compact: compactControls,
                      onPressed: _toggleAiScanning,
                    ),
                    const SizedBox(width: 8),
                    _LiveFeedRecordButton(
                      isRecording: _recordingRequested,
                      busy: _recordingBusy,
                      onPressed: _toggleRecording,
                    ),
                    if (_supportsOnvifPtz) ...[
                      const SizedBox(width: 8),
                      _LiveFeedIconButton(
                        tooltip: _showPtzControls
                            ? 'Hide PTZ controls'
                            : 'Show PTZ controls',
                        icon: _showPtzControls
                            ? Icons.control_camera
                            : Icons.control_camera_outlined,
                        onPressed: _togglePtzControls,
                      ),
                    ],
                    _LiveFeedIconButton(
                      tooltip: 'Exit full screen',
                      icon: Icons.fullscreen_exit,
                      onPressed: player.exitFullScreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_showPtzControls && _supportsOnvifPtz)
            Positioned(
              top: 68,
              bottom: 64,
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
            child: SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  constraints: BoxConstraints(maxWidth: viewSize.width * .7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _aiScanningEnabled
                            ? Icons.auto_awesome
                            : Icons.visibility_outlined,
                        color: _aiScanningEnabled
                            ? const Color(0xFFFFCE67)
                            : Colors.white70,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _fullscreenAiStatus,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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
    _stablePlaybackTimer?.cancel();
    _playbackWatchdogTimer?.cancel();
    _inspectionTimer?.cancel();
    unawaited(_bufferStateSubscription?.cancel());
    unawaited(_positionSubscription?.cancel());
    _recordingTicker?.cancel();
    _orientationResetTimer?.cancel();
    _recorder.dispose();
    _controller?.removeListener(_handlePlayerValueChanged);
    if (_controller case final controller?) {
      unawaited(controller.release().catchError((_) {}));
    }
    super.dispose();
  }

  void _notifyStreamStatusIfChanged() {
    final callback = widget.onStreamStatusChanged;
    if (callback == null) {
      return;
    }
    if (_streamProbeStatus == _lastNotifiedStreamProbeStatus &&
        _streamProbeSucceeded == _lastNotifiedStreamProbeSucceeded) {
      return;
    }
    _lastNotifiedStreamProbeStatus = _streamProbeStatus;
    _lastNotifiedStreamProbeSucceeded = _streamProbeSucceeded;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      callback(_streamProbeStatus, _streamProbeSucceeded);
    });
  }

  @override
  Widget build(BuildContext context) {
    _notifyStreamStatusIfChanged();
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
                            final viewport = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            final videoRect = _videoRectForViewport(
                              viewport,
                              value.size,
                              widget.videoFit,
                            );
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                KeyedSubtree(
                                  key: ValueKey(
                                    '${widget.streamUrl}|${_playbackProfile.name}|$_controllerGeneration',
                                  ),
                                  child: FijkView(
                                    player: controller,
                                    fit: widget.videoFit == BoxFit.contain
                                        ? FijkFit.contain
                                        : FijkFit.cover,
                                    fsFit: FijkFit.contain,
                                    fs: true,
                                    color: Colors.black,
                                    // An anonymous wrapper intentionally gets a
                                    // new identity when this widget rebuilds.
                                    // The plugin otherwise considers a method
                                    // tear-off unchanged and does not refresh
                                    // its separate fullscreen route when new
                                    // detection boxes arrive.
                                    panelBuilder:
                                        (
                                          player,
                                          data,
                                          context,
                                          viewSize,
                                          texturePos,
                                        ) => _liveFeedPanelBuilder(
                                          player,
                                          data,
                                          context,
                                          viewSize,
                                          texturePos,
                                        ),
                                  ),
                                ),
                                if (!value.videoRenderStart &&
                                    !_hasFijkError(value))
                                  const _LiveFeedPlaceholder(),
                                IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: borderRadius,
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
                                if (_liveDetections.isNotEmpty)
                                  _detectionOverlay(videoRect),
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
                top: 14,
                left: 14,
                right: 14,
                // mainAxisAlignment.spaceBetween (not a Spacer()) is what
                // actually guarantees the control cluster sits flush against
                // the right edge: a Spacer() next to a same-flex
                // Flexible(label) splits the row's free space 50/50 between
                // them up front, and the label — rendering at its own
                // smaller intrinsic width — leaves its unused half as dead,
                // untappable space in front of the controls instead of
                // handing it back to the Spacer (confirmed on the
                // fullscreen panel below, which had this exact bug).
                // Grouping the controls into their own unflexed Row and
                // letting spaceBetween place the two groups avoids the flex
                // split entirely.
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.showLabelOverlay)
                      Flexible(
                        child: SeverityTag(
                          label: widget.displayLabel ?? 'LIVE CCTV',
                          color: const Color(0xFF43E39C),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LiveFeedAiToggle(
                          enabled: _aiScanningEnabled,
                          compact: true,
                          onPressed: _supportsFijkPlayer && controller != null
                              ? _toggleAiScanning
                              : null,
                        ),
                        const SizedBox(width: 8),
                        _LiveFeedRecordButton(
                          isRecording: _recordingRequested,
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
                          profiles: _availablePlaybackProfiles,
                          onSelected: _selectPlaybackProfile,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_recordingRequested)
                Positioned(
                  top: 54,
                  left: 14,
                  child: _RecordingIndicator(
                    label: _formatRecordingElapsed(_recordingElapsed),
                    paused: _recordingPausedForDisconnect,
                  ),
                ),
              if (widget.showEndpointOverlay)
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
                        safePlaybackEndpointLabel(widget.streamUrl),
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
              if (widget.showStreamProbeOverlay && _streamProbeStatus != null)
                Positioned(
                  left: 18,
                  right: 18,
                  // Sits just above the endpoint overlay when that's shown;
                  // otherwise it can drop all the way to the bottom edge
                  // instead of floating mid-frame over the placeholder text.
                  bottom: widget.showEndpointOverlay ? 58 : 18,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _streamProbeSucceeded
                            ? const Color(0xCC134F36)
                            : const Color(0xCC5A1D24),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _streamProbeStatus!,
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

class _LiveFeedAiToggle extends StatelessWidget {
  const _LiveFeedAiToggle({
    required this.enabled,
    required this.onPressed,
    this.compact = false,
  });

  final bool enabled;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? const Color(0xFFFFCE67)
        : onPressed == null
        ? Colors.white38
        : Colors.white70;
    return Tooltip(
      message: enabled ? 'Disable AI scanning' : 'Enable AI scanning',
      child: Material(
        color: enabled
            ? const Color(0x995C4610)
            : Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 38),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 11 : 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    enabled ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                    color: foreground,
                    size: 18,
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 7),
                    Text(
                      enabled ? 'AI On' : 'AI Off',
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
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
  const _RecordingIndicator({required this.label, this.paused = false});

  final String label;
  final bool paused;

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
            decoration: BoxDecoration(
              color: paused ? const Color(0xFFFFCE67) : _appAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            paused ? 'PAUSED' : 'REC',
            style: const TextStyle(
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
    required this.profiles,
    required this.onSelected,
  });

  final _LiveFeedPlaybackProfile selectedProfile;
  final List<_LiveFeedPlaybackProfile> profiles;
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
            for (final profile in profiles)
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
            'Live cloud-stream playback is enabled for Android and iOS builds.',
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
