part of '../../main.dart';

/// The camera-side settings encoded by a `v380://` source URL.
class V380CloudCameraConfig {
  const V380CloudCameraConfig({
    required this.deviceId,
    this.username = '',
    this.password = '',
  });

  final int deviceId;
  final String username;
  final String password;

  factory V380CloudCameraConfig.parse(String sourceUrl) {
    final error = v380CloudCameraValidationError(sourceUrl);
    if (error != null) throw FormatException(error);
    final uri = Uri.parse(sourceUrl);
    final separator = uri.userInfo.indexOf(':');
    return V380CloudCameraConfig(
      deviceId: int.parse(uri.host),
      username: Uri.decodeComponent(
        separator < 0 ? uri.userInfo : uri.userInfo.substring(0, separator),
      ),
      password: separator < 0
          ? ''
          : Uri.decodeComponent(uri.userInfo.substring(separator + 1)),
    );
  }
}

/// Connects V380 cloud camera entries entirely on-device - no Roostify
/// backend is involved. The app keeps the existing `v380://` source format,
/// but locating the camera on V380's own cloud relay ([V380CloudDispatch]),
/// speaking the V380 protocol ([V380ProtocolClient]), and re-serving the
/// decoded stream ([V380LocalRtspServer]) all now happen inside this process.
///
/// `resolve()`/`resolveWebRtc()` both return a loopback `rtsp` URL (host
/// `127.0.0.1`, an ephemeral port) once the on-device session is up, so every
/// existing player call site (`FijkPlayer.setDataSource`) keeps working
/// unchanged.
class V380CloudBridgeRegistry {
  V380CloudBridgeRegistry._();

  static final instance = V380CloudBridgeRegistry._();

  final Map<String, _V380OnDeviceCameraSession> _sessions = {};

  Future<String> resolve(String sourceUrl) async {
    if (Uri.tryParse(sourceUrl)?.scheme.toLowerCase() != 'v380') {
      return sourceUrl;
    }

    final session = _sessions.putIfAbsent(
      sourceUrl,
      () => _V380OnDeviceCameraSession(
        config: V380CloudCameraConfig.parse(sourceUrl),
      ),
    );
    try {
      return await session.connect();
    } catch (_) {
      if (identical(_sessions[sourceUrl], session)) {
        _sessions.remove(sourceUrl);
      }
      unawaited(session.dispose());
      rethrow;
    }
  }

  /// No separate WebRTC/WHEP delivery exists on-device - this resolves the
  /// same local RTSP URL as [resolve].
  Future<String> resolveWebRtc(String sourceUrl) => resolve(sourceUrl);

  Future<void> stop(String sourceUrl) async {
    final session = _sessions.remove(sourceUrl);
    if (session == null) return;
    try {
      await session.dispose();
    } catch (_) {
      // Removing the local camera entry must still succeed even if the
      // on-device session was already gone or failed to tear down cleanly.
    }
  }

  Future<String?> statusFor(String sourceUrl) async {
    final session = _sessions[sourceUrl];
    if (session == null) return null;
    return session.userMessage;
  }

  /// Whether the on-device bridge session for [sourceUrl] currently reports
  /// itself online, straight from its live connection state - independent of
  /// whether a [LiveFeedCard] happens to be mounted for it, since the session
  /// keeps running/reconnecting in the background once started. Null means no
  /// session has been started for this camera yet this run (genuinely
  /// unknown, not confirmed offline).
  bool? isKnownOnline(String sourceUrl) {
    final session = _sessions[sourceUrl];
    if (session == null) return null;
    return session._status == V380ConnectionState.online;
  }

  Future<void> closeAll() async {
    final sessions = _sessions.values.toList();
    _sessions.clear();
    await Future.wait(
      sessions.map((session) => session.dispose().catchError((_) {})),
    );
  }
}

Future<String> resolveCameraPlaybackUrl(String sourceUrl) {
  return V380CloudBridgeRegistry.instance.resolve(sourceUrl);
}

Future<String> resolveCameraWebRtcUrl(String sourceUrl) {
  return V380CloudBridgeRegistry.instance.resolveWebRtc(sourceUrl);
}

class _V380OnDeviceCameraSession {
  _V380OnDeviceCameraSession({required this.config});

  final V380CloudCameraConfig config;
  static const _dispatch = V380CloudDispatch();

  V380LocalRtspServer? _rtspServer;
  V380ProtocolClient? _protocolClient;
  StreamSubscription<V380Frame>? _frameSub;
  StreamSubscription<(V380ConnectionState, String?)>? _stateSub;

  Future<String>? _pendingConnect;
  V380ConnectionState _status = V380ConnectionState.connecting;
  String? _lastError;
  bool _disposed = false;

  String get _streamPath => '/camera/${config.deviceId}';

  Future<String> connect() {
    final pending = _pendingConnect;
    if (pending != null) return pending;

    late final Future<String> operation;
    operation = _connect().whenComplete(() {
      if (identical(_pendingConnect, operation)) {
        _pendingConnect = null;
      }
    });
    _pendingConnect = operation;
    return operation;
  }

  Future<String> _connect() async {
    if (_protocolClient != null && _rtspServer != null) {
      // A session is already starting/started for this camera - reuse it.
      if (_status == V380ConnectionState.online) return _playbackUrl();
      await _waitUntilOnline();
      return _playbackUrl();
    }

    _status = V380ConnectionState.connecting;
    _lastError = null;

    final relayIp = await _dispatch.resolveRelayIp(config.deviceId);
    if (_disposed)
      throw const V380BackendException('The camera session was stopped.');
    if (relayIp == null) {
      _status = V380ConnectionState.offline;
      _lastError = 'No reachable V380 cloud relay was found for this camera.';
      throw V380BackendException(_lastError!);
    }

    final rtspServer = V380LocalRtspServer(streamPath: _streamPath);
    await rtspServer.start();
    _rtspServer = rtspServer;

    final client = V380ProtocolClient(
      initialIp: relayIp,
      resolveIp: () => _dispatch.resolveRelayIp(config.deviceId),
      deviceId: config.deviceId,
      username: config.username.isEmpty ? 'admin' : config.username,
      password: config.password,
    );
    _protocolClient = client;

    _frameSub = client.frames.listen((frame) {
      if (frame.isVideo) {
        rtspServer.pushVideo(frame);
      } else {
        rtspServer.pushAudio(frame);
      }
    });
    _stateSub = client.connectionState.listen((event) {
      _status = event.$1;
      // Every reconnect loop in V380ProtocolClient.run() starts by notifying
      // (connecting, null) again, which would otherwise wipe out the
      // specific reason the *previous* attempt failed right before
      // _waitUntilOnline's deadline expires - leaving only the generic "did
      // not become ready" message instead of whatever actually went wrong.
      if (event.$2 != null) _lastError = event.$2;
    });

    unawaited(client.run());

    await _waitUntilOnline();
    return _playbackUrl();
  }

  Future<void> _waitUntilOnline() async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (_status != V380ConnectionState.online) {
      if (_disposed) {
        throw const V380BackendException('The camera session was stopped.');
      }
      if (_status == V380ConnectionState.authenticationFailed) {
        throw V380BackendException(
          _lastError?.trim().isNotEmpty == true
              ? _lastError!.trim()
              : 'The camera rejected the device ID or credentials.',
        );
      }
      if (DateTime.now().isAfter(deadline)) {
        throw V380BackendException(
          _lastError?.trim().isNotEmpty == true
              ? _lastError!.trim()
              : 'The V380 camera did not become ready within 30 seconds.',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  String _playbackUrl() => 'rtsp://127.0.0.1:${_rtspServer!.port}$_streamPath';

  String get userMessage {
    final detail = _lastError?.trim();
    return switch (_status) {
      V380ConnectionState.online =>
        'V380 camera ${config.deviceId} is streaming directly from this device.',
      V380ConnectionState.connecting =>
        'Locating V380 camera ${config.deviceId} on the V380 cloud…',
      V380ConnectionState.reconnecting =>
        detail?.isNotEmpty == true
            ? 'Reconnecting to V380 camera ${config.deviceId}: $detail'
            : 'Reconnecting to V380 camera ${config.deviceId}…',
      V380ConnectionState.authenticationFailed =>
        detail?.isNotEmpty == true
            ? 'V380 camera ${config.deviceId} rejected the connection: $detail'
            : 'V380 camera ${config.deviceId} rejected the connection.',
      V380ConnectionState.offline =>
        detail?.isNotEmpty == true
            ? 'V380 camera ${config.deviceId} is offline: $detail'
            : 'V380 camera ${config.deviceId} is offline.',
    };
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _status = V380ConnectionState.offline;
    await _frameSub?.cancel();
    await _stateSub?.cancel();
    _protocolClient?.stop();
    await _protocolClient?.dispose();
    await _rtspServer?.stop();
  }
}

class V380BackendException implements Exception {
  const V380BackendException(this.message);

  final String message;

  @override
  String toString() => message;
}
