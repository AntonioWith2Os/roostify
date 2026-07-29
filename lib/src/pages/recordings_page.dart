part of '../../main.dart';

class RecordingsPage extends StatefulWidget {
  const RecordingsPage({super.key, required this.currentUser});

  /// Recordings are scoped to this viewer: a regular user only ever sees
  /// (and can only delete) their own clips; an admin sees every user's
  /// clips, each tagged with its owner.
  final AppUser currentUser;

  @override
  State<RecordingsPage> createState() => _RecordingsPageState();
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
    await Clipboard.setData(ClipboardData(text: recording.path));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recording path copied for sharing.')),
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
    return RtspRecorderService.listRecordings(
      username: _isAdmin ? null : widget.currentUser.username,
    );
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
          'This removes ${recording.name} from this device. This cannot be undone.',
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

    final deleted = await RtspRecorderService.deleteRecording(
      recording.path,
      requireOwnerUsername: _isAdmin ? null : widget.currentUser.username,
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
        builder: (_) => RecordingPlayerPage(recording: recording),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin ? 'All Recordings' : 'My Recordings'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        actions: [
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
                  'Recordings you start from a live CCTV feed will appear here.',
            );
          }

          final visible = _filtered(recordings);
          final usedBytes = recordings.fold<int>(
            0,
            (total, recording) => total + recording.sizeBytes,
          );
          const capacityBytes = 10 * 1024 * 1024 * 1024;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const Text(
                'Review saved CCTV clips and recordings.',
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
                capacityBytes: capacityBytes,
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
    required this.capacityBytes,
  });
  final int usedBytes;
  final int capacityBytes;

  String _gigabytes(int bytes) =>
      (bytes / (1024 * 1024 * 1024)).toStringAsFixed(1);

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
            const Icon(Icons.storage_rounded, color: _appAccent, size: 19),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Used Storage',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${_gigabytes(usedBytes)} GB of ${_gigabytes(capacityBytes)} GB',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 9),
        LinearProgressIndicator(
          value: (usedBytes / capacityBytes).clamp(0, 1),
          minHeight: 6,
          borderRadius: BorderRadius.circular(99),
          color: _appAccent,
          backgroundColor: context.appColors.border,
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

  String _formattedDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day ${_timeLabelFor(local)}';
  }

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
                      '${_formattedDate(recording.modifiedAt)} · ${recording.sizeLabel}',
                      style: TextStyle(color: colors.mutedText, fontSize: 12),
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
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
  const RecordingPlayerPage({super.key, required this.recording});

  final RecordingFile recording;

  @override
  State<RecordingPlayerPage> createState() => _RecordingPlayerPageState();
}

class _RecordingPlayerPageState extends State<RecordingPlayerPage> {
  FijkPlayer? _player;
  String? _errorMessage;

  bool get _supportsFijkPlayer {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

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
      await player.setDataSource(widget.recording.path, autoPlay: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not open this recording: $error';
      });
    }
  }

  @override
  void dispose() {
    final player = _player;
    if (player != null) {
      unawaited(player.release().catchError((_) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.recording.name, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: _errorMessage != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : _supportsFijkPlayer && player != null
            ? FijkView(
                player: player,
                fit: FijkFit.contain,
                color: Colors.black,
              )
            : const Padding(
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
    );
  }
}
