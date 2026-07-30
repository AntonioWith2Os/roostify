part of '../../main.dart';

enum UserRole { admin, user }

enum HealthState { healthy, normal, abnormal }

enum SensorWarningLevel { normal, caution, warning, danger, critical }

extension SensorWarningLevelDetails on SensorWarningLevel {
  String get label => switch (this) {
    SensorWarningLevel.normal => 'NORMAL',
    SensorWarningLevel.caution => 'CAUTION',
    SensorWarningLevel.warning => 'WARNING',
    SensorWarningLevel.danger => 'DANGER',
    SensorWarningLevel.critical => 'CRITICAL',
  };

  Color get color => switch (this) {
    SensorWarningLevel.normal => const Color(0xFF26C281),
    SensorWarningLevel.caution => const Color(0xFFE6B452),
    SensorWarningLevel.warning => const Color(0xFFF08F3A),
    SensorWarningLevel.danger => _appAccent,
    SensorWarningLevel.critical => const Color(0xFFB92D49),
  };
}

class AppUser {
  AppUser({
    required this.username,
    required this.password,
    required this.displayName,
    required this.role,
    required this.cameraAccessEnabled,
    required this.monitor,
    required this.cctvs,
    this.contactNumber = '',
    this.address = '',
    this.facebookContact = '',
    this.email = '',
    this.farmName = '',
    this.shortBio = '',
    this.avatarPath,
    List<LiveCctvStream>? liveCctvStreams,
  }) : liveCctvStreams = liveCctvStreams ?? [];

  String username;
  String password;
  String displayName;
  String contactNumber;
  String address;
  String facebookContact;
  String email;
  String farmName;
  String shortBio;
  // Local file path for a picked profile photo; distinct from Session.photoUrl,
  // which is a remote Google account picture.
  String? avatarPath;
  final UserRole role;
  bool cameraAccessEnabled;
  MonitorSnapshot monitor;
  final List<CctvFeed> cctvs;
  final List<LiveCctvStream> liveCctvStreams;

  bool get isAdmin => role == UserRole.admin;
}

/// Emitted by [AppController] when an event matches an enabled Notification
/// Preference (and isn't muted by quiet hours), for the app shell to surface
/// as an in-app SnackBar/sound/vibration.
class AppAlertEvent {
  const AppAlertEvent({
    required this.category,
    required this.title,
    required this.message,
    this.severity = AlertSeverity.info,
    this.playSound = false,
    this.vibrate = false,
  });

  final String category;
  final String title;
  final String message;
  final AlertSeverity severity;
  final bool playSound;
  final bool vibrate;
}

/// A single connected live RTSP camera. A user can connect several of these
/// at once; each runs its own playback, recording, and YOLOv8 inspection
/// independently of the others.
class LiveCctvStream {
  LiveCctvStream({
    required this.id,
    required this.streamUrl,
    required this.label,
    CctvInspectionResult? inspection,
  }) : inspection = inspection ?? CctvInspectionResult.waitingForFrame();

  final String id;
  final String streamUrl;
  String label;
  CctvInspectionResult inspection;

  Map<String, dynamic> toJson() => {
    'id': id,
    'streamUrl': streamUrl,
    'label': label,
  };

  factory LiveCctvStream.fromJson(Map<String, dynamic> json) {
    return LiveCctvStream(
      id: json['id'] as String,
      streamUrl: json['streamUrl'] as String,
      label: json['label'] as String,
    );
  }
}

/// Display name for a connected camera at [index] out of [totalStreams].
/// Only numbered once a user has more than one CCTV connected.
String cctvStreamDisplayLabel(int index, int totalStreams) {
  return totalStreams > 1 ? 'CCTV ${index + 1}' : 'CCTV';
}

class Session {
  Session({required this.user, this.email, this.photoUrl});

  final AppUser user;
  // Google profile metadata is optional so existing local/demo sessions still
  // work with the same Session model. Mutable so linking a Google account
  // after sign-in can update the same Session instance already held by the
  // active AppShell, without threading a new object through the widget tree.
  String? email;
  String? photoUrl;
}

class MonitorSnapshot {
  const MonitorSnapshot({
    required this.temperature,
    required this.humidity,
    required this.airPpm,
    required this.temperatureStatus,
    required this.humidityStatus,
    required this.airStatus,
    required this.detectedBreed,
    required this.movementLabel,
    required this.cctvStatus,
    required this.cctvSummary,
    required this.alerts,
    this.dhtAvailable = true,
    this.airAvailable = true,
  });

  final double temperature;
  final double humidity;
  final int airPpm;
  final String temperatureStatus;
  final String humidityStatus;
  final String airStatus;
  final String detectedBreed;
  final String movementLabel;
  final HealthState cctvStatus;
  final String cctvSummary;
  final List<AlertItem> alerts;

  /// False when the DHT (temperature/humidity) sensor is currently
  /// unreadable — [temperature]/[humidity] then hold the last known-good
  /// values rather than a fresh reading. Mirrors
  /// [Esp32SensorReading.dhtAvailable].
  final bool dhtAvailable;

  /// Same as [dhtAvailable] but for the MQ135 air-quality sensor. Mirrors
  /// [Esp32SensorReading.airAvailable].
  final bool airAvailable;

  SensorWarningLevel get temperatureLevel =>
      temperatureLevelFor(temperature, humidity: humidity);

  SensorWarningLevel get humidityLevel =>
      humidityLevelFor(humidity, temperature: temperature);

  SensorWarningLevel get airLevel => airLevelFor(airPpm);

  MonitorSnapshot withEnvironmentReading(Esp32SensorReading reading) {
    final retainedAlerts = alerts
        .where((alert) => !_environmentAlertCategories.contains(alert.category))
        .toList();

    return MonitorSnapshot(
      temperature: reading.temperatureC,
      humidity: reading.humidityPercent,
      airPpm: reading.airQualityPpm,
      temperatureStatus: _temperatureStatus(
        reading.temperatureC,
        humidity: reading.humidityPercent,
      ),
      humidityStatus: _humidityStatus(
        reading.humidityPercent,
        temperature: reading.temperatureC,
      ),
      airStatus: _airStatus(reading.airQualityPpm),
      detectedBreed: detectedBreed,
      movementLabel: movementLabel,
      cctvStatus: cctvStatus,
      cctvSummary: cctvSummary,
      alerts: [..._environmentAlerts(reading), ...retainedAlerts],
      dhtAvailable: reading.dhtAvailable,
      airAvailable: reading.airAvailable,
    );
  }

  static const Set<String> _environmentAlertCategories = {
    'Temperature',
    'Humidity',
    'Air Quality',
    'Air Pollution',
    'Environment',
    'System',
    'Setup',
  };

  static SensorWarningLevel temperatureLevelFor(
    double value, {
    double? humidity,
  }) {
    final humidHeat = humidity != null && humidity >= 80;
    final severeHumidHeat = humidity != null && humidity >= 90;

    if (value >= 35) return SensorWarningLevel.critical;
    if (value >= 32) return SensorWarningLevel.danger;
    if (value >= 30) {
      return humidHeat ? SensorWarningLevel.danger : SensorWarningLevel.warning;
    }
    if (value >= 27) {
      return severeHumidHeat
          ? SensorWarningLevel.warning
          : SensorWarningLevel.caution;
    }
    if (value >= 18) return SensorWarningLevel.normal;
    if (value >= 10) return SensorWarningLevel.caution;
    if (value >= 5) return SensorWarningLevel.danger;
    return SensorWarningLevel.critical;
  }

  static SensorWarningLevel humidityLevelFor(
    double value, {
    double? temperature,
  }) {
    final hot = temperature != null && temperature >= 30;

    if (value >= 90) return SensorWarningLevel.danger;
    if (value >= 80) {
      return hot ? SensorWarningLevel.danger : SensorWarningLevel.warning;
    }
    if (value >= 71) return SensorWarningLevel.caution;
    if (value >= 45) return SensorWarningLevel.normal;
    return SensorWarningLevel.caution;
  }

  static SensorWarningLevel airLevelFor(int value) {
    if (value >= 50) return SensorWarningLevel.critical;
    if (value >= 25) return SensorWarningLevel.danger;
    if (value >= 20) return SensorWarningLevel.warning;
    if (value >= 10) return SensorWarningLevel.caution;
    return SensorWarningLevel.normal;
  }

  static String _temperatureStatus(double value, {double? humidity}) {
    final humidHeat = humidity != null && humidity >= 80;
    final severeHumidHeat = humidity != null && humidity >= 90;

    if (value >= 35) return 'Emergency heat condition';
    if (value >= 32) return 'Dangerous; strong cooling needed';
    if (value >= 30) {
      return humidHeat
          ? 'Heat stress danger with high humidity'
          : 'Heat stress likely, especially if humid';
    }
    if (value >= 27) {
      return severeHumidHeat
          ? 'Heat risk raised by very high humidity'
          : 'Start prevention: shade, water, airflow';
    }
    if (value >= 18) return 'Good / comfortable';
    if (value >= 10) return 'Below ideal; add safe warmth';
    if (value >= 5) return 'Cold stress risk; warm the area';
    return 'Emergency cold condition';
  }

  static String _humidityStatus(double value, {double? temperature}) {
    final warm = temperature != null && temperature >= 28;
    final hot = temperature != null && temperature >= 30;

    if (value >= 90) {
      return hot
          ? 'Very poor cooling with heat'
          : 'Very poor cooling condition';
    }
    if (value >= 80) {
      return warm ? 'Risky with current heat' : 'Risky; improve ventilation';
    }
    if (value >= 71) return 'Watch closely; improve ventilation';
    if (value >= 45) return 'Good range';
    if (value < 40) return 'Dry/dust risk';
    return 'Slightly dry; watch dust';
  }

  static String _airStatus(int value) {
    if (value >= 50) {
      return 'Emergency; remove birds if possible';
    }
    if (value >= 25) return 'Ventilate and clean immediately';
    if (value >= 20) return 'Air quality becoming unsafe';
    if (value >= 10) return 'Improve ventilation; check litter/manure';
    return 'Good air';
  }

  static AlertSeverity _alertSeverityFor(SensorWarningLevel level) {
    return switch (level) {
      SensorWarningLevel.critical => AlertSeverity.danger,
      SensorWarningLevel.danger => AlertSeverity.danger,
      SensorWarningLevel.warning => AlertSeverity.warning,
      SensorWarningLevel.caution => AlertSeverity.warning,
      SensorWarningLevel.normal => AlertSeverity.info,
    };
  }

  static List<AlertItem> _environmentAlerts(Esp32SensorReading reading) {
    final alerts = <AlertItem>[];
    final time = _timeLabelFor(reading.receivedAt);
    final temperatureLevel = temperatureLevelFor(
      reading.temperatureC,
      humidity: reading.humidityPercent,
    );
    final humidityLevel = humidityLevelFor(
      reading.humidityPercent,
      temperature: reading.temperatureC,
    );
    final airLevel = airLevelFor(reading.airQualityPpm);

    if (temperatureLevel != SensorWarningLevel.normal) {
      final temperature = reading.temperatureC.toStringAsFixed(1);
      alerts.add(
        AlertItem(
          title: 'Temperature ${temperatureLevel.label.toLowerCase()}',
          message:
              'Temperature is $temperature °C. ${_temperatureStatus(reading.temperatureC, humidity: reading.humidityPercent)}.',
          severity: _alertSeverityFor(temperatureLevel),
          category: 'Temperature',
          time: time,
        ),
      );
    }

    if (humidityLevel != SensorWarningLevel.normal) {
      final humidity = reading.humidityPercent.toStringAsFixed(0);
      alerts.add(
        AlertItem(
          title: 'Humidity ${humidityLevel.label.toLowerCase()}',
          message:
              'Humidity is $humidity%. ${_humidityStatus(reading.humidityPercent, temperature: reading.temperatureC)}.',
          severity: _alertSeverityFor(humidityLevel),
          category: 'Humidity',
          time: time,
        ),
      );
    }

    final dangerousHeatHumidity =
        (reading.temperatureC >= 30 && reading.humidityPercent >= 80) ||
        (reading.temperatureC >= 28 && reading.humidityPercent >= 90);
    if (dangerousHeatHumidity) {
      final temperature = reading.temperatureC.toStringAsFixed(1);
      final humidity = reading.humidityPercent.toStringAsFixed(0);
      alerts.add(
        AlertItem(
          title: 'Heat and humidity danger',
          message:
              'The coop reached $temperature °C with $humidity% humidity. High humidity makes cooling harder; improve airflow and cool the pen immediately.',
          severity: AlertSeverity.danger,
          category: 'Environment',
          time: time,
        ),
      );
    }

    if (airLevel != SensorWarningLevel.normal) {
      alerts.add(
        AlertItem(
          title: 'Air pollution ${airLevel.label.toLowerCase()}',
          message:
              'Ammonia reading is ${reading.airQualityPpm} ppm. ${_airStatus(reading.airQualityPpm)}.',
          severity: _alertSeverityFor(airLevel),
          category: 'Air Pollution',
          time: time,
        ),
      );
    }

    if (!reading.dhtAvailable) {
      alerts.add(
        AlertItem(
          title: 'DHT sensor not responding',
          message:
              'Temperature and humidity readings are unavailable — check the DHT sensor wiring. Showing the last known values.',
          severity: AlertSeverity.warning,
          category: 'System',
          time: time,
        ),
      );
    }

    if (!reading.airAvailable) {
      alerts.add(
        AlertItem(
          title: 'Air quality sensor not responding',
          message:
              'Ammonia readings are unavailable — check the MQ135 sensor wiring. Showing the last known value.',
          severity: AlertSeverity.warning,
          category: 'System',
          time: time,
        ),
      );
    }

    if (alerts.isEmpty) {
      alerts.add(
        AlertItem(
          title: 'Environment stable',
          message: 'Live ESP32 readings are within the rooster comfort range.',
          severity: AlertSeverity.info,
          category: 'System',
          time: time,
        ),
      );
    }

    return alerts;
  }

  factory MonitorSnapshot.empty() {
    return const MonitorSnapshot(
      temperature: 0,
      humidity: 0,
      airPpm: 0,
      temperatureStatus: 'Admin account',
      humidityStatus: 'Admin account',
      airStatus: 'Admin account',
      detectedBreed: '-',
      movementLabel: '-',
      cctvStatus: HealthState.normal,
      cctvSummary: 'Admin accounts do not have direct farm monitoring values.',
      alerts: [],
    );
  }

  factory MonitorSnapshot.sampleOne() {
    return const MonitorSnapshot(
      temperature: 33.4,
      humidity: 78,
      airPpm: 22,
      temperatureStatus: 'Dangerous; strong cooling needed',
      humidityStatus: 'Watch closely; improve ventilation',
      airStatus: 'Air quality becoming unsafe',
      detectedBreed: 'American Gamefowl',
      movementLabel: 'Abnormal pacing',
      cctvStatus: HealthState.abnormal,
      cctvSummary:
          'YOLOv8 detection reports one rooster showing repeated pacing and slower wing balance than expected.',
      alerts: [
        AlertItem(
          title: 'Temperature danger',
          message: 'Temperature is 33.4 °C. Dangerous; strong cooling needed.',
          severity: AlertSeverity.danger,
          category: 'Temperature',
          time: '10:42 AM',
        ),
        AlertItem(
          title: 'Humidity caution',
          message: 'Humidity is 78%. Watch closely; improve ventilation.',
          severity: AlertSeverity.warning,
          category: 'Humidity',
          time: '10:18 AM',
        ),
        AlertItem(
          title: 'Air pollution warning',
          message: 'Ammonia reading is 22 ppm. Air quality becoming unsafe.',
          severity: AlertSeverity.warning,
          category: 'Air Pollution',
          time: '10:05 AM',
        ),
        AlertItem(
          title: 'Abnormal CCTV movement',
          message:
              'A rooster in Main Pen Camera A shows irregular movement and needs inspection.',
          severity: AlertSeverity.danger,
          category: 'YOLOv8 CCTV',
          time: '9:55 AM',
        ),
      ],
    );
  }

  factory MonitorSnapshot.sampleTwo() {
    return const MonitorSnapshot(
      temperature: 25.4,
      humidity: 64,
      airPpm: 6,
      temperatureStatus: 'Good / comfortable',
      humidityStatus: 'Good range',
      airStatus: 'Good air',
      detectedBreed: 'Sweater',
      movementLabel: 'Normal movement',
      cctvStatus: HealthState.normal,
      cctvSummary:
          'CCTV analysis shows normal movement and clear posture for the current rooster group.',
      alerts: [
        AlertItem(
          title: 'Environment stable',
          message:
              'Current readings are within acceptable farm conditions for the connected coop.',
          severity: AlertSeverity.info,
          category: 'System',
          time: '10:11 AM',
        ),
      ],
    );
  }

  factory MonitorSnapshot.newUser(String name) {
    return MonitorSnapshot(
      temperature: 25,
      humidity: 60,
      airPpm: 5,
      temperatureStatus: 'Monitoring started',
      humidityStatus: 'Monitoring started',
      airStatus: 'Monitoring started',
      detectedBreed: 'Breed not identified yet',
      movementLabel: 'No recent scan',
      cctvStatus: HealthState.normal,
      cctvSummary:
          'Monitoring for $name is ready. Connect live devices and cameras to begin classification.',
      alerts: const [
        AlertItem(
          title: 'Waiting for live data',
          message:
              'Device and camera readings will appear once the farm hardware starts sending updates.',
          severity: AlertSeverity.info,
          category: 'Setup',
          time: 'Now',
        ),
      ],
    );
  }
}

class CctvFeed {
  const CctvFeed({
    required this.name,
    required this.location,
    required this.status,
    required this.online,
    required this.note,
  });

  final String name;
  final String location;
  final HealthState status;
  final bool online;
  final String note;
}

enum AlertSeverity { info, warning, danger }

class AlertItem {
  const AlertItem({
    required this.title,
    required this.message,
    required this.severity,
    required this.category,
    required this.time,
  });

  final String title;
  final String message;
  final AlertSeverity severity;
  final String category;
  final String time;

  bool get isDanger => severity == AlertSeverity.danger;
}

class SupportThread {
  SupportThread({
    required this.id,
    required this.username,
    required this.messages,
    required this.resolved,
  });

  final String id;
  String username;
  final List<SupportMessage> messages;
  bool resolved;
}

class SupportMessage {
  const SupportMessage({
    required this.senderRole,
    required this.text,
    required this.timestamp,
  });

  final UserRole senderRole;
  final String text;
  final String timestamp;
}

class GuidelineItem {
  const GuidelineItem({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class ManualScanResult {
  const ManualScanResult({
    required this.condition,
    required this.breed,
    required this.movement,
    required this.note,
    this.confidenceLabel = '-',
    this.detectionCount = 0,
    this.detections = const [],
  });

  final HealthState condition;
  final String breed;
  final String movement;
  final String note;
  final String confidenceLabel;
  final int detectionCount;
  final List<ChickenDetection> detections;

  bool get detected => detectionCount > 0;
}

class LiveCameraFrame {
  const LiveCameraFrame({
    required this.width,
    required this.height,
    required this.formatGroup,
    required this.planes,
    required this.rotationDegrees,
  });

  factory LiveCameraFrame.fromCameraImage(
    CameraImage image, {
    required int rotationDegrees,
  }) {
    return LiveCameraFrame(
      width: image.width,
      height: image.height,
      formatGroup: image.format.group,
      rotationDegrees: rotationDegrees,
      planes: image.planes
          .map(
            (plane) => LiveCameraPlane(
              bytes: Uint8List.fromList(plane.bytes),
              bytesPerRow: plane.bytesPerRow,
              bytesPerPixel: plane.bytesPerPixel,
              width: plane.width,
              height: plane.height,
            ),
          )
          .toList(growable: false),
    );
  }

  final int width;
  final int height;
  final ImageFormatGroup formatGroup;
  final List<LiveCameraPlane> planes;
  final int rotationDegrees;
}

class LiveCameraPlane {
  const LiveCameraPlane({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel,
    this.width,
    this.height,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;
  final int? width;
  final int? height;
}

enum CctvInspectionState {
  idle,
  waitingForFrame,
  capturing,
  inspecting,
  completed,
  error,
}

class ChickenDetection {
  const ChickenDetection({
    required this.box,
    required this.label,
    required this.confidence,
    required this.condition,
  });

  final Rect box;
  final String label;
  final double confidence;
  final HealthState condition;
}

ChickenDetection? _bestChickenDetection(List<ChickenDetection> detections) {
  ChickenDetection? best;
  for (final detection in detections) {
    if (best == null || detection.confidence > best.confidence) {
      best = detection;
    }
  }
  return best;
}

bool _sameDetectedRooster(
  List<ChickenDetection> previous,
  List<ChickenDetection> next,
) {
  final previousDetection = _bestChickenDetection(previous);
  final nextDetection = _bestChickenDetection(next);
  if (previousDetection == null || nextDetection == null) {
    return false;
  }
  // No box-overlap requirement: captures can be several seconds apart on
  // slow devices, so a live bird moves too far for IoU matching and the
  // confirmation would starve. Two consecutive frames agreeing on the health
  // state is the debounce signal.
  return previousDetection.condition == nextDetection.condition;
}

class CctvInspectionResult {
  const CctvInspectionResult({
    required this.state,
    required this.resultLabel,
    required this.confidenceLabel,
    required this.message,
    required this.inspectedAtLabel,
    required this.condition,
    required this.detected,
    this.detectionCount,
    this.detections = const [],
  });

  factory CctvInspectionResult.idle() {
    return const CctvInspectionResult(
      state: CctvInspectionState.idle,
      resultLabel: 'No camera connected',
      confidenceLabel: '-',
      message:
          'Connect a CCTV stream to inspect frames with the on-device YOLOv8 model.',
      inspectedAtLabel: '-',
      condition: HealthState.normal,
      detected: false,
    );
  }

  factory CctvInspectionResult.waitingForFrame() {
    return const CctvInspectionResult(
      state: CctvInspectionState.waitingForFrame,
      resultLabel: 'Waiting for live frame',
      confidenceLabel: '-',
      message:
          'The app will capture a frame as soon as the live CCTV preview starts playing.',
      inspectedAtLabel: '-',
      condition: HealthState.normal,
      detected: false,
    );
  }

  factory CctvInspectionResult.capturing() {
    return const CctvInspectionResult(
      state: CctvInspectionState.capturing,
      resultLabel: 'Capturing frame',
      confidenceLabel: '-',
      message:
          'A rendered CCTV frame is being prepared for rooster inspection.',
      inspectedAtLabel: '-',
      condition: HealthState.normal,
      detected: false,
    );
  }

  factory CctvInspectionResult.inspecting() {
    return const CctvInspectionResult(
      state: CctvInspectionState.inspecting,
      resultLabel: 'Running YOLOv8',
      confidenceLabel: '-',
      message: 'The captured CCTV frame is being inspected on this device.',
      inspectedAtLabel: '-',
      condition: HealthState.normal,
      detected: false,
    );
  }

  factory CctvInspectionResult.error(String message) {
    return CctvInspectionResult(
      state: CctvInspectionState.error,
      resultLabel: 'Inspection failed',
      confidenceLabel: '-',
      message: message,
      inspectedAtLabel: _timestampLabel(),
      condition: HealthState.abnormal,
      detected: false,
    );
  }

  factory CctvInspectionResult.fromDetections(
    List<ChickenDetection> detections,
  ) {
    if (detections.isEmpty) {
      return CctvInspectionResult(
        state: CctvInspectionState.completed,
        resultLabel: 'No rooster detected',
        confidenceLabel: '-',
        message:
            'The on-device YOLOv8 model did not find a rooster in this frame.',
        inspectedAtLabel: _timestampLabel(),
        condition: HealthState.normal,
        detected: false,
        detectionCount: 0,
      );
    }

    final abnormalCount = detections
        .where((detection) => detection.condition == HealthState.abnormal)
        .length;
    final bestDetection = detections.reduce(
      (best, detection) =>
          detection.confidence > best.confidence ? detection : best,
    );
    final resultLabel = abnormalCount > 0
        ? '$abnormalCount abnormal rooster${abnormalCount == 1 ? '' : 's'}'
        : '${detections.length} normal rooster${detections.length == 1 ? '' : 's'}';

    return CctvInspectionResult(
      state: CctvInspectionState.completed,
      resultLabel: resultLabel,
      confidenceLabel: _formatConfidence(bestDetection.confidence),
      message:
          'The on-device YOLOv8 model found ${detections.length} rooster${detections.length == 1 ? '' : 's'} in this frame.',
      inspectedAtLabel: _timestampLabel(),
      condition: abnormalCount > 0 ? HealthState.abnormal : HealthState.normal,
      detected: true,
      detectionCount: detections.length,
      detections: detections,
    );
  }

  final CctvInspectionState state;
  final String resultLabel;
  final String confidenceLabel;
  final String message;
  final String inspectedAtLabel;
  final HealthState condition;
  final bool detected;
  final int? detectionCount;
  final List<ChickenDetection> detections;

  bool get isBusy =>
      state == CctvInspectionState.waitingForFrame ||
      state == CctvInspectionState.capturing ||
      state == CctvInspectionState.inspecting;

  static double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static String _formatConfidence(Object? value) {
    final confidence = _asDouble(value);
    if (confidence == null) {
      final fallback = value?.toString().trim();
      return fallback == null || fallback.isEmpty ? '-' : fallback;
    }

    final percent = confidence <= 1 ? confidence * 100 : confidence;
    final decimals = percent >= 10 ? 0 : 1;
    return '${percent.toStringAsFixed(decimals)}%';
  }
}
