import 'dart:typed_data';

/// Web build of [YoloInterpreterHandle]. tflite_flutter is an FFI plugin and
/// `dart:ffi` is not available on web, so this file (selected instead of
/// yolo_interpreter_io.dart via the conditional export in
/// yolo_interpreter.dart) never imports tflite_flutter at all and simply
/// reports the feature as unsupported.
class YoloInterpreterHandle {
  YoloInterpreterHandle._();

  static Future<YoloInterpreterHandle> fromBuffer(
    Uint8List modelBytes, {
    required int threads,
  }) {
    throw UnsupportedError(
      'On-device health scanning is only available in the Roostify mobile app.',
    );
  }

  List<int> get inputShape => const [];
  List<int> get outputShape => const [];

  void run(Object input, Object output) {}

  void close() {}
}
