import 'dart:io';

import 'package:coolapp/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('admin CCTV page exposes the server recordings library', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(cameras: const []);
    addTearDown(controller.dispose);
    final session = Session(user: controller.userByUsername('admin')!);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: AdminRedesignShell(controller: controller, session: session),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('CCTV'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Recordings'), findsOneWidget);
  });

  test(
    'server archive scopes users and lets an admin list every owner',
    () async {
      final originalPathProvider = PathProviderPlatform.instance;
      final testRoot = await Directory.systemTemp.createTemp(
        'roostify_recording_server_test_',
      );
      PathProviderPlatform.instance = _TestPathProvider(testRoot.path);
      addTearDown(() async {
        PathProviderPlatform.instance = originalPathProvider;
        if (await testRoot.exists()) await testRoot.delete(recursive: true);
      });

      final firstSource = File('${testRoot.path}/farmer1.mp4');
      final secondSource = File('${testRoot.path}/farmer2.mp4');
      await firstSource.writeAsBytes([1, 2, 3]);
      await secondSource.writeAsBytes([4, 5, 6, 7]);
      await RecordingServerService.uploadRecording(
        sourcePath: firstSource.path,
        ownerUsername: 'farmer1',
      );
      await RecordingServerService.uploadRecording(
        sourcePath: secondSource.path,
        ownerUsername: 'farmer2',
      );

      final controller = AppController(cameras: const []);
      addTearDown(controller.dispose);
      final admin = controller.userByUsername('admin')!;
      final farmer1 = controller.userByUsername('farmer1')!;

      final adminRecordings = await RecordingServerService.listRecordings(
        viewer: admin,
      );
      final userRecordings = await RecordingServerService.listRecordings(
        viewer: farmer1,
      );

      expect(adminRecordings, hasLength(2));
      expect(
        adminRecordings.map((recording) => recording.ownerUsername).toSet(),
        {'farmer1', 'farmer2'},
      );
      expect(userRecordings, hasLength(1));
      expect(userRecordings.single.ownerUsername, 'farmer1');
      expect(userRecordings.single.isServerStored, isTrue);
    },
  );

  test('snapshot analysis failure does not disconnect a playing CCTV', () {
    final controller = AppController(cameras: const []);
    addTearDown(controller.dispose);
    final user = controller.userByUsername('farmer1')!;
    final stream = user.liveCctvStreams.single;

    controller.markCctvConnectionStatus(user.username, stream.id, true);
    controller.markCctvInspectionError(
      user.username,
      stream.id,
      'Snapshot timed out',
    );

    expect(stream.isOnline, isTrue);
    expect(stream.inspection.state, CctvInspectionState.error);
  });

  testWidgets('CCTV viewer exposes AI scanning as an opt-in control', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final controller = AppController(cameras: const []);
    addTearDown(controller.dispose);
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveFeedCard(
              streamUrl: 'rtsp://camera.local/live',
              recordingOwnerUsername: 'farmer1',
              controller: controller,
              expand: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('Enable AI scanning'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

class _TestPathProvider extends PathProviderPlatform {
  _TestPathProvider(this.rootPath);

  final String rootPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => '$rootPath/documents';

  @override
  Future<String?> getApplicationSupportPath() async => '$rootPath/support';

  @override
  Future<String?> getExternalStoragePath() async => '$rootPath/external';
}
