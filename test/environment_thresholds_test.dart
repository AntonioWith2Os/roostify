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

  group('final environment alert rule', () {
    test(
      'uses the highest available temperature, humidity, heat, or air risk',
      () {
        expect(
          MonitorSnapshot.finalEnvironmentLevelFor(
            temperature: 27,
            humidity: 60,
            airPpm: 0,
          ),
          SensorWarningLevel.caution,
        );
        expect(
          MonitorSnapshot.finalEnvironmentLevelFor(
            temperature: 25,
            humidity: 65,
            airPpm: 25,
          ),
          SensorWarningLevel.danger,
        );
      },
    );

    test('raises one level when heat and air are both warning or higher', () {
      expect(
        MonitorSnapshot.finalEnvironmentLevelFor(
          temperature: 28,
          humidity: 75,
          airPpm: 20,
        ),
        SensorWarningLevel.danger,
      );
      expect(
        MonitorSnapshot.finalEnvironmentLevelFor(
          temperature: 32,
          humidity: 90,
          airPpm: 50,
        ),
        SensorWarningLevel.critical,
      );
    });

    test('does not use stale values from unavailable sensors', () {
      expect(
        MonitorSnapshot.finalEnvironmentLevelFor(
          temperature: 35,
          humidity: 90,
          airPpm: 50,
          dhtAvailable: false,
          airAvailable: false,
        ),
        SensorWarningLevel.normal,
      );
    });

    test('uses each prescribed farmer message for the final alert', () {
      MonitorSnapshot monitorFor({
        required double temperature,
        required double humidity,
        required int airPpm,
      }) {
        return MonitorSnapshot.empty().withEnvironmentReading(
          Esp32SensorReading(
            temperatureC: temperature,
            humidityPercent: humidity,
            airQualityPpm: airPpm,
            receivedAt: DateTime(2026, 10, 9),
          ),
        );
      }

      final caution = monitorFor(temperature: 27, humidity: 60, airPpm: 0);
      expect(caution.finalEnvironmentLevel, SensorWarningLevel.caution);
      expect(
        caution.alerts.single.message,
        'Rooster area is getting warm. Check water and airflow.',
      );

      final warning = monitorFor(temperature: 30, humidity: 60, airPpm: 0);
      expect(warning.finalEnvironmentLevel, SensorWarningLevel.warning);
      expect(
        warning.alerts.single.message,
        'Heat stress risk detected. Add ventilation, shade, and cool drinking water.',
      );

      final danger = monitorFor(temperature: 28, humidity: 75, airPpm: 20);
      expect(danger.finalEnvironmentLevel, SensorWarningLevel.danger);
      expect(danger.alerts, hasLength(1));
      expect(danger.alerts.single.title, 'Rooster environment danger');
      expect(
        danger.alerts.single.message,
        'Dangerous rooster environment. Reduce heat immediately and check roosters for panting.',
      );

      final critical = monitorFor(temperature: 35, humidity: 60, airPpm: 0);
      expect(critical.finalEnvironmentLevel, SensorWarningLevel.critical);
      expect(
        critical.alerts.single.message,
        'Emergency condition. Move roosters to cooler ventilated area if possible.',
      );
    });
  });
}
