part of '../../main.dart';

/// Server-facing archive for completed CCTV recordings.
///
/// The prototype uses an on-device server emulator because this repository has
/// no deployed backend URL or credentials. Keeping this boundary separate from
/// [RtspRecorderService] mirrors the production flow: FFmpeg writes a temporary
/// local file, this service uploads it, and only then is the temporary file
/// removed. A production implementation can replace the private filesystem
/// methods with authenticated API calls without changing the recording UI or
/// its role-based access rules.
class RecordingServerService {
  RecordingServerService._();

  static const _serverDirectoryName = 'recording_server_emulator';

  /// Publishes one completed temporary recording to the server archive.
  ///
  /// The source is removed only after the archived file exists and has the
  /// same byte length, so an interrupted upload never destroys the only copy.
  static Future<RecordingFile> uploadRecording({
    required String sourcePath,
    required String ownerUsername,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException(
        'Temporary recording was not found.',
        sourcePath,
      );
    }
    final sourceLength = await source.length();
    if (sourceLength == 0) {
      throw FileSystemException('Temporary recording is empty.', sourcePath);
    }

    final owner = RtspRecorderService._sanitizeUsername(ownerUsername);
    final ownerDirectory = await _ownerDirectory(owner);
    await ownerDirectory.create(recursive: true);
    final fileName = source.uri.pathSegments.last;
    final destination = File('${ownerDirectory.path}/$fileName');

    if (source.path != destination.path) {
      if (await destination.exists()) {
        final destinationLength = await destination.length();
        if (destinationLength != sourceLength) {
          throw FileSystemException(
            'A different server recording already uses this name.',
            destination.path,
          );
        }
      } else {
        try {
          await source.rename(destination.path);
        } on FileSystemException {
          // A real server upload and a move across filesystems both require a
          // copy. Verify it below before removing the temporary source.
          try {
            await source.copy(destination.path);
          } catch (_) {
            if (await destination.exists() &&
                await destination.length() != sourceLength) {
              await destination.delete();
            }
            rethrow;
          }
        }
      }

      if (!await destination.exists() ||
          await destination.length() != sourceLength) {
        if (await destination.exists()) await destination.delete();
        throw FileSystemException(
          'Server upload could not be verified.',
          destination.path,
        );
      }
      if (await source.exists()) {
        await source.delete();
      }
    }

    final stat = await destination.stat();
    return RecordingFile(
      path: destination.path,
      name: fileName,
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
      ownerUsername: ownerUsername,
      serverId: '$owner/$fileName',
    );
  }

  /// Lists the server recordings visible to [viewer].
  ///
  /// Authorization lives here rather than in the page: admins can query every
  /// owner's archive, while regular users are always scoped to themselves.
  static Future<List<RecordingFile>> listRecordings({
    required AppUser viewer,
  }) async {
    await retryPendingUploads(viewer: viewer);
    final root = await _serverRootDirectory();
    if (!await root.exists()) return const [];

    final recordings = <RecordingFile>[];
    if (viewer.isAdmin) {
      await for (final entry in root.list()) {
        if (entry is! Directory) continue;
        final owner = entry.uri.pathSegments
            .where((segment) => segment.isNotEmpty)
            .last;
        recordings.addAll(await _collectServerRecordings(entry, owner));
      }
    } else {
      final owner = RtspRecorderService._sanitizeUsername(viewer.username);
      recordings.addAll(
        await _collectServerRecordings(await _ownerDirectory(owner), owner),
      );
      // If a real upload is offline, keep the owner's temporary clip visible
      // and playable while it waits for the next retry. Admins only see files
      // that have actually reached the server archive.
      recordings.addAll(
        await RtspRecorderService.listRecordings(username: viewer.username),
      );
    }

    recordings.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return recordings;
  }

  /// Retries temporary recordings that were retained after a failed upload.
  static Future<void> retryPendingUploads({required AppUser viewer}) async {
    final pending = await RtspRecorderService.listRecordings(
      username: viewer.isAdmin ? null : viewer.username,
    );
    for (final recording in pending) {
      try {
        await uploadRecording(
          sourcePath: recording.path,
          ownerUsername: recording.ownerUsername,
        );
      } catch (error) {
        debugPrint(
          'Recording upload remains pending for ${recording.name}: $error',
        );
      }
    }
  }

  /// Deletes a server recording if [viewer] is allowed to manage it.
  static Future<bool> deleteRecording({
    required RecordingFile recording,
    required AppUser viewer,
  }) async {
    if (!viewer.isAdmin &&
        RtspRecorderService._sanitizeUsername(recording.ownerUsername) !=
            RtspRecorderService._sanitizeUsername(viewer.username)) {
      return false;
    }

    if (!recording.isServerStored) {
      return RtspRecorderService.deleteRecording(
        recording.path,
        requireOwnerUsername: viewer.isAdmin ? null : viewer.username,
      );
    }

    final root = await _serverRootDirectory();
    final normalizedRoot = '${root.absolute.path}${Platform.pathSeparator}';
    final normalizedPath = File(recording.path).absolute.path;
    if (!normalizedPath.startsWith(normalizedRoot)) return false;

    try {
      final file = File(normalizedPath);
      if (!await file.exists()) return false;
      await file.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<RecordingFile>> _collectServerRecordings(
    Directory directory,
    String ownerUsername,
  ) async {
    if (!await directory.exists()) return const [];
    final recordings = <RecordingFile>[];
    await for (final entry in directory.list()) {
      if (entry is! File || !entry.path.toLowerCase().endsWith('.mp4')) {
        continue;
      }
      final stat = await entry.stat();
      final name = entry.uri.pathSegments.last;
      recordings.add(
        RecordingFile(
          path: entry.path,
          name: name,
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
          ownerUsername: ownerUsername,
          serverId: '$ownerUsername/$name',
        ),
      );
    }
    return recordings;
  }

  static Future<Directory> _serverRootDirectory() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/$_serverDirectoryName/recordings');
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  static Future<Directory> _ownerDirectory(String ownerUsername) async {
    final root = await _serverRootDirectory();
    return Directory('${root.path}/$ownerUsername');
  }
}
