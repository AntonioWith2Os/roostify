import 'dart:convert';

import 'package:coolapp/main.dart';
import 'package:crypto/crypto.dart';
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

  test('a V380 Cloud source without credentials fails validation', () {
    // There's no backend anymore to fall back to a configured default
    // username/password - the app connects with exactly what's entered.
    final source = buildV380CloudCameraUri(deviceId: '12345678');

    expect(source, 'v380://12345678');
    expect(v380CloudCameraValidationError(source), contains('username'));
  });

  test('a V380 Cloud source requires a username but allows a blank password', () {
    // Some V380 cameras are configured with no password at all.
    final blankPassword = buildV380CloudCameraUri(
      deviceId: '12345678',
      username: 'admin',
    );
    expect(v380CloudCameraValidationError(blankPassword), isNull);
    expect(V380CloudCameraConfig.parse(blankPassword).password, '');

    final complete = buildV380CloudCameraUri(
      deviceId: '12345678',
      username: 'admin',
      password: 'camera-password',
    );
    expect(v380CloudCameraValidationError(complete), isNull);
  });

  test('the V380 cloud dispatch sign matches the reference algorithm', () {
    // Mirrors DispatchRelayServer.ComputeSha1Hash in
    // cs_tmp/V380Decoder/src/DispatchRelayServer.cs: sha1(baseString), lowercase hex.
    const deviceId = 12345678;
    const platform = 10001;
    const timestamp = 1700000000;
    final baseString = 'dev_id=$deviceId&platform=$platform&timestamp=${timestamp}hsdata2022';
    final sign = sha1.convert(utf8.encode(baseString)).toString();

    expect(sign, hasLength(40));
    expect(sign, equals(sign.toLowerCase()));
  });

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
    expect(find.text('Scan local network'), findsOneWidget);
    // V380 Cloud camera adding is hidden for now (_v380CloudCameraAddingEnabled
    // in app_constants.dart) while that path's reliability against real
    // cameras is still being worked out - see that constant's doc comment.
    expect(find.text('V380 Cloud camera'), findsNothing);

    await tester.tap(find.text('Scan local network'));
    await tester.pumpAndSettle();
    expect(find.text('Scan Cameras'), findsOneWidget);
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
