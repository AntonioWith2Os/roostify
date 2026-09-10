import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

/// Native (Android/iOS/desktop) TFLite interpreter handle. This file is only
/// pulled into the build via the `dart.library.io` conditional export in
/// yolo_interpreter.dart, since tflite_flutter is an FFI plugin and
/// `dart:ffi` cannot be compiled for web.
class YoloInterpreterHandle {
  YoloInterpreterHandle._(this._interpreter);

  final tfl.Interpreter _interpreter;

  static Future<YoloInterpreterHandle> fromBuffer(
    Uint8List modelBytes, {
    required int threads,
  }) async {
    // No XNNPACK delegate: a delegate failure aborts natively (uncatchable
    // from Dart) and crashed the app on the first frame of some devices.
    final options = tfl.InterpreterOptions()..threads = threads;
    final interpreter = tfl.Interpreter.fromBuffer(
      modelBytes,
      options: options,
    );
    interpreter.allocateTensors();
    return YoloInterpreterHandle._(interpreter);
  }

  List<int> get inputShape => _interpreter.getInputTensor(0).shape;
  List<int> get outputShape => _interpreter.getOutputTensor(0).shape;

  void run(Object input, Object output) => _interpreter.run(input, output);

  void close() => _interpreter.close();
}
