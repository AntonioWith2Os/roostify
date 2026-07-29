import 'package:coolapp/main.dart';
import 'package:coolapp/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app opens login and shows Google sign-in', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(const RoosterWatchApp(cameras: []));

      expect(find.byType(StartupPage), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 3600));
      await tester.pumpAndSettle();

      expect(find.text('Roostify'), findsOneWidget);
      expect(find.text('Log in'), findsNWidgets(2));
      expect(
        find.text('Monitor your rooster, anytime, anywhere.'),
        findsOneWidget,
      );
      expect(find.text('Continue with Google'), findsOneWidget);
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
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ThemePreferenceCard(
            controller: controller,
            username: 'farmer1',
          ),
        ),
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
