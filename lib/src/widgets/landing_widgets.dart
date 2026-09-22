part of '../../main.dart';

class _LandingBrand extends StatelessWidget {
  const _LandingBrand();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'Roostify',
          style: TextStyle(
            color: Color(0xFF17191E),
            fontWeight: FontWeight.w900,
            fontSize: 30,
            letterSpacing: -1,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'SMART ROOSTER MONITORING',
          style: TextStyle(
            color: Color(0xFFFF6A32),
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: .45,
          ),
        ),
      ],
    );
  }
}

class _AuthImageBackground extends StatelessWidget {
  const _AuthImageBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('assets/app_icon.jpeg'),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}

class _LandingLoginPanel extends StatelessWidget {
  const _LandingLoginPanel({required this.onUserTap, this.onAdminTap});

  final VoidCallback onUserTap;

  /// Null hides the admin access button entirely (see [_adminLoginEnabled]).
  final VoidCallback? onAdminTap;
  static const _loginOrange = Color(0xFFFF6A19);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 34, 30, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          const _LandingBrand(),
          const SizedBox(height: 22),
          const Text(
            'Monitor your rooster, anytime, anywhere.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF72757C), fontSize: 15),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF44A12),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 5,
                shadowColor: const Color(0x66F44A12),
              ),
              onPressed: onUserTap,
              icon: const Icon(Icons.login_rounded, size: 26),
              label: const Text(
                'Log In',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (onAdminTap case final onAdminTap?) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _loginOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 5,
                  shadowColor: const Color(0x55FF6A19),
                ),
                onPressed: onAdminTap,
                icon: const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 26,
                ),
                label: const Text(
                  'Admin access',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  final IconData icon;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: const Color(0xFFF4512A)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF17191E),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.mutedText, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(color: colors.mutedText, height: 1.5)),
      ],
    );
  }
}

/// Card for the farmer dashboard's "Live Environment" section. It shows
/// whether the ESP32 is actively posting readings to Supabase over Wi-Fi,
/// and offers Bluetooth-based setup (initial Wi-Fi configuration or
/// "forget Wi-Fi") — Bluetooth is never used to view live data, only to
/// (re)configure the device.
class Esp32SensorConnectionCard extends StatefulWidget {
  const Esp32SensorConnectionCard({
    super.key,
    required this.controller,
    required this.username,
  });

  final AppController controller;
  final String username;

  @override
  State<Esp32SensorConnectionCard> createState() =>
      _Esp32SensorConnectionCardState();
}

class _Esp32SensorConnectionCardState extends State<Esp32SensorConnectionCard> {
  Future<void> _openWifiSetup(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.appColors.surface,
      builder: (_) => _Esp32WifiSetupSheet(
        controller: widget.controller,
        username: widget.username,
      ),
    );
    await widget.controller.disconnectEsp32Setup();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final controller = widget.controller;
    final monitor = controller.userByUsername(widget.username)?.monitor;
    final online = monitor?.isLive ?? false;
    final everConfigured = monitor?.lastUpdatedAt != null;
    final sensorFault =
        online &&
        (monitor!.dhtAvailable == false || monitor.airAvailable == false);

    final accent = sensorFault
        ? const Color(0xFFE6B452)
        : online
        ? const Color(0xFF26C281)
        : const Color(0xFF8E97B8);

    final String detail;
    if (online) {
      detail = sensorFault
          ? _sensorFaultMessage(monitor)
          : 'Receiving live sensor readings - updated ${_sensorTimeLabel(monitor!.lastUpdatedAt!)}';
    } else if (everConfigured) {
      detail =
          'Sensor offline - last update ${_sensorTimeLabel(monitor!.lastUpdatedAt!)}';
    } else {
      detail = 'No sensor data yet. Set up the sensor\'s Wi-Fi to get started.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: .3)),
                ),
                child: Icon(
                  online ? Icons.sensors_outlined : Icons.sensors_off_outlined,
                  color: accent,
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Semantics(
                  label: 'Environmental Sensor. $detail',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Environmental Sensor',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        detail,
                        style: TextStyle(
                          color: !online
                              ? colors.mutedText
                              : sensorFault
                              ? const Color(0xFFB8860B)
                              : colors.mutedText,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _openWifiSetup(context),
              icon: const Icon(Icons.wifi_outlined),
              label: Text(
                everConfigured
                    ? 'Reconfigure Sensor Wi-Fi'
                    : 'Set Up Sensor Wi-Fi',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _sensorFaultMessage(MonitorSnapshot monitor) {
    if (!monitor.dhtAvailable && !monitor.airAvailable) {
      return 'DHT and air quality sensors are not responding — check the wiring.';
    }
    if (!monitor.dhtAvailable) {
      return 'DHT sensor is not responding — check the wiring.';
    }
    return 'Air quality sensor is not responding — check the wiring.';
  }
}

class _Esp32WifiSetupSheet extends StatefulWidget {
  const _Esp32WifiSetupSheet({
    required this.controller,
    required this.username,
  });

  final AppController controller;
  final String username;

  @override
  State<_Esp32WifiSetupSheet> createState() => _Esp32WifiSetupSheetState();
}

class _Esp32WifiSetupSheetState extends State<_Esp32WifiSetupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _result;
  bool _hidePassword = true;
  bool _scanningWifi = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.startEsp32Discovery());
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _selectDevice(DiscoveredEsp32Device device) async {
    await widget.controller.connectToEsp32Device(device);
  }

  Future<void> _searchAgain() => widget.controller.startEsp32Discovery();

  Future<void> _scanWifiNetworks() async {
    if (_scanningWifi) return;
    setState(() => _scanningWifi = true);
    try {
      final networks = await widget.controller.scanEsp32WifiNetworks();
      if (!mounted) return;
      if (networks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No Wi-Fi networks found near the sensor.'),
          ),
        );
        return;
      }
      final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: context.appColors.surface,
        builder: (_) => _WifiNetworkPickerSheet(networks: networks),
      );
      if (selected != null && mounted) {
        setState(() => _ssidController.text = selected);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not scan for Wi-Fi: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _scanningWifi = false);
    }
  }

  Future<void> _sendWifiSettings() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _result = null);
    try {
      final result = await widget.controller.configureEsp32Wifi(
        username: widget.username,
        ssid: _ssidController.text,
        password: _passwordController.text,
      );
      _passwordController.clear();
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _result = error.toString());
    }
  }

  Future<void> _forgetWifi() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Forget Wi-Fi?'),
        content: const Text(
          'The sensor will erase its saved Wi-Fi network, password, and linked '
          'account, and stop posting readings until it is set up again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Forget Wi-Fi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _result = null);
    try {
      final result = await widget.controller.forgetEsp32Wifi();
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _result = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final status = widget.controller.esp32SetupStatus;
        return status == Esp32ProvisioningStatus.connected
            ? _buildWifiForm(context)
            : _buildDevicePicker(context, status);
      },
    );
  }

  Widget _buildDevicePicker(
    BuildContext context,
    Esp32ProvisioningStatus status,
  ) {
    final colors = context.appColors;
    final devices = widget.controller.discoveredEsp32Devices;
    final scanning = status == Esp32ProvisioningStatus.scanning;
    final connecting = status == Esp32ProvisioningStatus.connecting;
    final error = status == Esp32ProvisioningStatus.error
        ? widget.controller.esp32SetupError
        : null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          4,
          22,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Find Your Environmental Sensor',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                if (scanning)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              connecting
                  ? 'Connecting over Bluetooth…'
                  : scanning
                  ? 'Searching nearby over Bluetooth…'
                  : devices.isEmpty
                  ? 'No environmental sensors found nearby. Make sure it\'s powered on and close by.'
                  : 'Select the sensor you want to set up.',
              style: TextStyle(color: colors.mutedText, height: 1.35),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: const TextStyle(
                  color: Color(0xFFFF6B72),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (connecting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (devices.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return Material(
                      color: colors.surfaceRaised,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _selectDevice(device),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.sensors_outlined, color: _appAccent),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Environmental Sensor',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'ID ····${device.shortId}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.mutedText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: colors.mutedText,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: scanning || connecting ? null : _searchAgain,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Search Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWifiForm(BuildContext context) {
    // build() already wraps this whole sheet in one AnimatedBuilder keyed to
    // the same controller, so this doesn't need its own nested listener.
    final colors = context.appColors;
    final sending = widget.controller.isConfiguringSensorWifi;
    final status = _result ?? widget.controller.sensorWifiProvisioningStatus;
    final failed =
        status != null &&
        !sending &&
        !status.startsWith('OK:') &&
        !status.startsWith('Sending');

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          4,
          22,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Set Up Environmental Sensor Wi-Fi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Roostify sends these details directly to your environmental sensor over Bluetooth.',
                style: TextStyle(color: colors.mutedText, height: 1.35),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _ssidController,
                enabled: !sending,
                autofocus: true,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                maxLength: 32,
                decoration: InputDecoration(
                  labelText: 'Wi-Fi name (SSID)',
                  prefixIcon: const Icon(Icons.wifi_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'Scan for nearby Wi-Fi networks',
                    onPressed: sending || _scanningWifi
                        ? null
                        : _scanWifiNetworks,
                    icon: _scanningWifi
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find_outlined),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter the Wi-Fi name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                enabled: !sending,
                autocorrect: false,
                enableSuggestions: false,
                obscureText: _hidePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _sendWifiSettings(),
                maxLength: 63,
                decoration: InputDecoration(
                  labelText: 'Wi-Fi password',
                  prefixIcon: const Icon(Icons.password_outlined),
                  suffixIcon: IconButton(
                    tooltip: _hidePassword ? 'Show password' : 'Hide password',
                    onPressed: sending
                        ? null
                        : () => setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Use this only while physically near the device and on a trusted phone. Roostify never sends your Supabase password to the sensor.',
                style: TextStyle(
                  color: colors.mutedText,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              if (status != null) ...[
                const SizedBox(height: 14),
                Text(
                  status,
                  style: TextStyle(
                    color: failed ? const Color(0xFFFF6B72) : colors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: sending || !widget.controller.canConfigureSensorWifi
                    ? null
                    : _sendWifiSettings,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  sending
                      ? 'Connecting Sensor to Wi-Fi…'
                      : 'Save and Connect Wi-Fi',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: sending ? null : _forgetWifi,
                icon: const Icon(Icons.wifi_off_outlined),
                label: const Text('Forget Wi-Fi on This Device'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets the farmer pick one of the Wi-Fi networks the sensor itself found
/// during a scan, instead of typing the name by hand. Pops with the chosen
/// SSID, or null if dismissed without picking one.
class _WifiNetworkPickerSheet extends StatelessWidget {
  const _WifiNetworkPickerSheet({required this.networks});

  final List<String> networks;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nearby Wi-Fi Networks',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Found by the sensor itself. Tap the network you want it to join.',
              style: TextStyle(color: colors.mutedText, height: 1.35),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: networks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final ssid = networks[index];
                  return Material(
                    color: colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(context).pop(ssid),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.wifi_rounded, color: _appAccent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                ssid,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: colors.mutedText,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular ring gauge for one ESP32 reading, in the style of a fitness
/// progress ring: colored arc for the reading, value in the middle, and the
/// warning level underneath.
class CircularSensorGauge extends StatelessWidget {
  const CircularSensorGauge({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.progress,
    required this.icon,
    required this.status,
    required this.level,
    required this.accent,
    this.alerts = const [],
    this.available = true,
  });

  final String title;
  final String value;
  final String unit;
  final double progress;
  final IconData icon;
  final String status;
  final SensorWarningLevel level;
  final Color accent;

  /// False when this sensor (DHT11 for temperature/humidity, MQ135 for air)
  /// isn't currently reporting — either the whole ESP32 is offline, or just
  /// this one sensor is unplugged/faulty while the device is otherwise
  /// online. The card renders desaturated and shows [status] instead of a
  /// severity tag in that case, since [level] isn't a real reading.
  final bool available;

  /// Active warnings that belong to this sensor; shown as a badge on the
  /// ring and in a pop-up when the card is tapped.
  final List<AlertItem> alerts;

  void _showWarnings(BuildContext context) {
    final colors = context.appColors;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$title Warnings',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (alerts.isEmpty)
                    Text(
                      'No active warnings. $status.',
                      style: TextStyle(color: colors.mutedText, height: 1.45),
                    )
                  else
                    ...alerts.map((alert) => AlertCard(alert: alert)),
                  const SizedBox(height: 8),
                  Text(
                    'Open the Guides tab for what each warning level means '
                    'and what to do about it.',
                    style: TextStyle(
                      color: colors.subtleText,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final statusColor = available ? accent : colors.mutedText;

    return Tooltip(
      message: '$title: $value $unit - $status',
      child: Semantics(
        label: '$title sensor, $value $unit, $status',
        child: Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showWarnings(context),
            child: Opacity(
              // Grays the whole card, not just the ring/tag, so a sensor
              // that isn't reporting reads as clearly disabled rather than
              // just a differently-colored "normal" state.
              opacity: available ? 1 : 0.55,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FractionallySizedBox(
                      widthFactor: 0.8,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                strokeWidth: 8,
                                strokeCap: StrokeCap.round,
                                color: statusColor,
                                backgroundColor: statusColor.withValues(
                                  alpha: .12,
                                ),
                              ),
                            ),
                            FittedBox(
                              // Scales the whole icon/value/unit cluster down
                              // together on narrow screens instead of letting
                              // any one line overflow the circle — a fixed
                              // pixel budget for each line broke on very
                              // narrow widths where the gauge itself is small.
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon, color: statusColor, size: 18),
                                  Text(
                                    value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    unit,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.mutedText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (alerts.isNotEmpty)
                              Positioned(
                                top: 1,
                                right: 1,
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: statusColor,
                                  foregroundColor: Colors.white,
                                  child: Text(
                                    '${alerts.length}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    available
                        ? SensorLevelTag(level: level, compact: true)
                        : const _SensorUnavailableTag(),
                    const SizedBox(height: 4),
                    // The status line gets whatever vertical space is left in
                    // the card instead of a fixed height, then FittedBox
                    // shrinks the (fully wrapped, un-truncated) text down to
                    // fit that space if it's too long — so the full message
                    // always shows instead of being cut off with an ellipsis.
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: constraints.maxWidth,
                              child: Text(
                                status,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.mutedText,
                                  fontSize: 13,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SensorCard extends StatelessWidget {
  const SensorCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    required this.status,
    required this.level,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final String status;
  final SensorWarningLevel level;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final statusColor = level.color;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 260;
        final iconSize = compact ? 40.0 : 44.0;
        final tag = SensorLevelTag(level: level, compact: compact);

        return Tooltip(
          message: '$title: $value - $status',
          child: Semantics(
            label: '$title sensor, $value, $status',
            child: Container(
              clipBehavior: Clip.antiAlias,
              constraints: const BoxConstraints(minHeight: 118),
              padding: EdgeInsets.all(compact ? 12 : 14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.42)),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: accent,
                          size: compact ? 20 : 22,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.mutedText,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.text,
                                fontSize: compact ? 22 : 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!compact) ...[const SizedBox(width: 10), tag],
                    ],
                  ),
                  if (compact) ...[const SizedBox(height: 10), tag],
                  const SizedBox(height: 10),
                  Text(
                    status,
                    maxLines: compact ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.mutedText, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _sensorLevelValue(level),
                      minHeight: 4,
                      backgroundColor: statusColor.withValues(alpha: 0.14),
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

double _sensorLevelValue(SensorWarningLevel level) {
  return switch (level) {
    SensorWarningLevel.normal => 0.2,
    SensorWarningLevel.caution => 0.4,
    SensorWarningLevel.warning => 0.6,
    SensorWarningLevel.danger => 0.8,
    SensorWarningLevel.critical => 1.0,
  };
}

class SensorLevelTag extends StatelessWidget {
  const SensorLevelTag({super.key, required this.level, this.compact = false});

  final SensorWarningLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = level.color;

    return Tooltip(
      message: '${level.label.toLowerCase()} sensor reading',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Text(
          level.label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// Shown on a [CircularSensorGauge] instead of [SensorLevelTag] when that
/// sensor isn't reporting - distinct from "NORMAL" so a disconnected sensor
/// is never mistaken for a farm that's actually in good condition.
class _SensorUnavailableTag extends StatelessWidget {
  const _SensorUnavailableTag();

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.mutedText;

    return Tooltip(
      message: 'This sensor is not reporting data',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          'NO SIGNAL',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class SeverityTag extends StatelessWidget {
  const SeverityTag({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
