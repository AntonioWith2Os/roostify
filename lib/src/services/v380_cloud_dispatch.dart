part of '../../main.dart';

/// Locates a V380 camera directly on V380's own cloud dispatch service, with
/// no Roostify backend involved. Dart port of
/// `cs_tmp/V380Decoder/src/DispatchRelayServer.cs`.
///
/// Given a device ID, asks `dispa1.av380.net` which relay server is currently
/// serving that camera, then confirms the relay is actually reachable before
/// returning it - exactly what the standalone decoder does.
class V380CloudDispatch {
  const V380CloudDispatch();

  static const _dispatchUrl =
      'http://dispa1.av380.net:8001/api/v1/get_stream_server';
  static const _relayPort = 8800;

  Future<String?> resolveRelayIp(
    int deviceId, {
    Duration reachabilityTimeout = const Duration(seconds: 3),
  }) async {
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    const platform = 10001; // 20001 is the pano-device variant, unused here.
    final baseString =
        'dev_id=$deviceId&platform=$platform&timestamp=${timestamp}hsdata2022';
    final sign = sha1.convert(utf8.encode(baseString)).toString();

    final body = jsonEncode({
      'dev_id': deviceId,
      'platform': platform,
      'timestamp': timestamp,
      'sign': sign,
    });

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.postUrl(Uri.parse(_dispatchUrl));
      request.headers.contentType = ContentType.json;
      request.write(body);
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        return null;
      }

      final responseBody = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['code'] != 2000) return null;

      final candidates = decoded['data'];
      if (candidates is! List) return null;

      for (final candidate in candidates) {
        if (candidate is! Map<String, dynamic>) continue;
        final ip = candidate['ip'];
        if (ip is! String || ip.isEmpty) continue;
        if (await _isReachable(ip, _relayPort, reachabilityTimeout)) {
          return ip;
        }
      }
      return null;
    } on SocketException {
      return null;
    } on TimeoutException {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _isReachable(String ip, int port, Duration timeout) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
