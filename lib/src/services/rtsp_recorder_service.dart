part of '../../main.dart';

/// Records an RTSP stream to an MP4 file using FFmpeg Kit.
///
/// The recorder connects independently to the RTSP stream (does not interfere
/// with the existing FijkPlayer playback) and remuxes the stream to an MP4 file
/// using `-c copy` (no re-encoding, fast and lossless).
class RtspRecorderService {
  RtspRecorderService();

  FFmpegSession? _activeSession;
  String? _activeOutputPath;
  bool _isRecording = false;
  DateTime? _recordingStartTime;

  /// Whether a recording is currently in progress.
  bool get isRecording => _isRecording;

  /// When the current recording started, or null if not recording.
  DateTime? get recordingStartTime => _recordingStartTime;

  /// The file path of the current recording, or null if not recording.
  String? get activeOutputPath => _activeOutputPath;

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
  /// failure. The [maxDuration] parameter sets a safety limit (default 30
  /// minutes).
  Future<String> startRecording(
    String rtspUrl, {
    required String username,
    Duration maxDuration = const Duration(minutes: 30),
  }) async {
    if (_isRecording) {
      throw StateError('A recording is already in progress.');
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
    // -movflags +faststart → optimize MP4 for playback
    // -y                   → overwrite output file if exists
    final command = '-rtsp_transport tcp '
        '-i "$rtspUrl" '
        '-c copy '
        '-t ${maxDuration.inSeconds} '
        '-movflags +faststart '
        '-y "$outputPath"';

    _isRecording = true;
    _recordingStartTime = DateTime.now();
    _activeOutputPath = outputPath;

    final session = await FFmpegKit.executeAsync(command);
    _activeSession = session;

    return outputPath;
  }

  /// Stop the current recording and finalize the MP4 file.
  ///
  /// Returns the output file path, or null if no recording was active.
  /// If [saveToGallery] is true, the file will also be saved to the device
  /// gallery/Photos app.
  Future<String?> stopRecording({bool saveToGallery = true}) async {
    if (!_isRecording || _activeSession == null) {
      return null;
    }

    final outputPath = _activeOutputPath;

    // Send quit signal to FFmpeg to gracefully stop recording
    // and finalize the MP4 container.
    await FFmpegKit.cancel(_activeSession!.getSessionId());

    // Wait briefly for FFmpeg to finalize the file.
    await Future<void>.delayed(const Duration(milliseconds: 800));

    _isRecording = false;
    _recordingStartTime = null;
    _activeSession = null;
    _activeOutputPath = null;

    if (outputPath == null) return null;

    final outputFile = File(outputPath);
    if (!await outputFile.exists() || await outputFile.length() == 0) {
      // Recording failed or produced empty file - clean up.
      try {
        await outputFile.delete();
      } catch (_) {}
      return null;
    }

    // Save to device gallery if requested.
    if (saveToGallery) {
      try {
        if (!await Gal.hasAccess()) {
          await Gal.requestAccess();
        }
        await Gal.putVideo(outputPath, album: 'Roostify');
      } catch (e) {
        debugPrint('Failed to save recording to gallery: $e');
        // The file is still saved in the app's recordings directory.
      }
    }

    return outputPath;
  }

  /// Cancel a recording without saving.
  Future<void> cancelRecording() async {
    if (!_isRecording || _activeSession == null) return;

    await FFmpegKit.cancel(_activeSession!.getSessionId());
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final outputPath = _activeOutputPath;
    _isRecording = false;
    _recordingStartTime = null;
    _activeSession = null;
    _activeOutputPath = null;

    if (outputPath != null) {
      try {
        final file = File(outputPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  /// Clean up resources.
  void dispose() {
    if (_isRecording) {
      cancelRecording();
    }
  }

  static Future<Directory> _recordingsRootDirectory() async {
    final directory = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    return Directory('${directory.path}/Recordings');
  }

  static Future<Directory> _userRecordingsDirectory(String username) async {
    final root = await _recordingsRootDirectory();
    return Directory('${root.path}/${_sanitizeUsername(username)}');
  }

  static String _sanitizeUsername(String username) {
    final sanitized = username
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
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
      final ownerDir =
          '/${_sanitizeUsername(requireOwnerUsername)}/';
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

/// A recorded CCTV clip saved on device storage.
class RecordingFile {
  const RecordingFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.modifiedAt,
    required this.ownerUsername,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final DateTime modifiedAt;
  final String ownerUsername;

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