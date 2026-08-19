part of '../main.dart';

const _testRtspStreamUrl =
    'rtsp://chippy:prin_gles@192.168.1.1:554/live/ch00_0';
const _localYoloModelAsset = 'assets/best_float32.tflite';

/// Brand accent used across the whole UI (vivid Roostify orange).
const _appAccent = Color(0xFFFF4D16);

/// Core count cannot distinguish a budget 8-core (2 big + 6 little, e.g.
/// Helio G85) from a flagship, so cap at 2 threads: more just steals the big
/// cores from video decode and the raster thread and causes stutter.
int _defaultInterpreterThreads() {
  if (kIsWeb) {
    return 1;
  }
  return (Platform.numberOfProcessors ~/ 4).clamp(1, 2);
}

Duration _defaultInspectionInterval() {
  if (kIsWeb) {
    return const Duration(seconds: 12);
  }

  final cores = Platform.numberOfProcessors;
  if (cores <= 4) {
    return const Duration(seconds: 12);
  }
  if (cores <= 6) {
    return const Duration(seconds: 10);
  }
  return const Duration(seconds: 8);
}
