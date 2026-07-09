part of '../../main.dart';

class _LandingBrand extends StatelessWidget {
  const _LandingBrand();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: colors.accentSurface,
          backgroundImage: const AssetImage('assets/app_icon_square.png'),
        ),
        const SizedBox(width: 10),
        const Text(
          'Roostify',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ],
    );
  }
}

class _LandingLoginPanel extends StatelessWidget {
  const _LandingLoginPanel({required this.onUserTap, required this.onAdminTap});

  final VoidCallback onUserTap;
  final VoidCallback onAdminTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final userButton = FilledButton.icon(
            onPressed: onUserTap,
            icon: const Icon(Icons.person_outline_rounded),
            label: const Text('User Login'),
          );
          final adminButton = OutlinedButton.icon(
            onPressed: onAdminTap,
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: const Text('Admin'),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [userButton, const SizedBox(height: 10), adminButton],
            );
          }

          return Row(
            children: [
              Expanded(child: userButton),
              const SizedBox(width: 12),
              Expanded(child: adminButton),
            ],
          );
        },
      ),
    );
  }
}

class AppPill extends StatelessWidget {
  const AppPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _appAccent),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final status = controller.sensorConnectionStatus;
    final connected = status == Esp32SensorConnectionStatus.connected;
    final busy =
        status == Esp32SensorConnectionStatus.scanning ||
        status == Esp32SensorConnectionStatus.connecting;
    final error = status == Esp32SensorConnectionStatus.error;
    final reading = controller.latestSensorReading;
    final accent = connected
        ? const Color(0xFF26C281)
        : error
        ? const Color(0xFFFF6B72)
        : busy
        ? const Color(0xFFE6B452)
        : const Color(0xFF8E97B8);
    final detail = reading == null
        ? controller.sensorStatusLabel
        : '${controller.sensorStatusLabel} - updated ${_sensorTimeLabel(reading.receivedAt)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final action = connected
            ? OutlinedButton.icon(
                onPressed: controller.disconnectEsp32Sensor,
                icon: const Icon(Icons.bluetooth_disabled_outlined),
                label: const Text('Disconnect'),
              )
            : FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => controller.connectEsp32Sensor(username),
                icon: Icon(
                  busy
                      ? Icons.bluetooth_searching_outlined
                      : Icons.bluetooth_outlined,
                ),
                label: Text(busy ? 'Connecting...' : 'Connect ESP32'),
              );

        final statusContent = Row(
          children: [
            CircleAvatar(
              backgroundColor: accent.withValues(alpha: 0.14),
              foregroundColor: accent,
              child: Icon(
                connected
                    ? Icons.bluetooth_connected_outlined
                    : Icons.sensors_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ESP32 Sensor',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: TextStyle(
                      color: error ? const Color(0xFFFF8A98) : colors.mutedText,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        return _GlassCard(
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [statusContent, const SizedBox(height: 14), action],
                )
              : Row(
                  children: [
                    Expanded(child: statusContent),
                    const SizedBox(width: 14),
                    action,
                  ],
                ),
        );
      },
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
  });

  final String title;
  final String value;
  final String unit;
  final double progress;
  final IconData icon;
  final String status;
  final SensorWarningLevel level;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final ringColor = level.color;

    return Tooltip(
      message: '$title: $value $unit - $status',
      child: Semantics(
        label: '$title sensor, $value $unit, $status',
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: CustomPaint(
                  painter: _SensorRingPainter(
                    progress: progress.clamp(0.0, 1.0),
                    color: ringColor,
                    track: ringColor.withValues(alpha: 0.14),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          value,
                          maxLines: 1,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          unit,
                          style: TextStyle(
                            color: colors.mutedText,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 15, color: colors.mutedText),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.mutedText,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SensorLevelTag(level: level, compact: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.mutedText,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SensorRingPainter extends CustomPainter {
  const _SensorRingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.shortestSide * 0.105;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2 + 1);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, trackPaint);

    if (progress <= 0) {
      return;
    }
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SensorRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.track != track;
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
                                fontSize: 12,
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
            fontSize: compact ? 9 : 10,
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
