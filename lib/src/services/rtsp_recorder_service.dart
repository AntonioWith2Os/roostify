part of '../../main.dart';

/// Records an RTSP stream to an MP4 file using FFmpeg Kit.
///
/// The recorder connects independently to the RTSP stream (does not interfere
/// with the existing FijkPlayer playback) and remuxes the stream to an MP4 file
/// using `-c copy` (no re-encoding, fast and lossless).
class RtspRecorderService {
  RtspRecorderService();

  /// A single CCTV recording can run for at most one day.
  static const Duration maximumRecordingDuration = Duration(hours: 24);

  FFmpegSession? _activeSession;
  String? _activeOutputPath;
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Completer<String?>? _recordingCompleter;
  Future<String?>? _recordingCompletion;
  Future<String?>? _finalizationFuture;
  bool _saveToGalleryWhenFinished = false;
  bool _discardWhenFinished = false;

  static Future<void>? _legacyStorageMigration;

  /// Whether a recording is currently in progress.
  bool get isRecording => _isRecording;

  /// When the current recording started, or null if not recording.
  DateTime? get recordingStartTime => _recordingStartTime;

  /// The file path of the current recording, or null if not recording.
  String? get activeOutputPath => _activeOutputPath;

  /// Completes with the saved internal-storage path when FFmpeg finishes.
  ///
  /// This also completes when the 24-hour limit is reached without the user
  /// pressing Stop, allowing the UI to leave the recording state correctly.
  Future<String?>? get recordingCompletion => _recordingCompletion;

  /// How long the current recording has been running.
  Duration get recordingDuration {
    if (_recordingStartTime == null) return Duration.zero;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Start recording the given RTSP stream URL to a local MP4 file.
  ///
  /// The recording is saved under a per-[username] folder so only that user
  /// (and the admin, who can browse every folder) can see it in the
  /// Recordings list. Returns the output file path on success, or throws on
  /// failure. [maxDuration] defaults to, and cannot exceed, 24 hours.
  Future<String> startRecording(
    String rtspUrl, {
    required String username,
    Duration maxDuration = maximumRecordingDuration,
    bool saveToGalleryWhenFinished = false,
  }) async {
    if (_isRecording) {
      throw StateError('A recording is already in progress.');
    }
    if (maxDuration <= Duration.zero ||
        maxDuration > maximumRecordingDuration) {
      throw ArgumentError.value(
        maxDuration,
        'maxDuration',
        'Must be greater than zero and no longer than 24 hours.',
      );
    }

    final recordingsDir = await _userRecordingsDirectory(username);
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final outputPath = '${recordingsDir.path}/roostify_$timestamp.mp4';

    // FFmpeg command:
    // -rtsp_transport tcp  → use TCP for RTSP (matches fijkplayer default)
    // -i <url>             → input RTSP stream
    // -c copy              → copy streams without re-encoding (fast, lossless)
    // -t <seconds>         → max recording duration (safety limit)
    // fragmented MP4      → keeps a day-long file recoverable if interrupted
    // -y                   → overwrite output file if it somehow exists
    // Arguments are passed as a list so quotes or spaces in camera credentials
    // cannot alter the FFmpeg command.
    final arguments = <String>[
      '-rtsp_transport',
      'tcp',
      '-i',
      rtspUrl,
      '-c',
      'copy',
      '-t',
      maxDuration.inSeconds.toString(),
      '-movflags',
      '+frag_keyframe+empty_moov+default_base_moof',
      '-y',
      outputPath,
    ];

    _isRecording = true;
    _recordingStartTime = DateTime.now();
    _activeOutputPath = outputPath;
    _saveToGalleryWhenFinished = saveToGalleryWhenFinished;
    _discardWhenFinished = false;
    _recordingCompleter = Completer<String?>();
    _recordingCompletion = _recordingCompleter!.future;
    _finalizationFuture = null;

    try {
      final session = await FFmpegKit.executeWithArgumentsAsync(arguments, (
        completedSession,
      ) {
        _finalizationFuture ??= _finalizeRecording(completedSession);
      });
      // A bad URL can finish before executeWithArgumentsAsync returns. Do not
      // restore a completed session in that race.
      if (_isRecording) {
        _activeSession = session;
      }
    } catch (_) {
      _resetActiveRecording();
      final completer = _recordingCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete(null);
      }
      rethrow;
    }

    return outputPath;
  }

  /// Stop the current recording and finalize the MP4 file.
  ///
  /// Returns the output file path, or null if no recording was active.
  /// If [saveToGallery] is true, a second copy is also saved to the device
  /// gallery/Photos app. The master file always remains in internal app
  /// storage.
  Future<String?> stopRecording({bool saveToGallery = false}) async {
    if (!_isRecording || _activeSession == null) {
      return null;
    }

    final session = _activeSession!;
    final completion = _recordingCompleter!;
    _saveToGalleryWhenFinished = saveToGallery;

    // Cancellation asks native FFmpeg to close the stream and write the MP4
    // trailer. Its completion callback is the authoritative signal that the
    // file is ready; an arbitrary delay can expose a half-written MP4.
    await FFmpegKit.cancel(session.getSessionId());
    try {
      return await completion.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      // Defensive fallback for devices that fail to deliver the native
      // callback after cancellation.
      _finalizationFuture ??= _finalizeRecording(session);
      return _finalizationFuture!;
    }
  }

  /// Cancel a recording without saving.
  Future<void> cancelRecording() async {
    if (!_isRecording || _activeSession == null) return;

    final session = _activeSession!;
    final completion = _recordingCompleter!;
    _discardWhenFinished = true;
    await FFmpegKit.cancel(session.getSessionId());
    try {
      await completion.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      _finalizationFuture ??= _finalizeRecording(session);
      await _finalizationFuture;
    }
  }

  /// Stops and preserves an active clip when the owner is disposed.
  void dispose() {
    if (_isRecording) {
      unawaited(stopRecording());
    }
  }

  Future<String?> _finalizeRecording(FFmpegSession session) async {
    if (_activeSession != null &&
        session.getSessionId() != _activeSession!.getSessionId()) {
      return null;
    }

    final outputPath = _activeOutputPath;
    final saveToGallery = _saveToGalleryWhenFinished;
    final discard = _discardWhenFinished;
    final completer = _recordingCompleter;
    _resetActiveRecording();

    String? savedPath;
    if (outputPath != null) {
      final outputFile = File(outputPath);
      if (discard) {
        try {
          if (await outputFile.exists()) {
            await outputFile.delete();
          }
        } catch (_) {}
      } else if (await outputFile.exists() && await outputFile.length() > 0) {
        savedPath = outputPath;
      } else {
        try {
          if (await outputFile.exists()) {
            await outputFile.delete();
          }
        } catch (_) {}
      }
    }

    if (savedPath != null && saveToGallery) {
      try {
        if (!await Gal.hasAccess()) {
          await Gal.requestAccess();
        }
        await Gal.putVideo(savedPath, album: 'Roostify');
      } catch (error) {
        debugPrint('Failed to copy recording to gallery: $error');
        // The master file remains available in internal app storage.
      }
    }

    if (completer != null && !completer.isCompleted) {
      completer.complete(savedPath);
    }
    return savedPath;
  }

  void _resetActiveRecording() {
    _isRecording = false;
    _recordingStartTime = null;
    _activeSession = null;
    _activeOutputPath = null;
  }

  static Future<Directory> _recordingsRootDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final root = Directory('${directory.path}/Recordings');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    // Releases before this change used Android's app-specific external-files
    // directory. Move those clips once so switching to internal storage does
    // not make a user's existing recordings disappear.
    _legacyStorageMigration ??= _migrateLegacyRecordings(root);
    await _legacyStorageMigration;
    return root;
  }

  static Future<void> _migrateLegacyRecordings(Directory internalRoot) async {
    try {
      final external = await getExternalStorageDirectory();
      if (external == null) return;
      final legacyRoot = Directory('${external.path}/Recordings');
      if (legacyRoot.path == internalRoot.path || !await legacyRoot.exists()) {
        return;
      }

      await for (final ownerEntry in legacyRoot.list()) {
        if (ownerEntry is! Directory) continue;
        final owner = ownerEntry.uri.pathSegments
            .where((segment) => segment.isNotEmpty)
            .last;
        final targetOwner = Directory('${internalRoot.path}/$owner');
        await targetOwner.create(recursive: true);
        await for (final entry in ownerEntry.list()) {
          if (entry is! File || !entry.path.toLowerCase().endsWith('.mp4')) {
            continue;
          }
          final destination = File(
            '${targetOwner.path}/${entry.uri.pathSegments.last}',
          );
          if (await destination.exists()) continue;
          await entry.copy(destination.path);
          await entry.delete();
        }
      }
    } catch (error) {
      // Migration is best-effort. New recordings must not be blocked because
      // an old external directory is unavailable or read-only.
      debugPrint('Could not migrate legacy CCTV recordings: $error');
    }
  }

  static Future<Directory> _userRecordingsDirectory(String username) async {
    final root = await _recordingsRootDirectory();
    return Directory('${root.path}/${_sanitizeUsername(username)}');
  }

  static String _sanitizeUsername(String username) {
    final sanitized = username.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9._-]'),
      '_',
    );
    return sanitized.isEmpty ? 'unknown' : sanitized;
  }

  static Future<List<RecordingFile>> _collectRecordings(
    Directory directory,
    String ownerUsername,
  ) async {
    if (!await directory.exists()) {
      return const [];
    }

    final files = <RecordingFile>[];
    await for (final entry in directory.list()) {
      if (entry is! File || !entry.path.toLowerCase().endsWith('.mp4')) {
        continue;
      }
      final stat = await entry.stat();
      files.add(
        RecordingFile(
          path: entry.path,
          name: entry.uri.pathSegments.last,
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
          ownerUsername: ownerUsername,
        ),
      );
    }
    return files;
  }

  /// Lists saved recordings, most recent first.
  ///
  /// Pass [username] to see only that user's recordings. Omit it to list
  /// recordings from every user's folder — intended for admin use only, the
  /// caller must enforce that restriction before calling with no username.
  static Future<List<RecordingFile>> listRecordings({String? username}) async {
    final rootDir = await _recordingsRootDirectory();
    if (!await rootDir.exists()) {
      return const [];
    }

    final files = <RecordingFile>[];
    if (username != null) {
      files.addAll(
        await _collectRecordings(
          await _userRecordingsDirectory(username),
          username,
        ),
      );
    } else {
      await for (final entry in rootDir.list()) {
        if (entry is! Directory) continue;
        final owner = entry.uri.pathSegments
            .where((segment) => segment.isNotEmpty)
            .last;
        files.addAll(await _collectRecordings(entry, owner));
      }
    }

    files.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return files;
  }

  /// Deletes a saved recording by its file path. Returns true on success.
  ///
  /// If [requireOwnerUsername] is set, the path must live inside that user's
  /// recordings folder or the delete is refused — a defense-in-depth check
  /// so a non-admin caller can never delete another user's clip even if the
  /// UI layer's filtering is bypassed.
  static Future<bool> deleteRecording(
    String path, {
    String? requireOwnerUsername,
  }) async {
    if (requireOwnerUsername != null) {
      final ownerDir = '/${_sanitizeUsername(requireOwnerUsername)}/';
      if (!path.replaceAll('\\', '/').contains(ownerDir)) {
        return false;
      }
    }

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }
}

/// A recorded CCTV clip stored locally or published to the recording server.
class RecordingFile {
  const RecordingFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.modifiedAt,
    required this.ownerUsername,
    this.serverId,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final DateTime modifiedAt;
  final String ownerUsername;
  final String? serverId;

  bool get isServerStored => serverId != null;

  String get shareReference => serverId == null
      ? path
      : 'server://recordings/${Uri.encodeFull(serverId!)}';

  String get sizeLabel {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (sizeBytes >= 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$sizeBytes B';
  }
}
