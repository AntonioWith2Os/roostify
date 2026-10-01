part of '../../main.dart';

class RecordingsPage extends StatefulWidget {
  const RecordingsPage({
    super.key,
    required this.currentUser,
    required this.controller,
  });

  /// Recordings are scoped to this viewer: a regular user only ever sees
  /// (and can only delete) their own clips; an admin sees every user's
  /// clips, each tagged with its owner.
  final AppUser currentUser;

  /// Needed to run on-device AI detection while a recording (or a picked
  /// device video) plays back.
  final AppController controller;

  @override
  State<RecordingsPage> createState() => _RecordingsPageState();
}

/// FijkPlayer (and therefore recording/device-video playback and AI
/// detection over it) is only wired up for Android and iOS builds.
bool _supportsRecordingPlayback() {
  if (kIsWeb) {
    return false;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    _ => false,
  };
}

String _formattedRecordingDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day ${_timeLabelFor(local)}';
}

class _RecordingsPageState extends State<RecordingsPage> {
  late Future<List<RecordingFile>> _recordingsFuture;
  _RecordingFilter _filter = _RecordingFilter.today;
  Set<String> _favoritePaths = {};

  bool get _isAdmin => widget.currentUser.isAdmin;

  @override
  void initState() {
    super.initState();
    _recordingsFuture = _loadRecordings();
    unawaited(_loadFavorites());
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _favoritePaths =
          prefs.getStringList('roostify.recording_favorites')?.toSet() ?? {};
    });
  }

  Future<void> _toggleFavorite(RecordingFile recording) async {
    setState(() {
      if (!_favoritePaths.add(recording.path)) {
        _favoritePaths.remove(recording.path);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'roostify.recording_favorites',
      _favoritePaths.toList(),
    );
  }

  Future<void> _copyRecordingPath(RecordingFile recording) async {
    await Clipboard.setData(ClipboardData(text: recording.shareReference));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          recording.isServerStored
              ? 'Server recording reference copied.'
              : 'Temporary recording path copied.',
        ),
      ),
    );
  }

  List<RecordingFile> _filtered(List<RecordingFile> recordings) {
    final now = DateTime.now();
    return recordings.where((recording) {
      final date = recording.modifiedAt.toLocal();
      return switch (_filter) {
        _RecordingFilter.today =>
          date.year == now.year &&
              date.month == now.month &&
              date.day == now.day,
        _RecordingFilter.week =>
          now.difference(date).inDays >= 0 && now.difference(date).inDays < 7,
        _RecordingFilter.favorites => _favoritePaths.contains(recording.path),
        _RecordingFilter.all => true,
      };
    }).toList();
  }

  Future<List<RecordingFile>> _loadRecordings() {
    return RecordingServerService.listRecordings(viewer: widget.currentUser);
  }

  void _reload() {
    setState(() {
      _recordingsFuture = _loadRecordings();
    });
  }

  Future<void> _confirmDelete(RecordingFile recording) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recording?'),
        content: Text(
          recording.isServerStored
              ? 'This permanently removes ${recording.name} from the recording server. This cannot be undone.'
              : 'This permanently removes the pending local copy of ${recording.name}. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _appAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final deleted = await RecordingServerService.deleteRecording(
      recording: recording,
      viewer: widget.currentUser,
    );
    if (!mounted) return;
    if (deleted) {
      _reload();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete that recording.')),
      );
    }
  }

  void _openRecording(RecordingFile recording) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecordingPlayerPage(
          recording: recording,
          controller: widget.controller,
          viewer: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _browseDeviceVideo() async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open the device video picker: $error'),
        ),
      );
      return;
    }
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    int sizeBytes = 0;
    DateTime modifiedAt = DateTime.now();
    try {
      final stat = await file.stat();
      sizeBytes = stat.size;
      modifiedAt = stat.modified;
    } catch (_) {
      // Fall back to the defaults above if the file can't be stat'd.
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecordingPlayerPage(
          recording: RecordingFile(
            path: picked!.path,
            name: picked.name,
            sizeBytes: sizeBytes,
            modifiedAt: modifiedAt,
            ownerUsername: widget.currentUser.username,
          ),
          controller: widget.controller,
          viewer: widget.currentUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin ? 'All Recordings' : 'My Recordings'),
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        actions: [
          if (_supportsRecordingPlayback())
            IconButton(
              tooltip: 'Scan a video from this device',
              onPressed: _browseDeviceVideo,
              icon: const Icon(Icons.video_file_outlined),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<RecordingFile>>(
        future: _recordingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _RecordingsMessage(
              icon: Icons.error_outline,
              title: 'Could not load recordings',
              message: '${snapshot.error}',
            );
          }

          final recordings = snapshot.data ?? const [];
          if (recordings.isEmpty) {
            return const _RecordingsMessage(
              icon: Icons.video_library_outlined,
              title: 'No recordings yet',
              message:
                  'Recordings uploaded from a live CCTV feed will appear here.',
            );
          }

          final visible = _filtered(recordings);
          final usedBytes = recordings.fold<int>(
            0,
            (total, recording) => total + recording.sizeBytes,
          );
          final pendingUploads = recordings
              .where((recording) => !recording.isServerStored)
              .length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const Text(
                'Review CCTV recordings stored on the server.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              _RecordingFilterBar(
                selected: _filter,
                onSelected: (filter) => setState(() => _filter = filter),
              ),
              const SizedBox(height: 16),
              _RecordingStorageBar(
                usedBytes: usedBytes,
                pendingUploads: pendingUploads,
              ),
              const SizedBox(height: 14),
              if (visible.isEmpty)
                const _RecordingsMessage(
                  icon: Icons.video_library_outlined,
                  title: 'No recordings in this filter',
                  message: 'Try Today, This Week, or Favorites.',
                )
              else
                for (var index = 0; index < visible.length; index++) ...[
                  if (index > 0) const SizedBox(height: 9),
                  _RecordingTile(
                    recording: visible[index],
                    showOwner: _isAdmin,
                    favorite: _favoritePaths.contains(visible[index].path),
                    onTap: () => _openRecording(visible[index]),
                    onDelete: () => _confirmDelete(visible[index]),
                    onFavorite: () => _toggleFavorite(visible[index]),
                    onShare: () => _copyRecordingPath(visible[index]),
                  ),
                ],
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: () =>
                      setState(() => _filter = _RecordingFilter.all),
                  icon: const Icon(Icons.video_library_outlined),
                  label: const Text('Open Recording Library'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _RecordingFilter { today, week, favorites, all }

class _RecordingFilterBar extends StatelessWidget {
  const _RecordingFilterBar({required this.selected, required this.onSelected});
  final _RecordingFilter selected;
  final ValueChanged<_RecordingFilter> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (filter, label, icon) in const [
        (_RecordingFilter.today, 'Today', Icons.today_outlined),
        (_RecordingFilter.week, 'This Week', Icons.calendar_month_outlined),
        (_RecordingFilter.favorites, 'Favorites', Icons.star_border_rounded),
      ])
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: ChoiceChip(
              selected: selected == filter,
              onSelected: (_) => onSelected(filter),
              avatar: Icon(icon, size: 17),
              label: Text(label),
            ),
          ),
        ),
    ],
  );
}

class _RecordingStorageBar extends StatelessWidget {
  const _RecordingStorageBar({
    required this.usedBytes,
    required this.pendingUploads,
  });
  final int usedBytes;
  final int pendingUploads;

  String _storageSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.appColors.border),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(Icons.cloud_done_outlined, color: _appAccent, size: 19),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Server Storage',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(_storageSize(usedBytes), style: const TextStyle(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 7),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            pendingUploads == 0
                ? 'Uploaded recordings available across authorized accounts'
                : '$pendingUploads recording${pendingUploads == 1 ? '' : 's'} waiting to upload',
            style: TextStyle(color: context.appColors.mutedText, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class _RecordingsMessage extends StatelessWidget {
  const _RecordingsMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: colors.mutedText),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.mutedText, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingTile extends StatelessWidget {
  const _RecordingTile({
    required this.recording,
    required this.showOwner,
    required this.favorite,
    required this.onTap,
    required this.onDelete,
    required this.onFavorite,
    required this.onShare,
  });

  final RecordingFile recording;
  final bool showOwner;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onFavorite;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 84,
                height: 62,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF29364B), Color(0xFF101722)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.play_circle_fill,
                  color: _appAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recording.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formattedRecordingDate(recording.modifiedAt)} · ${recording.sizeLabel}',
                      style: TextStyle(color: colors.mutedText, fontSize: 13),
                    ),
                    if (showOwner) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentSurface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          recording.ownerUsername,
                          style: const TextStyle(
                            color: _appAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    if (!recording.isServerStored) ...[
                      const SizedBox(height: 6),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 15),
                          SizedBox(width: 4),
                          Text(
                            'Pending upload',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: favorite ? 'Remove favorite' : 'Add favorite',
                        onPressed: onFavorite,
                        icon: Icon(
                          favorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: favorite ? const Color(0xFFFFB020) : null,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Share',
                        onPressed: onShare,
                        icon: const Icon(Icons.share_outlined),
                      ),
                    ],
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFFF5A4E),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecordingPlayerPage extends StatefulWidget {
  const RecordingPlayerPage({
    super.key,
    required this.recording,
    required this.controller,
    required this.viewer,
  });

  final RecordingFile recording;

  /// Owns the on-device YOLO detector used for AI scanning this playback.
  final AppController controller;

  /// The signed-in account requesting playback; only used to attribute AI
  /// scan requests, not to restrict which file can be opened (the caller
  /// already scoped that).
  final AppUser viewer;

  @override
  State<RecordingPlayerPage> createState() => _RecordingPlayerPageState();
}

class _RecordingPlayerPageState extends State<RecordingPlayerPage> {
  FijkPlayer? _player;
  String? _errorMessage;

  Timer? _inspectionTimer;
  bool _aiScanningEnabled = false;
  bool _inspectionRunning = false;
  int _consecutiveInspectionFailures = 0;
  CctvInspectionResult _inspection = _recordingAiOffInspection();

  static const _inspectionFailureLimit = 3;

  bool get _supportsFijkPlayer => _supportsRecordingPlayback();

  @override
  void initState() {
    super.initState();
    if (_supportsFijkPlayer) {
      final player = FijkPlayer();
      _player = player;
      unawaited(_openRecording(player));
    }
  }

  Future<void> _openRecording(FijkPlayer player) async {
    try {
      final options = FijkOption()..setHostOption('enable-snapshot', 1);
      await player.applyOptions(options);
      await player.setDataSource(widget.recording.path, autoPlay: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not open this video: $error';
      });
    }
  }

  void _toggleAiScanning() {
    final enabling = !_aiScanningEnabled;
    setState(() {
      _aiScanningEnabled = enabling;
      _consecutiveInspectionFailures = 0;
      _inspection = enabling
          ? _recordingCapturingInspection()
          : _recordingAiOffInspection();
    });
    _inspectionTimer?.cancel();
    _inspectionTimer = null;
    final player = _player;
    if (enabling && player != null) {
      _scheduleNextInspection(player, delay: Duration.zero);
    }
  }

  void _scheduleNextInspection(FijkPlayer player, {Duration? delay}) {
    _inspectionTimer?.cancel();
    _inspectionTimer = Timer(delay ?? _defaultInspectionInterval(), () {
      _inspectionTimer = null;
      if (!_aiScanningEnabled || !mounted) return;
      unawaited(_captureInspectionFrame(player));
    });
  }

  Future<void> _captureInspectionFrame(FijkPlayer player) async {
    if (_inspectionRunning || !_aiScanningEnabled) return;

    _inspectionRunning = true;
    if (mounted) {
      setState(() => _inspection = _recordingCapturingInspection());
    }
    try {
      final frameBytes = await player.takeSnapShot().timeout(
        const Duration(seconds: 4),
      );
      if (!_aiScanningEnabled || !mounted) return;
      if (frameBytes.isEmpty) {
        throw StateError('The video snapshot was empty.');
      }

      if (mounted) {
        setState(() => _inspection = _recordingInspectingInspection());
      }
      final result = await widget.controller.inspectManualFrame(
        widget.viewer.username,
        frameBytes,
      );
      if (!_aiScanningEnabled || !mounted) return;

      _consecutiveInspectionFailures = 0;
      setState(() {
        _inspection = _recordingInspectionFrom(result);
      });
    } catch (error) {
      if (!mounted) return;
      _consecutiveInspectionFailures += 1;
      if (_consecutiveInspectionFailures >= _inspectionFailureLimit) {
        setState(() {
          _aiScanningEnabled = false;
          _inspection = _recordingErrorInspection(
            'AI scanning was turned off after repeated frame-capture failures.',
          );
        });
      }
    } finally {
      _inspectionRunning = false;
      if (_aiScanningEnabled && mounted) {
        _scheduleNextInspection(player);
      }
    }
  }

  @override
  void dispose() {
    _inspectionTimer?.cancel();
    final player = _player;
    if (player != null) {
      unawaited(player.release().catchError((_) {}));
    }
    super.dispose();
  }

  Widget _detectionOverlay(Rect videoRect) {
    return Positioned.fromRect(
      rect: videoRect,
      child: IgnorePointer(
        child: CustomPaint(
          painter: ChickenDetectionPainter(detections: _inspection.detections),
        ),
      ),
    );
  }

  String get _fullscreenAiStatus {
    if (!_aiScanningEnabled) {
      return _inspection.resultLabel;
    }
    if (_inspectionRunning) {
      return 'AI is checking the current frame…';
    }
    return _inspection.resultLabel;
  }

  // Draws on top of fijkplayer_plus's own default panel (play/pause, seek
  // bar, position/duration, fullscreen toggle) instead of replacing it —
  // an earlier version passed a panelBuilder that only drew AI-scan UI,
  // which silently dropped the seek bar since panelBuilder fully replaces
  // the default panel rather than extending it. This same panelBuilder
  // covers both the embedded view and the separate fullscreen route, mirroring
  // the CCTV live feed's fullscreen overlay (name tag, AI toggle, status chip).
  Widget _panelBuilder(
    FijkPlayer player,
    FijkData data,
    BuildContext context,
    Size viewSize,
    Rect texturePos,
  ) {
    // Matches how _DefaultFijkPanel itself sizes: the whole viewport in
    // fullscreen (fsFit may still letterbox the actual video inside it),
    // otherwise the exact rect the plugin rendered the video into.
    final videoRect = player.value.fullScreen
        ? Rect.fromLTWH(0, 0, viewSize.width, viewSize.height)
        : texturePos;
    final compactControls = viewSize.width < 600;

    // panelBuilder's return value is inserted as an unpositioned child of
    // fijkplayer_plus's own Stack, laid out with loose constraints. A Stack
    // whose children are all Positioned (as below) would then collapse to
    // zero size, so pin it to the real viewport first.
    return SizedBox.fromSize(
      size: viewSize,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          defaultFijkPanelBuilder(player, data, context, viewSize, texturePos),
          if (_aiScanningEnabled && _inspection.detections.isNotEmpty)
            _detectionOverlay(videoRect),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (player.value.fullScreen && !compactControls)
                    Flexible(
                      child: SeverityTag(
                        label: widget.recording.name,
                        color: _appAccent,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  _LiveFeedAiToggle(
                    enabled: _aiScanningEnabled,
                    compact: true,
                    onPressed: _toggleAiScanning,
                  ),
                ],
              ),
            ),
          ),
          if (player.value.fullScreen)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: viewSize.width * .7),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _aiScanningEnabled
                              ? Icons.auto_awesome
                              : Icons.visibility_outlined,
                          color: _aiScanningEnabled
                              ? const Color(0xFFFFCE67)
                              : Colors.white70,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _fullscreenAiStatus,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.recording.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Icon(
                  Icons.videocam_outlined,
                  color: colors.mutedText,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  '${_formattedRecordingDate(widget.recording.modifiedAt)} · ${widget.recording.sizeLabel}',
                  style: TextStyle(
                    color: colors.mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      // Video on top, detection results below — the same split-screen shape
      // as the CCTV live viewer (see _CctvViewerPage), so scanning a
      // recording feels like the same tool as watching it live.
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2B365F), Color(0xFF151B31)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    : _supportsFijkPlayer && player != null
                    ? FijkView(
                        player: player,
                        fit: FijkFit.contain,
                        fsFit: FijkFit.contain,
                        fs: true,
                        color: Colors.black,
                        panelBuilder: _panelBuilder,
                      )
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Local video playback is enabled for Android and iOS builds.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            Expanded(
              child: _RecordingDetectionPanel(
                recording: widget.recording,
                inspection: _inspection,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

CctvInspectionResult _recordingAiOffInspection() => const CctvInspectionResult(
  state: CctvInspectionState.idle,
  resultLabel: 'AI detection is off',
  confidenceLabel: '-',
  message: 'Turn on AI detection to scan this recording for roosters.',
  inspectedAtLabel: '-',
  condition: HealthState.normal,
  detected: false,
);

CctvInspectionResult _recordingCapturingInspection() =>
    const CctvInspectionResult(
      state: CctvInspectionState.capturing,
      resultLabel: 'Capturing frame',
      confidenceLabel: '-',
      message: 'A frame from this recording is being prepared for inspection.',
      inspectedAtLabel: '-',
      condition: HealthState.normal,
      detected: false,
    );

CctvInspectionResult _recordingInspectingInspection() =>
    const CctvInspectionResult(
      state: CctvInspectionState.inspecting,
      resultLabel: 'Running YOLOv8',
      confidenceLabel: '-',
      message: 'The captured frame is being inspected on this device.',
      inspectedAtLabel: '-',
      condition: HealthState.normal,
      detected: false,
    );

CctvInspectionResult _recordingErrorInspection(String message) =>
    CctvInspectionResult(
      state: CctvInspectionState.error,
      resultLabel: 'Inspection failed',
      confidenceLabel: '-',
      message: message,
      inspectedAtLabel: _timestampLabel(),
      condition: HealthState.abnormal,
      detected: false,
    );

CctvInspectionResult _recordingInspectionFrom(ManualScanResult result) {
  final detectionCount = result.detectionCount;
  final resultLabel = !result.detected
      ? 'No rooster detected'
      : (result.condition == HealthState.abnormal
            ? '$detectionCount abnormal rooster${detectionCount == 1 ? '' : 's'}'
            : '$detectionCount normal rooster${detectionCount == 1 ? '' : 's'}');
  return CctvInspectionResult(
    state: CctvInspectionState.completed,
    resultLabel: resultLabel,
    confidenceLabel: result.confidenceLabel,
    message: result.note,
    inspectedAtLabel: _timestampLabel(),
    condition: result.condition,
    detected: result.detected,
    detectionCount: detectionCount,
    detections: result.detections,
  );
}

/// The recorded-clip counterpart to the CCTV live viewer's
/// `_CctvViewerDetailsPanel`: a persistent lower panel that keeps detection
/// results and clip metadata readable without covering the video.
class _RecordingDetectionPanel extends StatelessWidget {
  const _RecordingDetectionPanel({
    required this.recording,
    required this.inspection,
  });

  final RecordingFile recording;
  final CctvInspectionResult inspection;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final detectionCount = inspection.detectionCount;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recording detection',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              SeverityTag(
                label: inspection.state.label,
                color: inspection.state.color,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CctvViewerMetric(
                  emoji: '🐔',
                  label: 'Detected',
                  value: detectionCount == null ? '—' : '$detectionCount',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CctvViewerMetric(
                  icon: Icons.auto_graph_rounded,
                  label: 'Confidence',
                  value: inspection.confidenceLabel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CctvViewerMetric(
                  icon: Icons.schedule_outlined,
                  label: 'Last checked',
                  value: inspection.inspectedAtLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: inspection.condition.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: inspection.condition.color.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  inspection.detected
                      ? Icons.health_and_safety_outlined
                      : Icons.visibility_outlined,
                  color: inspection.condition.color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inspection.resultLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        inspection.message,
                        style: TextStyle(
                          color: colors.mutedText,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (inspection.detections.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Current detections',
              style: TextStyle(
                color: colors.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final detection in inspection.detections)
                  _CctvDetectionChip(detection: detection),
              ],
            ),
          ],
          const SizedBox(height: 22),
          Text(
            'Clip details',
            style: TextStyle(
              color: colors.mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          _CctvViewerDetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Recorded',
            value: _formattedRecordingDate(recording.modifiedAt),
          ),
          const SizedBox(height: 10),
          _CctvViewerDetailRow(
            icon: Icons.sd_storage_outlined,
            label: 'Size',
            value: recording.sizeLabel,
          ),
          const SizedBox(height: 10),
          _CctvViewerDetailRow(
            icon: recording.isServerStored
                ? Icons.cloud_done_outlined
                : Icons.cloud_upload_outlined,
            label: 'Storage',
            value: recording.isServerStored
                ? 'Uploaded to server'
                : 'Pending upload',
          ),
        ],
      ),
    );
  }
}
