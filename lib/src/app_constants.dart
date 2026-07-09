part of '../main.dart';

const _testRtspStreamUrl =
    'rtsp://chippy:prin_gles@192.168.1.1:554/live/ch00_0';
const _localYoloModelAsset = 'assets/best_float32.tflite';

/// Half the cores keeps TFLite from starving video decode on weak phones.
int _defaultInterpreterThreads() {
  if (kIsWeb) {
    return 1;
  }
  return (Platform.numberOfProcessors ~/ 2).clamp(1, 4);
}

Duration _defaultInspectionInterval() {
  if (kIsWeb) {
    return const Duration(seconds: 2);
  }

  final cores = Platform.numberOfProcessors;
  if (cores <= 4) {
    return const Duration(milliseconds: 2500);
  }
  if (cores <= 6) {
    return const Duration(milliseconds: 1600);
  }
  return const Duration(seconds: 1);
}
