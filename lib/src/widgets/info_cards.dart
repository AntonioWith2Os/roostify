part of '../../main.dart';

class CctvInspectionResultCard extends StatelessWidget {
  const CctvInspectionResultCard({super.key, required this.result});

  final CctvInspectionResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Rooster inspection',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              SeverityTag(label: result.state.label, color: result.state.color),
            ],
          ),
          if (result.isBusy) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(color: result.state.color),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              return GridView.count(
                crossAxisCount: compact ? 2 : 4,
                childAspectRatio: compact ? 1.25 : 1.3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  SummaryMiniCard(title: 'Result', value: result.resultLabel),
                  SummaryMiniCard(
                    title: 'Confidence',
                    value: result.confidenceLabel,
                  ),
                  SummaryMiniCard(
                    title: 'Detections',
                    value: result.detectionCount?.toString() ?? '-',
                  ),
                  SummaryMiniCard(
                    title: 'Checked',
                    value: result.inspectedAtLabel,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            result.message,
            style: TextStyle(color: colors.mutedText, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class SummaryMiniCard extends StatelessWidget {
  const SummaryMiniCard({
    super.key,
    required this.title,
    required this.value,
    this.dark = false,
  });

  final String title;
  final String value;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? colors.overlayMiniCard : colors.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.mutedText),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.alert});

  final AlertItem alert;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = switch (alert.severity) {
      AlertSeverity.info => const Color(0xFF26C281),
      AlertSeverity.warning => const Color(0xFFE6B452),
      AlertSeverity.danger => const Color(0xFFFF6B72),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  alert.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SeverityTag(label: alert.category, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alert.message,
            style: TextStyle(color: colors.mutedText, height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(alert.time, style: TextStyle(color: colors.subtleText)),
        ],
      ),
    );
  }
}

class GuidelineCard extends StatelessWidget {
  const GuidelineCard({super.key, required this.item});

  final GuidelineItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: colors.accentSurface,
            foregroundColor: _appAccent,
            child: Icon(item.icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: TextStyle(color: colors.mutedText, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return _GlassCard(
      child: Column(
        children: [
          const Icon(
            Icons.mark_chat_read_outlined,
            color: _appAccent,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.mutedText, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message, required this.mine});

  final SupportMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bubbleColor = mine ? _appAccent : colors.surfaceRaised;
    final textColor = mine ? Colors.white : colors.text;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(color: textColor, height: 1.45),
            ),
            const SizedBox(height: 8),
            Text(
              message.timestamp,
              style: TextStyle(
                color: mine ? Colors.white70 : colors.subtleText,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileInfoCard extends StatelessWidget {
  const ProfileInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.accentSurface,
            foregroundColor: _appAccent,
            child: Icon(icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: colors.mutedText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ThemePreferenceCard extends StatelessWidget {
  const ThemePreferenceCard({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final colors = context.appColors;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colors.accentSurface,
                    foregroundColor: _appAccent,
                    child: const Icon(Icons.palette_outlined),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Appearance',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose how Roostify looks.',
                          style: TextStyle(color: colors.mutedText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<AppThemePreference>(
                  segments: [
                    for (final preference in AppThemePreference.values)
                      ButtonSegment<AppThemePreference>(
                        value: preference,
                        icon: Icon(preference.icon),
                        label: Text(preference.label),
                      ),
                  ],
                  selected: {controller.themePreference},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    controller.setThemePreference(selection.first);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SummaryPanel extends StatelessWidget {
  const SummaryPanel({
    super.key,
    required this.title,
    required this.value,
    required this.note,
    required this.accent,
  });

  final String title;
  final String value;
  final String note;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: colors.mutedText)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(note, style: TextStyle(color: colors.mutedText)),
        ],
      ),
    );
  }
}

class AdminUserCard extends StatelessWidget {
  const AdminUserCard({
    super.key,
    required this.user,
    required this.onCameraToggle,
    required this.onRemove,
  });

  final AppUser user;
  final VoidCallback onCameraToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Text(
            user.displayName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text('@${user.username}', style: TextStyle(color: colors.mutedText)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SummaryMiniCard(
                  title: 'Manual Camera',
                  value: user.cameraAccessEnabled ? 'Enabled' : 'Disabled',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryMiniCard(
                  title: 'CCTV Units',
                  value: '${user.cctvs.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: user.cameraAccessEnabled,
            activeThumbColor: const Color(0xFF26C281),
            activeTrackColor: const Color(0xFF1F5A46),
            title: const Text('Allow phone camera detection'),
            subtitle: const Text(
              'Disable this and the user can no longer use manual camera monitoring.',
            ),
            onChanged: (_) => onCameraToggle(),
          ),
        ],
      ),
    );
  }
}

class AdminCctvCard extends StatelessWidget {
  const AdminCctvCard({super.key, required this.user, required this.feed});

  final AppUser user;
  final CctvFeed feed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${feed.name} • ${feed.location}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SeverityTag(label: feed.status.label, color: feed.status.color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'User: ${user.displayName}',
            style: TextStyle(color: colors.mutedText),
          ),
          const SizedBox(height: 12),
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.mediaGradientStart, colors.mediaGradientEnd],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SeverityTag(
                  label: feed.online ? 'Online' : 'Offline',
                  color: feed.online
                      ? const Color(0xFF26C281)
                      : const Color(0xFFFF6B72),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            feed.note,
            style: TextStyle(color: colors.mutedText, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class SupportPreviewCard extends StatelessWidget {
  const SupportPreviewCard({super.key, required this.thread});

  final SupportThread thread;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final latest = thread.messages.isEmpty ? null : thread.messages.last;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  thread.username,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SeverityTag(
                label: thread.resolved ? 'Resolved' : 'Open',
                color: thread.resolved
                    ? const Color(0xFF26C281)
                    : const Color(0xFFFF6B72),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            latest?.text ?? 'No messages yet.',
            style: TextStyle(color: colors.mutedText, height: 1.5),
          ),
          if (latest != null) ...[
            const SizedBox(height: 8),
            Text(latest.timestamp, style: TextStyle(color: colors.subtleText)),
          ],
        ],
      ),
    );
  }
}

class ManualScanResultCard extends StatelessWidget {
  const ManualScanResultCard({super.key, required this.result});

  final ManualScanResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'AI scan result',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              SeverityTag(
                label: result.condition.label,
                color: result.condition.color,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SummaryMiniCard(title: 'Breed', value: result.breed),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryMiniCard(
                  title: 'Movement',
                  value: result.movement,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SummaryMiniCard(
                  title: 'Detections',
                  value: '${result.detectionCount}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryMiniCard(
                  title: 'Confidence',
                  value: result.confidenceLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            result.note,
            style: TextStyle(color: colors.mutedText, height: 1.5),
          ),
        ],
      ),
    );
  }
}
