import 'package:coolapp/esp32_sensor_service.dart';
import 'package:coolapp/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('documented temperature bands', () {
    test('uses the supplied normal-through-critical boundaries', () {
      expect(
        MonitorSnapshot.temperatureLevelFor(18),
        SensorWarningLevel.normal,
      );
      expect(
        MonitorSnapshot.temperatureLevelFor(26),
        SensorWarningLevel.normal,
      );
      expect(
        MonitorSnapshot.temperatureLevelFor(27),
        SensorWarningLevel.caution,
      );
      expect(
        MonitorSnapshot.temperatureLevelFor(29),
        SensorWarningLevel.caution,
      );
      expect(
        MonitorSnapshot.temperatureLevelFor(30),
        SensorWarningLevel.warning,
      );
      expect(
        MonitorSnapshot.temperatureLevelFor(31),
        SensorWarningLevel.warning,
      );
      expect(
        MonitorSnapshot.temperatureLevelFor(32),
        SensorWarningLevel.danger,
      );
      expect(
        MonitorSnapshot.temperatureLevelFor(34),
        SensorWarningLevel.danger,
      );
      expect(
        MonitorSnapshot.temperatureLevelFor(35),
        SensorWarningLevel.critical,
      );
    });
  });

  group('documented humidity bands', () {
    test('does not silently change the humidity band because it is hot', () {
      expect(
        MonitorSnapshot.humidityLevelFor(45, temperature: 35),
        SensorWarningLevel.normal,
      );
      expect(
        MonitorSnapshot.humidityLevelFor(70, temperature: 35),
        SensorWarningLevel.normal,
      );
      expect(
        MonitorSnapshot.humidityLevelFor(71, temperature: 35),
        SensorWarningLevel.caution,
      );
      expect(
        MonitorSnapshot.humidityLevelFor(79, temperature: 35),
        SensorWarningLevel.caution,
      );
      expect(
        MonitorSnapshot.humidityLevelFor(80, temperature: 35),
        SensorWarningLevel.warning,
      );
      expect(
        MonitorSnapshot.humidityLevelFor(89, temperature: 35),
        SensorWarningLevel.warning,
      );
      expect(
        MonitorSnapshot.humidityLevelFor(90, temperature: 35),
        SensorWarningLevel.danger,
      );
    });
  });

  group('combined heat rule', () {
    test('promotes the documented heat-and-humidity combinations', () {
      expect(
        MonitorSnapshot.combinedHeatLevelFor(28, 75),
        SensorWarningLevel.warning,
      );
      expect(
        MonitorSnapshot.combinedHeatLevelFor(30, 80),
        SensorWarningLevel.danger,
      );
      expect(
        MonitorSnapshot.combinedHeatLevelFor(28, 90),
        SensorWarningLevel.danger,
      );
      expect(
        MonitorSnapshot.combinedHeatLevelFor(32, 90),
        SensorWarningLevel.critical,
      );
    });

    test('promotes both DHT dashboard cards for combined heat', () {
      final monitor = MonitorSnapshot.empty().withEnvironmentReading(
        Esp32SensorReading(
          temperatureC: 28,
          humidityPercent: 75,
          airQualityPpm: 0,
          receivedAt: DateTime(2026, 10, 9),
        ),
      );

      expect(monitor.temperatureLevel, SensorWarningLevel.warning);
      expect(monitor.humidityLevel, SensorWarningLevel.warning);
    });

    test(
      'does not promote the humidity card without a humid-heat interaction',
      () {
        final monitor = MonitorSnapshot.empty().withEnvironmentReading(
          Esp32SensorReading(
            temperatureC: 35,
            humidityPercent: 45,
            airQualityPpm: 0,
            receivedAt: DateTime(2026, 10, 9),
          ),
        );

        expect(monitor.temperatureLevel, SensorWarningLevel.critical);
        expect(monitor.humidityLevel, SensorWarningLevel.normal);
      },
    );
  });
}
