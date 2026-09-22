import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const esp32SensorDeviceName = 'DominiGo-ESP32';
const esp32SensorServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const esp32SensorConfigUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

enum Esp32ProvisioningStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

/// One environmental reading, as stored under `farms/{uid}/status/latest` in
/// Postgres (see [SupabaseBackendService.watchLatestSensor]). The ESP32
/// posts these directly over Wi-Fi; nothing here comes over Bluetooth.
class Esp32SensorReading {
  const Esp32SensorReading({
    required this.temperatureC,
    required this.humidityPercent,
    required this.airQualityPpm,
    required this.receivedAt,
    this.dhtAvailable = true,
    this.airAvailable = true,
  });

  final double temperatureC;
  final double humidityPercent;
  final int airQualityPpm;
  final DateTime receivedAt;

  /// False when the ESP32 reported the DHT sensor as unreadable (bad wiring,
  /// disconnected, etc) on its most recent upload. [temperatureC] and
  /// [humidityPercent] are then a placeholder rather than a fresh reading.
  final bool dhtAvailable;

  /// Same as [dhtAvailable] but for the MQ135 air-quality sensor.
  final bool airAvailable;
}

/// One nearby environmental sensor found while searching for setup, before
/// it's been connected to. Wraps the underlying BLE device so nothing
/// outside this file needs to depend on flutter_blue_plus types directly.
class DiscoveredEsp32Device {
  const DiscoveredEsp32Device._(this.id, this.rssi, this._device);

  /// Stable per-device identifier (its Bluetooth address). Only used to tell
  /// otherwise-identical sensors apart in a list - a raw Bluetooth address
  /// isn't meaningful to a farmer, so the UI shows a short suffix of it at
  /// most, never the full [id].
  final String id;
  final int rssi;
  final BluetoothDevice _device;

  /// Last 4 characters of [id] with separators stripped, for a compact
  /// "which one is this" hint when more than one sensor is found nearby.
  String get shortId {
    final compact = id.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
    return compact.length <= 4
        ? compact
        : compact.substring(compact.length - 4);
  }
}

/// Bluetooth Low Energy client used ONLY to set up an ESP32: pairing it with
/// a Wi-Fi network and the signed-in farmer's account, or resetting that
/// configuration ("forget Wi-Fi"). Once the ESP32 is on Wi-Fi, it posts
/// sensor readings straight to Supabase itself - the app never needs a BLE
/// connection to see live data, only to (re)configure the device.
class Esp32ProvisioningClient extends ChangeNotifier {
  static final Guid _serviceGuid = Guid(esp32SensorServiceUuid);
  static final Guid _configGuid = Guid(esp32SensorConfigUuid);
  static const Duration _scanTimeout = Duration(seconds: 12);
  static const Duration _connectTimeout = Duration(seconds: 14);

  Esp32ProvisioningStatus _status = Esp32ProvisioningStatus.disconnected;
  BluetoothDevice? _device;
  final List<DiscoveredEsp32Device> _discoveredDevices = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  BluetoothCharacteristic? _configCharacteristic;
  String? _lastError;
  String? _wifiProvisioningStatus;
  bool _isProvisioningWifi = false;
  bool _disposed = false;

  Esp32ProvisioningStatus get status => _status;
  String? get lastError => _lastError;
  String? get wifiProvisioningStatus => _wifiProvisioningStatus;
  bool get isProvisioningWifi => _isProvisioningWifi;
  bool get canProvisionWifi => isConnected && _configCharacteristic != null;
  bool get isBusy =>
      _status == Esp32ProvisioningStatus.scanning ||
      _status == Esp32ProvisioningStatus.connecting;
  bool get isConnected => _status == Esp32ProvisioningStatus.connected;

  /// Sensors found by the most recent [startDiscovery] call, updated live as
  /// more advertise themselves. Stays populated after the scan window ends
  /// so the picker UI can still be browsed/tapped; cleared only when a new
  /// discovery starts.
  List<DiscoveredEsp32Device> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);

  /// Scans for nearby environmental sensors and adds each one found to
  /// [discoveredDevices] as it's seen - it does not connect to anything on
  /// its own. Call [connectToDevice] once the user picks one from that list.
  Future<void> startDiscovery() async {
    if (isBusy) return;

    _lastError = null;
    _wifiProvisioningStatus = null;
    _discoveredDevices.clear();
    _setStatus(Esp32ProvisioningStatus.scanning);

    try {
      if (kIsWeb && !await FlutterBluePlus.isSupported) {
        _setError(
          'Bluetooth setup needs a browser with Web Bluetooth support, such as Chrome or Edge, served over HTTPS.',
        );
        return;
      }

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

      // The scan window ran out on its own. Finding nothing isn't an error
      // here - the picker shows an empty state with a "Search Again" button
      // - so just drop back to idle instead of raising a hard error.
      if (_status == Esp32ProvisioningStatus.scanning) {
        _setStatus(Esp32ProvisioningStatus.disconnected);
      }
    } on TimeoutException catch (error) {
      await _stopScanQuietly();
      _setError(error.message ?? 'Bluetooth did not become ready in time.');
    } catch (error) {
      await _stopScanQuietly();
      _setError(_friendlyError(error));
    }
  }

  /// Stops an in-progress [startDiscovery] scan without disconnecting from
  /// anything, e.g. because the user picked a device before the scan window
  /// naturally ended.
  Future<void> stopDiscovery() async {
    await _stopScanQuietly();
    if (_status == Esp32ProvisioningStatus.scanning) {
      _setStatus(Esp32ProvisioningStatus.disconnected);
    }
  }

  Future<void> disconnect() async {
    await _stopScanQuietly();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _configCharacteristic = null;
    _isProvisioningWifi = false;
    _wifiProvisioningStatus = null;

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
    _setStatus(Esp32ProvisioningStatus.disconnected);
  }

  void _handleScanResults(List<ScanResult> results) {
    if (_status != Esp32ProvisioningStatus.scanning) return;

    var changed = false;
    for (final result in results) {
      if (!_matchesSensor(result)) continue;
      final id = result.device.remoteId.str;
      final index = _discoveredDevices.indexWhere((d) => d.id == id);
      final entry = DiscoveredEsp32Device._(id, result.rssi, result.device);
      if (index == -1) {
        _discoveredDevices.add(entry);
        changed = true;
      } else if (_discoveredDevices[index].rssi != result.rssi) {
        _discoveredDevices[index] = entry;
        changed = true;
      }
    }
    if (changed) _notify();
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

  /// Connects to one of [discoveredDevices], stopping any in-progress scan
  /// first. Deliberately callable while [status] is still `scanning` - the
  /// whole point of listing devices as they're found is to let the user tap
  /// one before the scan window ends, so only an already-in-progress
  /// connection attempt (or an existing connection) blocks a new one.
  Future<void> connectToDevice(DiscoveredEsp32Device target) async {
    if (_status == Esp32ProvisioningStatus.connecting || isConnected) return;

    _setStatus(Esp32ProvisioningStatus.connecting);
    await _stopScanQuietly();

    final device = target._device;
    try {
      _device = device;
      await _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected &&
            _status == Esp32ProvisioningStatus.connected) {
          _setStatus(Esp32ProvisioningStatus.disconnected);
        }
      });

      if (!device.isConnected) {
        await device.connect(license: License.free, timeout: _connectTimeout);
      }

      final services = await device.discoverServices();
      _configCharacteristic = _findConfigCharacteristic(services);
      if (_configCharacteristic == null) {
        throw StateError(
          'This sensor does not support Wi-Fi setup yet. Update its firmware, then try again.',
        );
      }

      _lastError = null;
      _setStatus(Esp32ProvisioningStatus.connected);
    } catch (error) {
      await disconnect();
      _setError(_friendlyError(error));
    }
  }

  BluetoothCharacteristic? _findConfigCharacteristic(
    List<BluetoothService> services,
  ) {
    for (final service in services) {
      if (service.uuid != _serviceGuid) continue;
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid == _configGuid) return characteristic;
      }
    }
    return null;
  }

  /// Sends the Wi-Fi details to the ESP32's BLE configuration characteristic.
  /// The ESP32 stores the network details locally and uses them to connect
  /// to Wi-Fi and post readings to Supabase; the UID is only a label used to
  /// tag those readings and is not used as Supabase credentials.
  Future<String> provisionWifi({
    required String ssid,
    required String password,
    String? ownerUid,
  }) async {
    final normalizedSsid = ssid.trim();
    final normalizedOwnerUid = ownerUid?.trim();
    if (normalizedSsid.isEmpty || normalizedSsid.length > 32) {
      throw ArgumentError.value(
        ssid,
        'ssid',
        'Use a Wi-Fi name of 1–32 characters.',
      );
    }
    if (password.length > 63) {
      throw ArgumentError.value(
        password,
        'password',
        'Use a Wi-Fi password of at most 63 characters.',
      );
    }
    if (normalizedOwnerUid != null && normalizedOwnerUid.length > 128) {
      throw ArgumentError.value(
        ownerUid,
        'ownerUid',
        'The account identifier is too long.',
      );
    }

    final characteristic = _configCharacteristic;
    if (!isConnected || characteristic == null) {
      throw StateError(
        'This sensor\'s firmware does not support Wi-Fi setup. Update it, then reconnect.',
      );
    }

    _isProvisioningWifi = true;
    _wifiProvisioningStatus = 'Sending Wi-Fi settings to the sensor…';
    _notify();

    try {
      await _writeConfigCommand(characteristic, 'SSID:$normalizedSsid');
      await _writeConfigCommand(characteristic, 'PASSWORD:$password');
      if (normalizedOwnerUid != null && normalizedOwnerUid.isNotEmpty) {
        await _writeConfigCommand(
          characteristic,
          'OWNER_UID:$normalizedOwnerUid',
        );
      }
      await _writeConfigCommand(characteristic, 'SAVE');
      final response = await _writeConfigCommand(characteristic, 'CONNECT');
      _wifiProvisioningStatus = response;
      if (!response.startsWith('OK:')) {
        throw StateError(response);
      }
      return response;
    } catch (error) {
      _wifiProvisioningStatus = _friendlyError(error);
      rethrow;
    } finally {
      _isProvisioningWifi = false;
      _notify();
    }
  }

  /// Wipes the ESP32's saved Wi-Fi network, password, and owner UID, so it
  /// falls back to BLE-only setup mode.
  Future<String> forgetWifi() async {
    final characteristic = _configCharacteristic;
    if (!isConnected || characteristic == null) {
      throw StateError(
        'Connect to the sensor over Bluetooth before forgetting its Wi-Fi.',
      );
    }

    _isProvisioningWifi = true;
    _wifiProvisioningStatus = 'Clearing the sensor\'s saved Wi-Fi…';
    _notify();

    try {
      final response = await _writeConfigCommand(characteristic, 'CLEAR');
      _wifiProvisioningStatus = response;
      if (!response.startsWith('OK:')) {
        throw StateError(response);
      }
      return response;
    } catch (error) {
      _wifiProvisioningStatus = _friendlyError(error);
      rethrow;
    } finally {
      _isProvisioningWifi = false;
      _notify();
    }
  }

  /// Slower BLE commands that block on-device (connecting to Wi-Fi, or
  /// scanning for it) need more room than a plain config write.
  static const _slowCommands = {'CONNECT', 'SCAN_WIFI'};

  /// Asks the connected sensor to scan for nearby Wi-Fi networks and returns
  /// the SSIDs it can see, strongest signal first. Runs on the sensor's own
  /// radio, not the phone's - that's the one that actually needs to reach
  /// the network once configured, and the two don't always see the same
  /// set even when they're right next to each other.
  Future<List<String>> scanWifiNetworks() async {
    final characteristic = _configCharacteristic;
    if (!isConnected || characteristic == null) {
      throw StateError(
        'Connect to the sensor over Bluetooth before scanning for Wi-Fi.',
      );
    }

    final response = await _writeConfigCommand(characteristic, 'SCAN_WIFI');
    if (!response.startsWith('OK:')) {
      throw StateError(response);
    }
    final payload = response.substring(3);
    if (payload.isEmpty) return const [];
    return payload.split('|').where((ssid) => ssid.isNotEmpty).toList();
  }

  Future<String> _writeConfigCommand(
    BluetoothCharacteristic characteristic,
    String command,
  ) async {
    final canWriteWithResponse = characteristic.properties.write;
    final canWriteWithoutResponse =
        characteristic.properties.writeWithoutResponse;
    if (!canWriteWithResponse && !canWriteWithoutResponse) {
      throw StateError(
        'The sensor\'s Wi-Fi setup characteristic is not writable.',
      );
    }

    final timeoutSeconds = _slowCommands.contains(command) ? 22 : 8;

    await characteristic.write(
      utf8.encode(command),
      withoutResponse: !canWriteWithResponse,
      timeout: timeoutSeconds,
    );

    if (!characteristic.properties.read) return 'OK:$command sent';
    // The ESP32 updates the characteristic value inside its write callback.
    // A brief wait avoids racing the following GATT read on slower phones.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final response = utf8
        .decode(
          await characteristic.read(timeout: timeoutSeconds),
          allowMalformed: true,
        )
        .trim();
    return response.isEmpty ? 'OK:$command sent' : response;
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

  void _setStatus(Esp32ProvisioningStatus status) {
    _status = status;
    _notify();
  }

  void _setError(String message) {
    _lastError = message;
    _status = Esp32ProvisioningStatus.error;
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
    unawaited(_connectionSubscription?.cancel());
    unawaited(_stopScanQuietly());
    final device = _device;
    if (device != null && device.isConnected) {
      unawaited(device.disconnect());
    }
    super.dispose();
  }
}
