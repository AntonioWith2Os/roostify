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

/// Whether the admin sign-in entry points (the landing page's admin button
/// and the login page's farmer/admin switcher) are shown at all. Off by
/// default so a build handed out to farmers has no way to even reach an
/// admin login screen; set `--dart-define=ADMIN_LOGIN_ENABLED=true` at
/// build/run time for a build meant to include admin access.
const _adminLoginEnabled = bool.fromEnvironment('ADMIN_LOGIN_ENABLED');

/// Whether the "V380 Cloud camera" option is offered anywhere a camera can
/// be added. Off for now - the on-device V380 protocol client/bridge code
/// stays in the repo, just not reachable from the UI, while that path's
/// reliability against real cameras is still being worked out. Flip this
/// back to true to re-expose it; nothing else needs to change.
const _v380CloudCameraAddingEnabled = false;

/// Core count cannot distinguish a budget 8-core (2 big + 6 little, e.g.
/// Helio G85) from a flagship, so cap at 2 threads: more just steals the big
/// cores from video decode and the raster thread and causes stutter.
int _defaultInterpreterThreads() {
  if (kIsWeb) {
    return 1;
  }
  return (Platform.numberOfProcessors ~/ 4).clamp(1, 2);
}

/// The rect within [viewport] where a video of [videoSize] actually renders
/// under [fit] (only [BoxFit.contain] and [BoxFit.cover] are implemented —
/// the two fits used for video playback in this app). AI detection boxes
/// are normalized to the source frame, so they must be painted against this
/// rect rather than the full viewport, or they drift whenever the video's
/// aspect ratio doesn't exactly match its container (letterboxing/pillarboxing
/// under `contain`, cropping under `cover`).
Rect _videoRectForViewport(Size viewport, Size? videoSize, BoxFit fit) {
  if (videoSize == null ||
      videoSize.isEmpty ||
      viewport.isEmpty ||
      !viewport.width.isFinite ||
      !viewport.height.isFinite) {
    return Offset.zero & viewport;
  }

  final scale = fit == BoxFit.contain
      ? math.min(
          viewport.width / videoSize.width,
          viewport.height / videoSize.height,
        )
      : math.max(
          viewport.width / videoSize.width,
          viewport.height / videoSize.height,
        );
  final renderedSize = Size(videoSize.width * scale, videoSize.height * scale);
  return Alignment.center.inscribe(renderedSize, Offset.zero & viewport);
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
