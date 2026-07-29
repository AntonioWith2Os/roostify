part of '../../main.dart';

class CctvInspectionResultCard extends StatelessWidget {
  const CctvInspectionResultCard({
    super.key,
    required this.result,
    this.title = 'Rooster inspection',
  });

  final CctvInspectionResult result;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
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

class ThemePreferenceCard extends StatefulWidget {
  const ThemePreferenceCard({
    super.key,
    required this.controller,
    required this.username,
  });

  final AppController controller;

  /// Whose Recordings folder to measure/clear for the Clear Cache row.
  final String username;

  @override
  State<ThemePreferenceCard> createState() => _ThemePreferenceCardState();
}

class _ThemePreferenceCardState extends State<ThemePreferenceCard> {
  static final _languageNames = {
    const Locale('en'): 'English',
    const Locale('fil'): 'Filipino',
  };

  bool _autoPlayPreview = true;
  bool _dataSaver = false;
  int? _cacheBytes;
  bool _clearingCache = false;
  PermissionStatus? _cameraPermissionStatus;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
    unawaited(_refreshCacheSize());
    unawaited(_refreshCameraPermissionStatus());
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoPlayPreview = prefs.getBool('roostify.app.autoplay') ?? true;
      _dataSaver = prefs.getBool('roostify.app.data_saver') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('roostify.app.autoplay', _autoPlayPreview);
    await prefs.setBool('roostify.app.data_saver', _dataSaver);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _refreshCacheSize() async {
    try {
      final recordings = await RtspRecorderService.listRecordings(
        username: widget.username,
      );
      final totalBytes = recordings.fold<int>(
        0,
        (sum, recording) => sum + recording.sizeBytes,
      );
      if (!mounted) return;
      setState(() => _cacheBytes = totalBytes);
    } catch (_) {
      // Recording storage isn't available on this platform (e.g. desktop/
      // web builds); treat the cache as empty rather than crashing.
      if (mounted) setState(() => _cacheBytes = 0);
    }
  }

  Future<void> _clearCache() async {
    setState(() => _clearingCache = true);
    try {
      final recordings = await RtspRecorderService.listRecordings(
        username: widget.username,
      );
      for (final recording in recordings) {
        final file = File(recording.path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      if (!mounted) return;
      setState(() {
        _cacheBytes = 0;
        _clearingCache = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            recordings.isEmpty
                ? 'Cache was already empty.'
                : 'Deleted ${recordings.length} saved recording${recordings.length == 1 ? '' : 's'} and freed up space.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _clearingCache = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not clear cache: $error')),
      );
    }
  }

  Future<void> _refreshCameraPermissionStatus() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    setState(() => _cameraPermissionStatus = status);
  }

  Future<void> _manageCameraPermission() async {
    final current = await Permission.camera.status;
    if (current.isGranted) {
      final opened = await openAppSettings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'Camera access is already granted. Opened device settings to manage it.'
                : 'Camera access is already granted.',
          ),
        ),
      );
      await _refreshCameraPermissionStatus();
      return;
    }

    final result = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _cameraPermissionStatus = result);

    if (result.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera access granted.')),
      );
    } else if (result.isPermanentlyDenied) {
      final opened = await openAppSettings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'Camera access is blocked. Enable it in device settings.'
                : 'Camera access is blocked. Enable it in your device settings.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera access denied.')),
      );
    }
  }

  String _cameraPermissionLabel() {
    switch (_cameraPermissionStatus) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return 'Granted — tap to open device settings';
      case PermissionStatus.permanentlyDenied:
        return 'Blocked — tap to open device settings';
      case PermissionStatus.denied:
        return 'Not granted — tap to allow';
      case PermissionStatus.restricted:
        return 'Restricted by the device';
      case PermissionStatus.provisional:
        return 'Granted — tap to open device settings';
      case null:
        return 'Checking permission...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final colors = context.appColors;
        final currentLanguage =
            _languageNames[widget.controller.languageLocale] ?? 'English';
        return SingleChildScrollView(
          child: Container(
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
                          Text(
                            l10n.settingsTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.settingsSubtitle,
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
                    selected: {widget.controller.themePreference},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      widget.controller.setThemePreference(selection.first);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsActionRow(
                  icon: Icons.language_rounded,
                  title: l10n.settingsLanguage,
                  subtitle: currentLanguage,
                  onTap: () async {
                    final value = await showDialog<String>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: Text(l10n.settingsLanguage),
                        children: [
                          for (final language in _languageNames.values)
                            SimpleDialogOption(
                              onPressed: () =>
                                  Navigator.of(context).pop(language),
                              child: Text(language),
                            ),
                        ],
                      ),
                    );
                    if (value != null) widget.controller.setLanguage(value);
                  },
                ),
                _SettingsActionRow(
                  icon: Icons.play_circle_outline_rounded,
                  title: l10n.settingsAutoPlayTitle,
                  subtitle: l10n.settingsAutoPlaySubtitle,
                  trailing: Switch(
                    value: _autoPlayPreview,
                    onChanged: (value) =>
                        setState(() => _autoPlayPreview = value),
                  ),
                ),
                _SettingsActionRow(
                  icon: Icons.energy_savings_leaf_outlined,
                  title: l10n.settingsDataSaverTitle,
                  subtitle: l10n.settingsDataSaverSubtitle,
                  trailing: Switch(
                    value: _dataSaver,
                    onChanged: (value) => setState(() => _dataSaver = value),
                  ),
                ),
                _SettingsActionRow(
                  icon: Icons.shield_outlined,
                  title: l10n.settingsCameraPermTitle,
                  subtitle: _cameraPermissionLabel(),
                  onTap: _manageCameraPermission,
                ),
                _SettingsActionRow(
                  icon: Icons.delete_outline_rounded,
                  title: l10n.settingsClearCacheTitle,
                  subtitle: _clearingCache
                      ? 'Clearing...'
                      : _cacheBytes == null
                      ? 'Calculating...'
                      : _cacheBytes == 0
                      ? l10n.settingsCacheEmpty
                      : l10n.settingsCacheSize(
                          (_cacheBytes! / (1024 * 1024)).round().toString(),
                        ),
                  onTap: _clearingCache ? null : _clearCache,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saveSettings,
                    child: Text(l10n.settingsSaveButton),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(l10n.settingsCancelButton),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.appColors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _appAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.appColors.mutedText,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
          if (trailing == null)
            const Icon(Icons.chevron_right_rounded, size: 19),
        ],
      ),
    ),
  );
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
