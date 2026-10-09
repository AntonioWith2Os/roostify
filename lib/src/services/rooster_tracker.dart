part of '../../main.dart';

/// Assigns a stable identity to each detected rooster across frames of a
/// single CCTV stream, so duration-based gating (see [PostureDurationTracker])
/// can key off "this specific bird" instead of "this camera stream".
///
/// The on-device detector produces no track IDs of its own, and CCTV
/// captures on slow devices can be several seconds apart, so classic
/// near-frame-rate tracking (ByteTrack/BoT-SORT style, built around a
/// constant-velocity motion model between consecutive video frames) does not
/// apply here. Matching instead tries IoU first, then falls back to a
/// normalized centroid distance for cases where the bird moved far enough
/// between captures that its boxes no longer overlap. Tracks age out on
/// wall-clock time rather than frame count, since capture cadence varies.
class RoosterTracker {
  RoosterTracker({
    this.iouMatchThreshold = 0.2,
    this.centroidMatchThreshold = 0.35,
    this.trackTimeout = const Duration(seconds: 45),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Minimum intersection-over-union for two boxes to be considered the
  /// same bird outright.
  final double iouMatchThreshold;

  /// Maximum centroid distance - as a fraction of the frame diagonal, boxes
  /// being in normalized 0..1 coordinates - for a fallback match once boxes
  /// no longer overlap.
  final double centroidMatchThreshold;

  /// How long a track survives without a matching detection before it is
  /// dropped and its id retired.
  final Duration trackTimeout;

  final DateTime Function() _clock;

  final Map<String, List<_RoosterTrack>> _tracksByStream = {};
  final Map<String, int> _nextTrackId = {};

  /// Matches [detections] against the live tracks for [streamKey], updates
  /// or creates tracks as needed, drops tracks that timed out, and returns
  /// the resulting per-detection track ids plus any ids retired this call.
  ///
  /// Matching ignores [ChickenDetection.condition] entirely: a bird's
  /// identity must stay stable across frames regardless of whether it reads
  /// normal or abnormal, since that health flip is exactly what downstream
  /// gating needs to observe per-bird.
  RoosterTrackingUpdate update(
    String streamKey,
    List<ChickenDetection> detections,
  ) {
    final now = _clock();
    final tracks = _tracksByStream.putIfAbsent(
      streamKey,
      () => <_RoosterTrack>[],
    );

    final timedOut = tracks
        .where((track) => now.difference(track.lastSeen) > trackTimeout)
        .map((track) => track.id)
        .toList(growable: false);
    tracks.removeWhere((track) => timedOut.contains(track.id));

    // Greedy best-match-first assignment: score every (detection, track)
    // pair that clears a threshold, then repeatedly take the best remaining
    // pair. A single CCTV frame typically shows a handful of birds, so this
    // is simpler than solving an assignment problem exactly and behaves the
    // same in practice.
    final candidates = <_MatchCandidate>[];
    for (var i = 0; i < detections.length; i++) {
      for (final track in tracks) {
        final score = _matchScore(detections[i].box, track.box);
        if (score != null) {
          candidates.add(_MatchCandidate(i, track, score));
        }
      }
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));

    final matchedDetections = <int>{};
    final matchedTracks = <_RoosterTrack>{};
    final trackIdByDetection = <int, int>{};
    for (final candidate in candidates) {
      if (matchedDetections.contains(candidate.detectionIndex) ||
          matchedTracks.contains(candidate.track)) {
        continue;
      }
      matchedDetections.add(candidate.detectionIndex);
      matchedTracks.add(candidate.track);
      candidate.track
        ..box = detections[candidate.detectionIndex].box
        ..lastSeen = now;
      trackIdByDetection[candidate.detectionIndex] = candidate.track.id;
    }

    final results = <TrackedDetection>[];
    for (var i = 0; i < detections.length; i++) {
      var trackId = trackIdByDetection[i];
      if (trackId == null) {
        trackId = (_nextTrackId[streamKey] ?? 0) + 1;
        _nextTrackId[streamKey] = trackId;
        tracks.add(
          _RoosterTrack(id: trackId, box: detections[i].box, lastSeen: now),
        );
      }
      results.add(TrackedDetection(detection: detections[i], trackId: trackId));
    }

    return RoosterTrackingUpdate(
      detections: results,
      droppedTrackIds: timedOut,
    );
  }

  double? _matchScore(Rect detectionBox, Rect trackBox) {
    final iou = _trackIou(detectionBox, trackBox);
    if (iou >= iouMatchThreshold) {
      // Prefer any IoU match over any centroid-only match.
      return 1.0 + iou;
    }
    final distance = _trackCentroidDistance(detectionBox, trackBox);
    if (distance <= centroidMatchThreshold) {
      return 1.0 - distance;
    }
    return null;
  }

  /// Clears all tracks for [streamKey], e.g. when its stream stops being
  /// inspected or no rooster is detected in the latest frame.
  void clearStream(String streamKey) {
    _tracksByStream.remove(streamKey);
    _nextTrackId.remove(streamKey);
  }

  /// Clears every stream whose key matches [test], e.g. all streams for a
  /// signed-out user.
  void clearStreamsWhere(bool Function(String streamKey) test) {
    _tracksByStream.removeWhere((key, _) => test(key));
    _nextTrackId.removeWhere((key, _) => test(key));
  }
}

/// Result of one [RoosterTracker.update] call.
class RoosterTrackingUpdate {
  const RoosterTrackingUpdate({
    required this.detections,
    required this.droppedTrackIds,
  });

  /// One entry per input detection, each carrying its assigned track id.
  final List<TrackedDetection> detections;

  /// Ids of tracks that timed out and were retired this call, so callers can
  /// clear any per-track state (such as a [PostureDurationTracker] streak)
  /// keyed off those ids.
  final List<int> droppedTrackIds;
}

/// One detection from a frame, paired with the stable [trackId] it was
/// matched to by [RoosterTracker.update].
class TrackedDetection {
  const TrackedDetection({required this.detection, required this.trackId});

  final ChickenDetection detection;
  final int trackId;
}

class _RoosterTrack {
  _RoosterTrack({required this.id, required this.box, required this.lastSeen});

  final int id;
  Rect box;
  DateTime lastSeen;
}

class _MatchCandidate {
  _MatchCandidate(this.detectionIndex, this.track, this.score);

  final int detectionIndex;
  final _RoosterTrack track;
  final double score;
}

double _trackIou(Rect a, Rect b) {
  final left = math.max(a.left, b.left);
  final top = math.max(a.top, b.top);
  final right = math.min(a.right, b.right);
  final bottom = math.min(a.bottom, b.bottom);
  final width = math.max(0.0, right - left);
  final height = math.max(0.0, bottom - top);
  final intersection = width * height;
  if (intersection <= 0) {
    return 0;
  }
  final union = a.width * a.height + b.width * b.height - intersection;
  return union <= 0 ? 0 : intersection / union;
}

double _trackCentroidDistance(Rect a, Rect b) {
  final dx = a.center.dx - b.center.dx;
  final dy = a.center.dy - b.center.dy;
  return math.sqrt(dx * dx + dy * dy) / math.sqrt2;
}
