part of '../../main.dart';

class _GoogleMark extends StatelessWidget {
  const _GoogleMark({this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Google',
      image: true,
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size),
          painter: const _GoogleMarkPainter(),
        ),
      ),
    );
  }
}

/// Renders Google's actual "G" mark, traced from Google's official 18x18
/// four-path icon (the same shape used on Google's own Sign In buttons) —
/// not an approximation built from generic arcs, so the colored segments
/// land exactly where they do in the real logo.
class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 18, size.height / 18);
    final paint = Paint()..style = PaintingStyle.fill;

    final bluePath = Path()
      ..moveTo(17.64, 9.2045)
      ..relativeCubicTo(0, -0.6381, -0.0573, -1.2518, -0.1636, -1.8409)
      ..lineTo(9, 7.3636)
      ..relativeLineTo(0, 3.4814)
      ..relativeLineTo(4.8436, 0)
      ..relativeCubicTo(-0.2086, 1.125, -0.8427, 2.0782, -1.7963, 2.7164)
      ..relativeLineTo(0, 2.2581)
      ..relativeLineTo(2.9087, 0)
      ..relativeCubicTo(1.7018, -1.5668, 2.6849, -3.8741, 2.6849, -6.6149)
      ..close();
    canvas.drawPath(bluePath, paint..color = _blue);

    final greenPath = Path()
      ..moveTo(9, 18)
      ..relativeCubicTo(2.43, 0, 4.4673, -0.806, 5.9564, -2.1805)
      ..relativeLineTo(-2.9087, -2.2581)
      ..relativeCubicTo(-0.806, 0.54, -1.8368, 0.859, -3.0477, 0.859)
      ..relativeCubicTo(-2.344, 0, -4.3282, -1.5831, -5.0359, -3.7104)
      ..lineTo(0.9573, 10.71)
      ..relativeLineTo(0, 2.3318)
      ..cubicTo(2.4382, 15.9832, 5.4818, 18, 9, 18)
      ..close();
    canvas.drawPath(greenPath, paint..color = _green);

    final yellowPath = Path()
      ..moveTo(3.9641, 10.71)
      ..relativeCubicTo(-0.18, -0.54, -0.2822, -1.1168, -0.2822, -1.71)
      ..relativeCubicTo(0, -0.5932, 0.1023, -1.17, 0.2822, -1.71)
      ..lineTo(3.9641, 4.9582)
      ..lineTo(0.9573, 4.9582)
      ..cubicTo(0.3477, 6.1732, 0, 7.5477, 0, 9)
      ..relativeCubicTo(0, 1.4523, 0.3477, 2.8268, 0.9573, 4.0418)
      ..lineTo(3.9641, 10.71)
      ..close();
    canvas.drawPath(yellowPath, paint..color = _yellow);

    final redPath = Path()
      ..moveTo(9, 3.5786)
      ..relativeCubicTo(1.3214, 0, 2.5077, 0.4541, 3.4405, 1.346)
      ..relativeLineTo(2.5813, -2.5814)
      ..cubicTo(13.4632, 0.8918, 11.426, 0, 9, 0)
      ..cubicTo(5.4818, 0, 2.4382, 2.0168, 0.9573, 4.9582)
      ..lineTo(3.9641, 7.29)
      ..cubicTo(4.6718, 5.1618, 6.656, 3.5786, 9, 3.5786)
      ..close();
    canvas.drawPath(redPath, paint..color = _red);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoogleMarkPainter oldDelegate) => false;
}

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
  const _LandingLoginPanel({required this.onUserTap, required this.onAdminTap});

  final VoidCallback onUserTap;
  final VoidCallback onAdminTap;
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
              icon: const Icon(Icons.admin_panel_settings_outlined, size: 26),
              label: const Text(
                'Admin access',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
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

class Esp32SensorConnectionCard extends StatelessWidget {
  const Esp32SensorConnectionCard({
    super.key,
    required this.controller,
    required this.username,
  });

  final AppController controller;
  final String username;

  void _showSensorDetails(BuildContext context) {
    final reading = controller.latestSensorReading;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.appColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'ESP32 Sensor Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                controller.sensorStatusLabel,
                style: TextStyle(color: context.appColors.mutedText),
              ),
              const SizedBox(height: 18),
              if (reading != null)
                Row(
                  children: [
                    Expanded(
                      child: SummaryMiniCard(
                        title: 'Temperature',
                        value: reading.dhtAvailable
                            ? '${reading.temperatureC.toStringAsFixed(1)} °C'
                            : 'Offline',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SummaryMiniCard(
                        title: 'Humidity',
                        value: reading.dhtAvailable
                            ? '${reading.humidityPercent.toStringAsFixed(0)}%'
                            : 'Offline',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SummaryMiniCard(
                        title: 'Air',
                        value: reading.airAvailable
                            ? '${reading.airQualityPpm} ppm'
                            : 'Offline',
                      ),
                    ),
                  ],
                )
              else
                const Text('Waiting for the first sensor reading...'),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  controller.disconnectEsp32Sensor();
                },
                icon: const Icon(Icons.bluetooth_disabled_outlined),
                label: const Text('Disconnect ESP32'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final status = controller.sensorConnectionStatus;
    final connected = status == Esp32SensorConnectionStatus.connected;
    final busy =
        status == Esp32SensorConnectionStatus.scanning ||
        status == Esp32SensorConnectionStatus.connecting;
    final error = status == Esp32SensorConnectionStatus.error;
    // Being BLE-connected doesn't mean readings are actually flowing — flag
    // that distinctly instead of showing the same green "connected" state
    // whether or not any usable data has arrived.
    final readIssue = controller.sensorHasReadIssue;
    final reading = controller.latestSensorReading;
    final accent = readIssue
        ? const Color(0xFFE6B452)
        : connected
        ? const Color(0xFF26C281)
        : error
        ? const Color(0xFFFF6B72)
        : busy
        ? const Color(0xFFE6B452)
        : const Color(0xFF8E97B8);
    final detail = reading == null
        ? controller.sensorStatusLabel
        : '${controller.sensorStatusLabel} - updated ${_sensorTimeLabel(reading.receivedAt)}';

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
                  connected
                      ? Icons.bluetooth_connected_outlined
                      : Icons.bluetooth_searching_outlined,
                  color: accent,
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ESP32 Sensor',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      detail,
                      style: TextStyle(
                        color: error || readIssue
                            ? const Color(0xFFFF8A98)
                            : colors.mutedText,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: busy
                  ? null
                  : connected
                  ? () => _showSensorDetails(context)
                  : () => controller.connectEsp32Sensor(username),
              icon: Icon(
                busy
                    ? Icons.bluetooth_searching_outlined
                    : connected
                    ? Icons.bluetooth_rounded
                    : Icons.add_link_rounded,
              ),
              label: Text(
                busy
                    ? 'Connecting...'
                    : connected
                    ? 'View Sensor Details'
                    : 'Connect ESP32 Sensor',
              ),
            ),
          ),
        ],
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
  });

  final String title;
  final String value;
  final String unit;
  final double progress;
  final IconData icon;
  final String status;
  final SensorWarningLevel level;
  final Color accent;

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
    final statusColor = accent;

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
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, color: statusColor, size: 18),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  value,
                                  style: const TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Text(
                                unit,
                                style: TextStyle(
                                  color: colors.mutedText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
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
                  SensorLevelTag(level: level, compact: true),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.mutedText,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ],
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
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
