import 'package:coolapp/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts the current channels-first YOLO model input', () {
    final layout = OnDeviceYoloDetector.debugInputLayout([1, 3, 640, 640]);

    expect(layout.width, 640);
    expect(layout.height, 640);
    expect(layout.channelsFirst, isTrue);
  });

  test('keeps supporting channels-last YOLO model inputs', () {
    final layout = OnDeviceYoloDetector.debugInputLayout([1, 640, 640, 3]);

    expect(layout.width, 640);
    expect(layout.height, 640);
    expect(layout.channelsFirst, isFalse);
  });

  test('rejects input tensors without three RGB channels', () {
    expect(
      () => OnDeviceYoloDetector.debugInputLayout([1, 640, 640, 1]),
      throwsFormatException,
    );
  });
}
