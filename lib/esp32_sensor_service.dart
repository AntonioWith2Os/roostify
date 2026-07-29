import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const esp32SensorDeviceName = 'DominiGo-ESP32';
const esp32SensorServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const esp32SensorNotifyUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

enum Esp32SensorConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

class Esp32SensorReading {
  const Esp32SensorReading({
    required this.temperatureC,
    required this.humidityPercent,
    required this.airQualityPpm,
    required this.receivedAt,
  });

  final double temperatureC;
  final double humidityPercent;
  final int airQualityPpm;
  final DateTime receivedAt;
}

class Esp32SensorClient extends ChangeNotifier {
  static final Guid _serviceGuid = Guid(esp32SensorServiceUuid);
  static final Guid _notifyGuid = Guid(esp32SensorNotifyUuid);
  static const Duration _scanTimeout = Duration(seconds: 12);
  static const Duration _connectTimeout = Duration(seconds: 14);

  Esp32SensorConnectionStatus _status =
      Esp32SensorConnectionStatus.disconnected;
  BluetoothDevice? _device;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _valueSubscription;
  ValueChanged<Esp32SensorReading>? _onReading;
  Esp32SensorReading? _latestReading;
  String? _lastError;
  String _rxBuffer = '';
  bool _disposed = false;

  Esp32SensorConnectionStatus get status => _status;
  Esp32SensorReading? get latestReading => _latestReading;
  String? get lastError => _lastError;
  bool get isBusy =>
      _status == Esp32SensorConnectionStatus.scanning ||
      _status == Esp32SensorConnectionStatus.connecting;
  bool get isConnected => _status == Esp32SensorConnectionStatus.connected;

  String get statusLabel => switch (_status) {
    Esp32SensorConnectionStatus.disconnected => 'ESP32 sensor not connected',
    Esp32SensorConnectionStatus.scanning =>
      'Scanning for $esp32SensorDeviceName',
    Esp32SensorConnectionStatus.connecting => 'Connecting to ESP32 sensor',
    Esp32SensorConnectionStatus.connected => _connectedLabel(),
    Esp32SensorConnectionStatus.error =>
      _lastError ?? 'ESP32 sensor connection failed',
  };

  /// The BLE link can be "connected" while never actually having produced a
  /// usable reading (no notification has arrived yet, or every payload so
  /// far failed to parse) — those are silent no-ops for the caller
  /// otherwise, so distinguish them instead of always claiming success.
  String _connectedLabel() {
    if (_lastError != null) return _lastError!;
    if (_latestReading == null) return 'Connected — waiting for first reading...';
    return 'Receiving live ESP32 readings';
  }

  /// True once connected if the most recent payload failed to parse, so the
  /// UI can flag it instead of showing a plain "connected" state.
  bool get hasReadIssue =>
      _status == Esp32SensorConnectionStatus.connected && _lastError != null;

  Future<void> connect({
    required ValueChanged<Esp32SensorReading> onReading,
  }) async {
    if (isBusy || isConnected) return;

    _onReading = onReading;
    _lastError = null;
    _rxBuffer = '';
    _setStatus(Esp32SensorConnectionStatus.scanning);

    try {
      if (!kIsWeb && Platform.isAndroid) {
        await FlutterBluePlus.turnOn(timeout: 8);
      }

      await FlutterBluePlus.adapterState
          .where((state) => state == BluetoothAdapterState.on)
          .first
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw TimeoutException('Bluetooth is off.'),
          );

      await _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.onScanResults.listen(
        _handleScanResults,
        onError: (Object error) => _setError(_friendlyError(error)),
      );

      await FlutterBluePlus.startScan(
        withServices: [_serviceGuid],
        timeout: _scanTimeout,
        webOptionalServices: [_serviceGuid],
      );

      await FlutterBluePlus.isScanning
          .where((isScanning) => !isScanning)
          .first
          .timeout(_scanTimeout + const Duration(seconds: 2));

      if (_status == Esp32SensorConnectionStatus.scanning) {
        _setError(
          'ESP32 not found. Make sure $esp32SensorDeviceName is powered nearby.',
        );
      }
    } on TimeoutException catch (error) {
      await _stopScanQuietly();
      _setError(error.message ?? 'Bluetooth did not become ready in time.');
    } catch (error) {
      await _stopScanQuietly();
      _setError(_friendlyError(error));
    }
  }

  Future<void> disconnect() async {
    await _stopScanQuietly();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _valueSubscription?.cancel();
    _valueSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _rxBuffer = '';

    final device = _device;
    _device = null;
    if (device != null && device.isConnected) {
      try {
        await device.disconnect();
      } catch (_) {
        // The device may already have disconnected.
      }
    }

    _lastError = null;
    _setStatus(Esp32SensorConnectionStatus.disconnected);
  }

  void _handleScanResults(List<ScanResult> results) {
    if (_status != Esp32SensorConnectionStatus.scanning) return;

    for (final result in results) {
      if (_matchesSensor(result)) {
        unawaited(_connectToDevice(result.device));
        return;
      }
    }
  }

  bool _matchesSensor(ScanResult result) {
    final advName = result.advertisementData.advName;
    final platformName = result.device.platformName;
    final hasSensorService = result.advertisementData.serviceUuids.contains(
      _serviceGuid,
    );

    return hasSensorService ||
        advName == esp32SensorDeviceName ||
        platformName == esp32SensorDeviceName;
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_status != Esp32SensorConnectionStatus.scanning) return;

    _setStatus(Esp32SensorConnectionStatus.connecting);
    await _stopScanQuietly();

    try {
      _device = device;
      await _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected &&
            _status == Esp32SensorConnectionStatus.connected) {
          _setStatus(Esp32SensorConnectionStatus.disconnected);
        }
      });

      if (!device.isConnected) {
        await device.connect(license: License.free, timeout: _connectTimeout);
      }

      final services = await device.discoverServices();
      final characteristic = _findNotifyCharacteristic(services);
      if (characteristic == null) {
        throw StateError('Sensor data characteristic was not found.');
      }

      await _valueSubscription?.cancel();
      _valueSubscription = characteristic.onValueReceived.listen(
        _handleSensorBytes,
        onError: (Object error) => _setError(_friendlyError(error)),
      );

      if (characteristic.properties.read) {
        final currentValue = await characteristic.read(timeout: 8);
        _handleSensorBytes(currentValue);
      }

      await characteristic.setNotifyValue(true);
      _lastError = null;
      _setStatus(Esp32SensorConnectionStatus.connected);
    } catch (error) {
      await disconnect();
      _setError(_friendlyError(error));
    }
  }

  BluetoothCharacteristic? _findNotifyCharacteristic(
    List<BluetoothService> services,
  ) {
    for (final service in services) {
      if (service.uuid != _serviceGuid) continue;
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid == _notifyGuid) {
          return characteristic;
        }
      }
    }
    return null;
  }

  // The firmware sends a fresh, self-contained "{...}\n" reading on every
  // notification — never a continuation of a previous one. If a single BLE
  // packet ever arrives short (e.g. the negotiated ATT MTU is smaller than
  // the ~50-byte payload, which the ESP32 BLE stack silently truncates to
  // rather than fragmenting across packets), that fragment would otherwise
  // sit in the buffer forever, get concatenated with the *next* unrelated
  // notification, and never again match a complete "\n"-terminated or
  // balanced-brace payload — i.e. readings would stop updating permanently
  // after a single bad packet. Capping the buffer and recovering from the
  // most recent "{" keeps this self-healing instead.
  static const int _maxBufferLength = 512;

  void _handleSensorBytes(List<int> bytes) {
    if (bytes.isEmpty) return;

    _rxBuffer += utf8.decode(bytes, allowMalformed: true);
    if (_rxBuffer.length > _maxBufferLength) {
      final lastBrace = _rxBuffer.lastIndexOf('{');
      _rxBuffer = lastBrace == -1 ? '' : _rxBuffer.substring(lastBrace);
    }

    while (_rxBuffer.contains('\n')) {
      final newline = _rxBuffer.indexOf('\n');
      final payload = _rxBuffer.substring(0, newline).trim();
      _rxBuffer = _rxBuffer.substring(newline + 1);
      _parseAndEmit(payload);
    }

    final candidate = _extractBalancedJsonObject(_rxBuffer);
    if (candidate != null) {
      _rxBuffer = '';
      _parseAndEmit(candidate);
    }
  }

  /// Finds the first complete `{...}` object in [buffer] by brace counting,
  /// instead of requiring the *entire* trimmed buffer to start and end with
  /// braces — a stray leading/trailing byte shouldn't block an otherwise
  /// complete payload from parsing.
  String? _extractBalancedJsonObject(String buffer) {
    final start = buffer.indexOf('{');
    if (start == -1) return null;

    var depth = 0;
    for (var i = start; i < buffer.length; i++) {
      if (buffer[i] == '{') depth++;
      if (buffer[i] == '}') {
        depth--;
        if (depth == 0) return buffer.substring(start, i + 1);
      }
    }
    return null;
  }

  void _parseAndEmit(String payload) {
    if (payload.isEmpty) return;

    final reading = _parseReading(payload);
    if (reading == null) {
      _lastError = 'ESP32 sent unreadable sensor data.';
      _notify();
      return;
    }

    _latestReading = reading;
    _lastError = null;
    _onReading?.call(reading);
    _notify();
  }

  Esp32SensorReading? _parseReading(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final temperature = _numberFrom(decoded, const [
          'temperature',
          'temperatureC',
          'temp',
          't',
        ]);
        final humidity = _numberFrom(decoded, const [
          'humidity',
          'humidityPercent',
          'h',
        ]);
        final airQuality = _numberFrom(decoded, const [
          'airQuality',
          'air_quality',
          'airPpm',
          'ppm',
          'aq',
        ]);

        if (temperature != null && humidity != null && airQuality != null) {
          return Esp32SensorReading(
            temperatureC: temperature,
            humidityPercent: humidity,
            airQualityPpm: airQuality.round(),
            receivedAt: DateTime.now(),
          );
        }
      }
    } catch (_) {
      return _parseKeyValueReading(payload);
    }

    return _parseKeyValueReading(payload);
  }

  Esp32SensorReading? _parseKeyValueReading(String payload) {
    final temperature = _matchNumber(
      payload,
      RegExp(
        r'(?:temperature|temp|t)\s*[:=]\s*(-?\d+(?:\.\d+)?)',
        caseSensitive: false,
      ),
    );
    final humidity = _matchNumber(
      payload,
      RegExp(
        r'(?:humidity|hum|h)\s*[:=]\s*(-?\d+(?:\.\d+)?)',
        caseSensitive: false,
      ),
    );
    final airQuality = _matchNumber(
      payload,
      RegExp(
        r'(?:airQuality|air_quality|air|ppm|aq)\s*[:=]\s*(-?\d+(?:\.\d+)?)',
        caseSensitive: false,
      ),
    );

    if (temperature == null || humidity == null || airQuality == null) {
      return null;
    }

    return Esp32SensorReading(
      temperatureC: temperature,
      humidityPercent: humidity,
      airQualityPpm: airQuality.round(),
      receivedAt: DateTime.now(),
    );
  }

  double? _numberFrom(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
    }
    return null;
  }

  double? _matchNumber(String value, RegExp pattern) {
    final match = pattern.firstMatch(value);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  Future<void> _stopScanQuietly() async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {
      // Scanning may already have stopped.
    }
  }

  void _setStatus(Esp32SensorConnectionStatus status) {
    _status = status;
    _notify();
  }

  void _setError(String message) {
    _lastError = message;
    _status = Esp32SensorConnectionStatus.error;
    _notify();
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    return message
        .replaceFirst('Exception: ', '')
        .replaceFirst('StateError: ', '')
        .replaceFirst('FlutterBluePlusException: ', '')
        .trim();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_scanSubscription?.cancel());
    unawaited(_valueSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    unawaited(_stopScanQuietly());
    final device = _device;
    if (device != null && device.isConnected) {
      unawaited(device.disconnect());
    }
    super.dispose();
  }
}
