import 'package:coolapp/main.dart';
import 'package:flutter/material.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';

ChickenDetection _detectionAt(
  double left,
  double top, {
  HealthState condition = HealthState.normal,
  double size = 0.1,
}) {
  return ChickenDetection(
    box: Rect.fromLTWH(left, top, size, size),
    label: 'rooster',
    confidence: 0.9,
    condition: condition,
  );
}

void main() {
  test('assigns the same track id to a box that stays roughly in place', () {
    final tracker = RoosterTracker();

    final first = tracker.update('cam', [_detectionAt(0.1, 0.1)]);
    final second = tracker.update('cam', [_detectionAt(0.12, 0.11)]);

    expect(first.detections.single.trackId, second.detections.single.trackId);
  });

  test('assigns distinct track ids to two simultaneous detections', () {
    final tracker = RoosterTracker();

    final result = tracker.update('cam', [
      _detectionAt(0.1, 0.1),
      _detectionAt(0.7, 0.7),
    ]);

    final ids = result.detections.map((d) => d.trackId).toSet();
    expect(ids, hasLength(2));
  });

  test('matches a far-moved box via centroid fallback when IoU misses', () {
    final tracker = RoosterTracker(
      iouMatchThreshold: 0.2,
      centroidMatchThreshold: 0.4,
    );

    final first = tracker.update('cam', [_detectionAt(0.1, 0.1)]);
    // Box has moved far enough that it no longer overlaps the original one,
    // but the centroid is still close enough to count as the same bird.
    final second = tracker.update('cam', [_detectionAt(0.25, 0.1)]);

    expect(first.detections.single.trackId, second.detections.single.trackId);
  });

  test('a box that moved too far starts a new track', () {
    final tracker = RoosterTracker(
      iouMatchThreshold: 0.2,
      centroidMatchThreshold: 0.1,
    );

    final first = tracker.update('cam', [_detectionAt(0.0, 0.0)]);
    final second = tracker.update('cam', [_detectionAt(0.9, 0.9)]);

    expect(first.detections.single.trackId, isNot(second.detections.single.trackId));
  });

  test('tracks for different streams never collide', () {
    final tracker = RoosterTracker();

    final a = tracker.update('camA', [_detectionAt(0.1, 0.1)]);
    final b = tracker.update('camB', [_detectionAt(0.1, 0.1)]);

    expect(a.detections.single.trackId, b.detections.single.trackId);
    tracker.clearStream('camA');
    final aAgain = tracker.update('camA', [_detectionAt(0.1, 0.1)]);
    // Clearing one stream doesn't disturb the other stream's id sequence.
    expect(aAgain.detections.single.trackId, a.detections.single.trackId);
  });

  test('a track that times out is reported as dropped and gets a fresh id', () {
    var now = DateTime(2026, 1, 1, 12);
    final tracker = RoosterTracker(
      trackTimeout: const Duration(seconds: 30),
      clock: () => now,
    );

    final first = tracker.update('cam', [_detectionAt(0.1, 0.1)]);
    final firstId = first.detections.single.trackId;

    now = now.add(const Duration(seconds: 31));
    final second = tracker.update('cam', [_detectionAt(0.1, 0.1)]);

    expect(second.droppedTrackIds, contains(firstId));
    expect(second.detections.single.trackId, isNot(firstId));
  });

  test('identity survives a condition flip from normal to abnormal', () {
    final tracker = RoosterTracker();

    final first = tracker.update('cam', [
      _detectionAt(0.1, 0.1, condition: HealthState.normal),
    ]);
    final second = tracker.update('cam', [
      _detectionAt(0.11, 0.1, condition: HealthState.abnormal),
    ]);

    expect(first.detections.single.trackId, second.detections.single.trackId);
  });
}
