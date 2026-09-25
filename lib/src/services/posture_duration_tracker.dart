part of '../../main.dart';

/// Folds a stream of per-frame [HealthState] readings for a given key (one
/// live CCTV stream, one tracked rooster, ...) into a duration-aware state.
///
/// The on-device YOLOv8 model has no memory: every frame is classified in
/// isolation, so a rooster that briefly looks down to feed reads as
/// `abnormal` on every one of those frames, the same as a rooster that is
/// actually lethargic or stuck. This tracker adds the missing temporal
/// dimension in the app layer: an `abnormal` reading is only surfaced once it
/// has persisted continuously for [sustainedAbnormalThreshold]; shorter
/// streaks are folded back to `normal`.
class PostureDurationTracker {
  PostureDurationTracker({
    this.sustainedAbnormalThreshold = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration sustainedAbnormalThreshold;
  final DateTime Function() _clock;

  final Map<String, HealthState> _streakState = {};
  final Map<String, DateTime> _streakStart = {};
  final Set<String> _alerted = {};

  /// Folds [rawCondition] into the running streak for [key] and returns the
  /// condition that should actually be surfaced: [rawCondition] unchanged,
  /// unless it is [HealthState.abnormal] and hasn't persisted long enough
  /// yet, in which case [HealthState.normal] is returned instead.
  HealthState evaluate(String key, HealthState rawCondition) {
    final now = _clock();
    if (_streakState[key] != rawCondition) {
      _streakState[key] = rawCondition;
      _streakStart[key] = now;
      if (rawCondition != HealthState.abnormal) {
        _alerted.remove(key);
      }
    }

    if (rawCondition != HealthState.abnormal) {
      return rawCondition;
    }

    final streakStart = _streakStart[key] ?? now;
    return now.difference(streakStart) >= sustainedAbnormalThreshold
        ? HealthState.abnormal
        : HealthState.normal;
  }

  /// True the first time [key]'s streak crosses into a sustained abnormal
  /// state; false on every later call for that same streak. Lets a caller
  /// fire a one-shot alert on the transition instead of once per frame.
  bool consumeSustainedAlert(String key, HealthState effectiveCondition) {
    if (effectiveCondition != HealthState.abnormal ||
        _alerted.contains(key)) {
      return false;
    }
    _alerted.add(key);
    return true;
  }

  /// How long [key]'s current abnormal streak has been running, or
  /// [Duration.zero] when [key] isn't currently in one. Useful for surfacing
  /// progress such as "looking down for 2m30s" in the UI.
  Duration elapsedAbnormal(String key) {
    if (_streakState[key] != HealthState.abnormal) {
      return Duration.zero;
    }
    final streakStart = _streakStart[key];
    return streakStart == null ? Duration.zero : _clock().difference(streakStart);
  }

  void clear(String key) {
    _streakState.remove(key);
    _streakStart.remove(key);
    _alerted.remove(key);
  }

  void clearWhere(bool Function(String key) test) {
    _streakState.removeWhere((key, _) => test(key));
    _streakStart.removeWhere((key, _) => test(key));
    _alerted.removeWhere(test);
  }
}
