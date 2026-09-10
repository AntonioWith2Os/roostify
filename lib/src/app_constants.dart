part of '../main.dart';

/// Example of the playback URL produced by the cloud video server.
///
/// This is deliberately not the V380 camera's private RTSP URL and contains
/// no camera credentials. The edge gateway owns the camera-side URL; Roostify
/// only receives the video server's delivery endpoint.
const _exampleCloudPlaybackUrl =
    'https://video.example.org/live/roostify/index.m3u8';
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
