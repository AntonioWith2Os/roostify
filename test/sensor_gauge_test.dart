import 'package:coolapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpGauge(
    WidgetTester tester, {
    required String status,
    required bool available,
    double width = 118,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 210,
              child: CircularSensorGauge(
                title: 'Temperature',
                value: available ? '24.0' : '0',
                unit: available ? '°C' : '',
                progress: available ? 0.5 : 0,
                icon: Icons.thermostat_outlined,
                status: status,
                level: SensorWarningLevel.normal,
                available: available,
                accent: const Color(0xFFFF453A),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a long status message renders fully without overflowing', (
    tester,
  ) async {
    const longStatus =
        'Heat stress danger with high humidity — improve airflow immediately '
        'and provide extra water for the flock.';

    await pumpGauge(tester, status: longStatus, available: true);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(longStatus), findsOneWidget);
  });

  testWidgets('an unavailable sensor shows NO SIGNAL instead of a severity tag', (
    tester,
  ) async {
    await pumpGauge(
      tester,
      status: 'DHT11 sensor is not responding — check the wiring.',
      available: false,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('NO SIGNAL'), findsOneWidget);
    expect(find.text('NORMAL'), findsNothing);
    expect(
      find.text('DHT11 sensor is not responding — check the wiring.'),
      findsOneWidget,
    );
  });
}
