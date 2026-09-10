part of '../../main.dart';

const _configuredV380BackendUrl = String.fromEnvironment(
  'V380_BACKEND_URL',
  defaultValue: 'https://api.roostify.com',
);
const _configuredV380BackendApiKey = String.fromEnvironment(
  'V380_BACKEND_API_KEY',
);

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

/// Connects V380 camera entries to the long-lived C# decoder backend.
///
/// The app keeps the existing `v380://` source format, but proprietary relay
/// discovery and decoding now happen in `cs_tmp/v380connectorbackend`. The
/// backend returns public WebRTC/WHEP and optional RTSP delivery URLs. The
/// Hostinger deployment keeps RTSP private and uses WebRTC for mobile video.
class V380CloudBridgeRegistry {
  V380CloudBridgeRegistry._({V380BackendClient? backend})
    : _backend = backend ?? V380BackendClient.fromEnvironment();

  static final instance = V380CloudBridgeRegistry._();

  final V380BackendClient _backend;
  final Map<String, _V380BackendCameraSession> _sessions = {};

  Future<String> resolve(String sourceUrl) async {
    if (Uri.tryParse(sourceUrl)?.scheme.toLowerCase() != 'v380') {
      return sourceUrl;
    }

    final session = _sessions.putIfAbsent(
      sourceUrl,
      () => _V380BackendCameraSession(
        backend: _backend,
        config: V380CloudCameraConfig.parse(sourceUrl),
      ),
    );
    try {
      return await session.connect();
    } catch (_) {
      if (identical(_sessions[sourceUrl], session)) {
        _sessions.remove(sourceUrl);
      }
      rethrow;
    }
  }

  Future<String> resolveWebRtc(String sourceUrl) async {
    if (Uri.tryParse(sourceUrl)?.scheme.toLowerCase() != 'v380') {
      return sourceUrl;
    }

    final session = _sessions.putIfAbsent(
      sourceUrl,
      () => _V380BackendCameraSession(
        backend: _backend,
        config: V380CloudCameraConfig.parse(sourceUrl),
      ),
    );
    try {
      return (await session.waitUntilOnline()).webRtcPlaybackUrl(
        _backend.baseUri,
      );
    } catch (_) {
      if (identical(_sessions[sourceUrl], session)) {
        _sessions.remove(sourceUrl);
      }
      rethrow;
    }
  }

  Future<void> stop(String sourceUrl) async {
    final session = _sessions.remove(sourceUrl);
    if (session == null) return;
    try {
      await session.disconnect();
    } catch (_) {
      // Removing the local camera entry must still succeed if the backend is
      // temporarily unavailable or already discarded the session.
    }
  }

  Future<String?> statusFor(String sourceUrl) async {
    final session = _sessions[sourceUrl];
    if (session == null) return null;
    try {
      return await session.refreshStatus();
    } catch (error) {
      return _friendlyV380BackendError(error);
    }
  }

  Future<void> closeAll() {
    // Camera sessions belong to the long-lived backend, not to one app
    // process. Explicit camera removal still calls [stop], but closing the app
    // must not interrupt other viewers using the same backend stream.
    _sessions.clear();
    return Future<void>.value();
  }
}

Future<String> resolveCameraPlaybackUrl(String sourceUrl) {
  return V380CloudBridgeRegistry.instance.resolve(sourceUrl);
}

Future<String> resolveCameraWebRtcUrl(String sourceUrl) {
  return V380CloudBridgeRegistry.instance.resolveWebRtc(sourceUrl);
}

class _V380BackendCameraSession {
  _V380BackendCameraSession({required this.backend, required this.config});

  final V380BackendClient backend;
  final V380CloudCameraConfig config;
  Future<String>? _pendingConnect;
  Future<V380BackendCameraStatus>? _pendingStatus;

  Future<String> connect() {
    final pending = _pendingConnect;
    if (pending != null) return pending;

    late final Future<String> operation;
    operation = backend
        .connectCamera(config)
        .then((status) => status.playbackUrl(backend.baseUri))
        .whenComplete(() {
          if (identical(_pendingConnect, operation)) {
            _pendingConnect = null;
          }
        });
    _pendingConnect = operation;
    return operation;
  }

  Future<V380BackendCameraStatus> connectStatus() {
    final pending = _pendingStatus;
    if (pending != null) return pending;

    late final Future<V380BackendCameraStatus> operation;
    operation = backend.connectCamera(config).whenComplete(() {
      if (identical(_pendingStatus, operation)) {
        _pendingStatus = null;
      }
    });
    _pendingStatus = operation;
    return operation;
  }

  Future<V380BackendCameraStatus> waitUntilOnline() async {
    var status = await connectStatus();
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (status.status != 'online') {
      if (status.status == 'offline') {
        throw V380BackendException(
          status.lastError?.trim().isNotEmpty == true
              ? status.lastError!.trim()
              : 'The V380 camera is offline.',
        );
      }
      if (DateTime.now().isAfter(deadline)) {
        throw const V380BackendException(
          'The V380 camera did not become ready within 30 seconds.',
        );
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      status = await backend.cameraStatus(config.deviceId);
    }
    return status;
  }

  Future<String> refreshStatus() async {
    final status = await backend.cameraStatus(config.deviceId);
    return status.userMessage;
  }

  Future<void> disconnect() async {
    await backend.disconnectCamera(config.deviceId);
  }
}

class V380BackendCameraStatus {
  const V380BackendCameraStatus({
    required this.cameraId,
    required this.status,
    required this.rtspUrl,
    required this.webRtcUrl,
    required this.lastError,
  });

  final String cameraId;
  final String status;
  final String? rtspUrl;
  final String? webRtcUrl;
  final String? lastError;

  factory V380BackendCameraStatus.fromJson(Map<String, dynamic> json) {
    final cameraId = json['cameraId'];
    final status = json['status'];
    if (cameraId is! String || cameraId.isEmpty || status is! String) {
      throw const FormatException(
        'The V380 decoder returned an invalid camera status.',
      );
    }
    return V380BackendCameraStatus(
      cameraId: cameraId,
      status: status.toLowerCase(),
      rtspUrl: json['rtspUrl'] as String?,
      webRtcUrl: json['webRtcUrl'] as String?,
      lastError: json['lastError'] as String?,
    );
  }

  String playbackUrl(Uri backendUri) {
    final value = rtspUrl?.trim() ?? '';
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.host.isEmpty ||
        !const {'rtsp', 'rtsps'}.contains(uri.scheme.toLowerCase())) {
      throw const FormatException(
        'The V380 decoder did not return a valid RTSP playback URL.',
      );
    }

    // The backend defaults to localhost for desktop development. When the API
    // is reached through another host (for example 10.0.2.2 on an Android
    // emulator), that API host is also the reachable MediaMTX host.
    if (_isLoopbackHost(uri.host) && !_isLoopbackHost(backendUri.host)) {
      return uri.replace(host: backendUri.host).toString();
    }
    return uri.toString();
  }

  String webRtcPlaybackUrl(Uri backendUri) {
    final value = webRtcUrl?.trim() ?? '';
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.host.isEmpty ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        !uri.path.endsWith('/whep')) {
      throw const FormatException(
        'The V380 decoder did not return a valid WebRTC/WHEP playback URL.',
      );
    }

    if (_isLoopbackHost(uri.host) && !_isLoopbackHost(backendUri.host)) {
      return uri.replace(host: backendUri.host).toString();
    }
    return uri.toString();
  }

  String get userMessage {
    final detail = lastError?.trim();
    return switch (status) {
      'online' =>
        'V380 camera $cameraId is streaming through the decoder backend.',
      'connecting' =>
        'The decoder backend is connecting to V380 camera $cameraId…',
      'reconnecting' =>
        detail?.isNotEmpty == true
            ? 'The decoder backend is reconnecting: $detail'
            : 'The decoder backend is reconnecting to V380 camera $cameraId…',
      'stopping' => 'The decoder backend is stopping V380 camera $cameraId.',
      'offline' =>
        detail?.isNotEmpty == true
            ? 'V380 camera $cameraId is offline: $detail'
            : 'V380 camera $cameraId is offline.',
      _ => 'V380 camera $cameraId has backend status “$status”.',
    };
  }
}

class V380BackendClient {
  V380BackendClient({required String baseUrl, String apiKey = ''})
    : baseUri = _parseBaseUri(baseUrl),
      _apiKey = apiKey;

  factory V380BackendClient.fromEnvironment() => V380BackendClient(
    baseUrl: _configuredV380BackendUrl,
    apiKey: _configuredV380BackendApiKey,
  );

  final Uri baseUri;
  final String _apiKey;

  Future<V380BackendCameraStatus> connectCamera(
    V380CloudCameraConfig config,
  ) async {
    final response = await _request(
      'POST',
      '/api/cameras/connect',
      body: {
        'cameraId': config.deviceId.toString(),
        if (config.username.isNotEmpty) 'username': config.username,
        if (config.password.isNotEmpty) 'password': config.password,
        'source': 'cloud',
      },
    );
    return V380BackendCameraStatus.fromJson(response);
  }

  Future<V380BackendCameraStatus> cameraStatus(int deviceId) async {
    final response = await _request(
      'GET',
      '/api/cameras/${Uri.encodeComponent(deviceId.toString())}/status',
    );
    return V380BackendCameraStatus.fromJson(response);
  }

  Future<void> disconnectCamera(int deviceId) async {
    await _request(
      'POST',
      '/api/cameras/${Uri.encodeComponent(deviceId.toString())}/disconnect',
      allowEmptyResponse: true,
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String route, {
    Map<String, dynamic>? body,
    bool allowEmptyResponse = false,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    final endpoint = Uri.parse(
      '${baseUri.toString().replaceFirst(RegExp(r'/$'), '')}$route',
    );
    try {
      final request = await client.openUrl(method, endpoint);
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      if (_apiKey.isNotEmpty) {
        request.headers.set('X-API-Key', _apiKey);
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final responseBody = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw V380BackendException(
          _backendFailureMessage(response.statusCode, responseBody),
        );
      }
      if (responseBody.trim().isEmpty && allowEmptyResponse) {
        return const {};
      }
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'The V380 decoder returned an invalid JSON response.',
        );
      }
      return decoded;
    } on TimeoutException {
      throw const V380BackendException(
        'The V380 decoder backend did not respond in time.',
      );
    } on SocketException catch (error) {
      throw V380BackendException(
        'Cannot reach the V380 decoder backend at ${baseUri.host}:${baseUri.port}: ${error.message}',
      );
    } finally {
      client.close(force: true);
    }
  }
}

class V380BackendException implements Exception {
  const V380BackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

Uri _parseBaseUri(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.host.isEmpty ||
      !const {'http', 'https'}.contains(uri.scheme.toLowerCase())) {
    throw const FormatException(
      'V380_BACKEND_URL must be an absolute HTTP or HTTPS URL.',
    );
  }
  return uri.replace(
    path: uri.path.replaceFirst(RegExp(r'/$'), ''),
    query: null,
    fragment: null,
  );
}

bool _isLoopbackHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}

String _backendFailureMessage(int statusCode, String responseBody) {
  String? detail;
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is Map<String, dynamic>) {
      detail = decoded['error'] as String?;
    }
  } catch (_) {
    // Fall back to a status-only message for non-JSON proxy responses.
  }
  if (detail?.trim().isNotEmpty == true) return detail!.trim();
  return switch (statusCode) {
    401 || 403 => 'The V380 decoder backend rejected the API key.',
    404 => 'The V380 camera session was not found by the decoder backend.',
    _ => 'The V380 decoder backend returned HTTP $statusCode.',
  };
}

String _friendlyV380BackendError(Object error) {
  if (error is V380BackendException) return error.message;
  if (error is FormatException) return error.message;
  return 'V380 decoder backend request failed: $error';
}
