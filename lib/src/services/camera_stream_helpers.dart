part of '../../main.dart';

_CameraCredentials _cameraCredentialsFromRtspUrl(String streamUrl) {
  final uri = Uri.tryParse(streamUrl);
  final userInfo = uri?.userInfo ?? '';
  if (userInfo.isEmpty) {
    return const _CameraCredentials(username: '', password: '');
  }

  final separatorIndex = userInfo.indexOf(':');
  if (separatorIndex == -1) {
    return _CameraCredentials(
      username: Uri.decodeComponent(userInfo),
      password: '',
    );
  }

  return _CameraCredentials(
    username: Uri.decodeComponent(userInfo.substring(0, separatorIndex)),
    password: Uri.decodeComponent(userInfo.substring(separatorIndex + 1)),
  );
}

class _CameraCredentials {
  const _CameraCredentials({required this.username, required this.password});

  final String username;
  final String password;
}

Future<_RtspProbeResponse> _sendRtspProbeRequest(
  Uri uri, {
  required String method,
  required int cSeq,
  bool includeSdpAccept = false,
  Duration connectTimeout = const Duration(seconds: 3),
  Duration responseTimeout = const Duration(seconds: 4),
}) async {
  final host = uri.host;
  final port = uri.hasPort ? uri.port : 554;
  final socket = await Socket.connect(host, port, timeout: connectTimeout);

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
    try {
      await for (final chunk in socket.timeout(responseTimeout)) {
        responseBytes.addAll(chunk);
        final responseText = latin1.decode(responseBytes, allowInvalid: true);
        if (responseText.contains('\r\n\r\n') || responseBytes.length > 8192) {
          break;
        }
      }
    } on TimeoutException {
      if (responseBytes.isEmpty) {
        return const _RtspProbeResponse(
          statusLine: 'No response',
          statusCode: null,
          headers: {},
        );
      }
    }

    return _RtspProbeResponse.parse(
      latin1.decode(responseBytes, allowInvalid: true),
    );
  } finally {
    socket.destroy();
  }
}

String _buildRtspUrl({
  required String host,
  required int port,
  required String path,
  required String username,
  required String password,
}) {
  final cleanUsername = username.trim();
  final userInfo = cleanUsername.isEmpty
      ? ''
      : '${Uri.encodeComponent(cleanUsername)}:${Uri.encodeComponent(password)}@';
  final cleanPath = _normalizeRtspPath(path);

  return 'rtsp://$userInfo$host:$port$cleanPath';
}

String _normalizeRtspPath(String path) {
  final cleanPath = path.trim();
  if (cleanPath.isEmpty) {
    return '/';
  }

  return cleanPath.startsWith('/') ? cleanPath : '/$cleanPath';
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
