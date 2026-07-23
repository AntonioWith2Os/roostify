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

  bool get _isAdmin => widget.currentUser.isAdmin;

  @override
  void initState() {
    super.initState();
    _recordingsFuture = _loadRecordings();
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

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: recordings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final recording = recordings[index];
              return _RecordingTile(
                recording: recording,
                showOwner: _isAdmin,
                onTap: () => _openRecording(recording),
                onDelete: () => _confirmDelete(recording),
              );
            },
          );
        },
      ),
    );
  }
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
    required this.onTap,
    required this.onDelete,
  });

  final RecordingFile recording;
  final bool showOwner;
  final VoidCallback onTap;
  final VoidCallback onDelete;

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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.accentSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.play_circle_fill,
                  color: _appAccent,
                  size: 30,
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
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
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
            ? FijkView(player: player, fit: FijkFit.contain, color: Colors.black)
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
