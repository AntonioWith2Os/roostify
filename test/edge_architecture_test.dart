import 'dart:convert';
import 'dart:io';

import 'package:coolapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('cloud playback endpoint validation keeps camera credentials out', () {
    expect(
      cloudPlaybackUrlValidationError(
        'https://media.roostify.example/live/farm-1/index.m3u8?token=abc',
      ),
      isNull,
    );
    expect(
      cloudPlaybackUrlValidationError(
        'rtsp://media.roostify.example:8554/farm-1',
      ),
      isNull,
    );
    expect(
      cloudPlaybackUrlValidationError(
        'rtsp://camera-user:camera-pass@192.168.1.20/live',
      ),
      contains('usernames or passwords'),
    );
    expect(
      cloudPlaybackUrlValidationError('ftp://media.example/live'),
      contains('HLS/HTTP'),
    );
  });

  test('display label hides cloud playback query tokens', () {
    expect(
      safePlaybackEndpointLabel(
        'https://media.roostify.example/live/farm-1/index.m3u8?token=secret',
      ),
      'https://media.roostify.example/live/farm-1/index.m3u8',
    );
  });

  test('V380 Cloud source round-trips credentials without displaying them', () {
    final source = buildV380CloudCameraUri(
      deviceId: '12345678',
      username: 'admin',
      password: 'secret:@ value',
    );

    expect(v380CloudCameraValidationError(source), isNull);
    expect(videoDeliveryProtocolFor(source), VideoDeliveryProtocol.v380Cloud);
    expect(safePlaybackEndpointLabel(source), 'V380 Cloud camera 12345678');
    expect(source, isNot(contains('secret:@ value')));
    final parsed = V380CloudCameraConfig.parse(source);
    expect(parsed.deviceId, 12345678);
    expect(parsed.username, 'admin');
    expect(parsed.password, 'secret:@ value');
  });

  test('new V380 Cloud sources keep camera credentials on the backend', () {
    final source = buildV380CloudCameraUri(deviceId: '12345678');

    expect(source, 'v380://12345678');
    expect(v380CloudCameraValidationError(source), isNull);
    final parsed = V380CloudCameraConfig.parse(source);
    expect(parsed.deviceId, 12345678);
    expect(parsed.username, isEmpty);
    expect(parsed.password, isEmpty);
  });

  test('V380 backend status uses the API host for loopback RTSP URLs', () {
    final status = V380BackendCameraStatus.fromJson({
      'cameraId': '12345678',
      'status': 'online',
      'rtspUrl': 'rtsp://localhost:8554/camera/12345678',
      'webRtcUrl': 'https://stream.example.com/camera/12345678/whep',
      'lastError': null,
    });

    expect(
      status.playbackUrl(Uri.parse('https://decoder.example.com:8080')),
      'rtsp://decoder.example.com:8554/camera/12345678',
    );
    expect(status.userMessage, contains('is streaming'));
    expect(
      status.webRtcPlaybackUrl(Uri.parse('https://api.example.com')),
      'https://stream.example.com/camera/12345678/whep',
    );
  });

  test('V380 WebRTC loopback URL keeps the MediaMTX port', () {
    final status = V380BackendCameraStatus.fromJson({
      'cameraId': '12345678',
      'status': 'online',
      'rtspUrl': null,
      'webRtcUrl': 'http://localhost:8889/camera/12345678/whep',
      'lastError': null,
    });

    expect(
      status.webRtcPlaybackUrl(Uri.parse('http://10.0.2.2:8080')),
      'http://10.0.2.2:8889/camera/12345678/whep',
    );
  });

  test(
    'V380 backend client connects, checks status, and disconnects',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requests =
          <({String method, String path, String apiKey, String body})>[];
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        requests.add((
          method: request.method,
          path: request.uri.path,
          apiKey: request.headers.value('X-API-Key') ?? '',
          body: body,
        ));
        if (request.uri.path.endsWith('/disconnect')) {
          request.response.statusCode = HttpStatus.noContent;
        } else {
          request.response
            ..statusCode = request.method == 'POST'
                ? HttpStatus.accepted
                : HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'cameraId': '12345678',
                'status': request.method == 'POST' ? 'connecting' : 'online',
                'rtspUrl': 'rtsp://127.0.0.1:8554/camera/12345678',
                'webRtcUrl': 'http://127.0.0.1:8889/camera/12345678/whep',
                'lastError': null,
              }),
            );
        }
        await request.response.close();
      });

      final client = V380BackendClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        apiKey: 'test-key',
      );
      const config = V380CloudCameraConfig(deviceId: 12345678);

      final realHttp = _RealHttpOverrides();
      late V380BackendCameraStatus connected;
      late V380BackendCameraStatus current;
      await HttpOverrides.runZoned(() async {
        connected = await client.connectCamera(config);
        current = await client.cameraStatus(config.deviceId);
        await client.disconnectCamera(config.deviceId);
      }, createHttpClient: realHttp.createHttpClient);

      expect(connected.status, 'connecting');
      expect(current.status, 'online');
      expect(requests.map((request) => '${request.method} ${request.path}'), [
        'POST /api/cameras/connect',
        'GET /api/cameras/12345678/status',
        'POST /api/cameras/12345678/disconnect',
      ]);
      expect(requests.every((request) => request.apiKey == 'test-key'), isTrue);
      expect(jsonDecode(requests.first.body), {
        'cameraId': '12345678',
        'source': 'cloud',
      });
    },
  );

  test('controller accepts a V380 Cloud device source', () {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(cameras: const []);
    addTearDown(controller.dispose);
    final user = controller.userByUsername('user1')!;

    expect(
      controller.addLiveCctvStream(
        user.username,
        buildV380CloudCameraUri(
          deviceId: '12345678',
          username: 'admin',
          password: 'camera-password',
        ),
        label: 'Coop Cloud',
      ),
      isTrue,
    );
    expect(user.liveCctvStreams.single.label, 'Coop Cloud');
    expect(
      user.liveCctvStreams.single.deliveryProtocol,
      VideoDeliveryProtocol.v380Cloud,
    );
  });

  test('controller accepts video-server delivery protocols', () {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(cameras: const []);
    addTearDown(controller.dispose);
    final user = controller.userByUsername('user1')!;

    expect(
      controller.addLiveCctvStream(
        user.username,
        'https://media.example/live/user1/index.m3u8',
        label: 'Main Pen',
      ),
      isTrue,
    );
    expect(user.liveCctvStreams.single.label, 'Main Pen');
    expect(
      user.liveCctvStreams.single.deliveryProtocol,
      VideoDeliveryProtocol.hlsOrHttp,
    );
  });

  testWidgets('camera setup supports cloud streams and local scanning', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(cameras: const []);
    addTearDown(controller.dispose);
    final user = controller.userByUsername('user1')!;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: CctvManagementSheet(controller: controller, user: user),
        ),
      ),
    );

    expect(find.text('Manage Cameras'), findsOneWidget);
    expect(find.text('Cloud playback URL'), findsOneWidget);
    expect(find.text('Add Cloud Stream'), findsOneWidget);
    expect(find.text('Scan local network'), findsOneWidget);
    expect(find.text('Port-forwarded camera'), findsOneWidget);
    expect(find.text('V380 Cloud camera'), findsOneWidget);

    await tester.tap(find.text('V380 Cloud camera'));
    await tester.pumpAndSettle();
    expect(find.text('V380 device ID'), findsOneWidget);
    expect(find.text('Connect V380 Camera'), findsOneWidget);
    expect(find.text('Camera username'), findsNothing);
    expect(find.text('Camera password'), findsNothing);
    await tester.tap(find.text('V380 Cloud camera'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Scan local network'));
    await tester.tap(find.text('Scan local network'));
    await tester.pumpAndSettle();
    expect(find.text('Scan Cameras'), findsOneWidget);

    await tester.ensureVisible(find.text('Port-forwarded camera'));
    await tester.tap(find.text('Port-forwarded camera'));
    await tester.pumpAndSettle();
    expect(find.text('Public IP or hostname'), findsOneWidget);
    expect(find.text('Test & Find Stream'), findsOneWidget);
  });

  test('controller accepts a direct local RTSP camera with credentials', () {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(cameras: const []);
    addTearDown(controller.dispose);
    final user = controller.userByUsername('user1')!;

    expect(
      controller.addLiveCctvStream(
        user.username,
        'rtsp://camera:secret@192.168.1.20:554/live',
        allowDirectRtspCamera: true,
      ),
      isTrue,
    );
    expect(
      user.liveCctvStreams.single.deliveryProtocol,
      VideoDeliveryProtocol.rtsp,
    );
  });

  test('controller accepts a port-forwarded RTSP camera', () {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(cameras: const []);
    addTearDown(controller.dispose);
    final user = controller.userByUsername('user1')!;

    expect(
      controller.addLiveCctvStream(
        user.username,
        'rtsp://camera:secret@camera.example.com:10554/live',
        allowDirectRtspCamera: true,
      ),
      isTrue,
    );
    expect(user.liveCctvStreams.single.streamUrl, contains(':10554/live'));
  });
}

class _RealHttpOverrides extends HttpOverrides {}
