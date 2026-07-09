import 'package:coolapp/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app opens landing and reaches user dashboard', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(const RoosterWatchApp(cameras: []));

      expect(find.byType(StartupPage), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 3600));
      await tester.pumpAndSettle();

      expect(find.text('Roostify'), findsOneWidget);
      expect(find.text('User Login'), findsOneWidget);

      await tester.tap(find.text('User Login'));
      await tester.pumpAndSettle();

      expect(find.text('User access'), findsOneWidget);
      expect(find.text('Demo account'), findsOneWidget);
      expect(find.text('Login as User'), findsOneWidget);

      await tester.ensureVisible(find.text('Login as User'));
      await tester.tap(find.text('Login as User'));
      await tester.pumpAndSettle();

      expect(find.text('User Dashboard'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Real-Time Farm Environment'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Real-Time Farm Environment'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Temperature'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Temperature'), findsOneWidget);
      await tester.tap(find.text('CCTV'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('CCTV Rooster Inspection'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Rooster inspection'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Rooster inspection'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('theme preference card defaults to light theme', (tester) async {
    final controller = AppController(cameras: const []);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(body: ThemePreferenceCard(controller: controller)),
      ),
    );

    expect(controller.themePreference, AppThemePreference.light);

    await tester.tap(find.text('Dark'));
    await tester.pump();

    expect(controller.themePreference, AppThemePreference.dark);

    await tester.tap(find.text('Light'));
    await tester.pump();

    expect(controller.themePreference, AppThemePreference.light);
  });
}
