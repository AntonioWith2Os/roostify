part of '../../main.dart';

class OnDeviceYoloDetector {
  static const double _confidenceThreshold = 0.58;
  static const double _abnormalConfidenceThreshold = 0.48;
  static const double _abnormalPriorityRatio = 0.90;
  static const double _sameRoosterIouThreshold = 0.35;
  static const double _minimumBoxArea = 0.006;
  static const double _maximumBoxArea = 0.88;
  static const double _minimumBoxAspectRatio = 0.18;
  static const double _maximumBoxAspectRatio = 3.8;
  static const int _maxDetections = 20;
  static const double _byteToFloat = 1 / 255;
  static const double _letterboxValue = 114 * _byteToFloat;
  static const List<String> _labels = ['Normal Chicken', 'Abnormal Chicken'];
  static const List<String> _displayLabels = [
    'Normal Rooster',
    'Abnormal Rooster',
  ];
  static const List<HealthState> _labelConditions = [
    HealthState.normal,
    HealthState.abnormal,
  ];

  tfl.Interpreter? _interpreter;
  Future<tfl.Interpreter>? _loadingInterpreter;
  _YoloModelMetadata? _modelMetadata;
  Float32List? _inputBuffer;
  Float32List? _outputBuffer;

  Future<CctvInspectionResult> inspectFrame(Uint8List frameBytes) async {
    final decodedFrame = img.decodeImage(frameBytes);
    if (decodedFrame == null) {
      throw const FormatException('The captured frame could not be decoded.');
    }

    return _inspectImage(img.bakeOrientation(decodedFrame));
  }

  Future<CctvInspectionResult> inspectCameraFrame(LiveCameraFrame frame) async {
    return _inspectImage(_imageFromCameraFrame(frame));
  }

  Future<CctvInspectionResult> _inspectImage(img.Image frame) async {
    final interpreter = await _interpreterForInference();
    final metadata = _metadataForInterpreter(interpreter);
    final preprocessed = _preprocessFrame(frame, metadata: metadata);

    final outputValues = _outputBufferForSize(metadata.outputElementCount);
    interpreter.run(preprocessed.input.buffer, outputValues.buffer);
    final detections = _parseDetections(outputValues, metadata, preprocessed);

    return CctvInspectionResult.fromDetections(detections);
  }

  img.Image _imageFromCameraFrame(LiveCameraFrame frame) {
    final image = switch (frame.formatGroup) {
      ImageFormatGroup.bgra8888 => _bgra8888ToImage(frame),
      ImageFormatGroup.yuv420 => _yuv420ToImage(frame),
      ImageFormatGroup.jpeg => _jpegCameraFrameToImage(frame),
      ImageFormatGroup.nv21 => _nv21ToImage(frame),
      ImageFormatGroup.unknown => throw FormatException(
        'Unsupported live camera image format: ${frame.formatGroup.name}',
      ),
    };

    final rotation = frame.rotationDegrees % 360;
    if (rotation == 0) {
      return image;
    }

    return img.copyRotate(image, angle: rotation);
  }

  img.Image _jpegCameraFrameToImage(LiveCameraFrame frame) {
    if (frame.planes.isEmpty) {
      throw const FormatException('The camera JPEG frame has no image data.');
    }

    final decoded = img.decodeImage(frame.planes.first.bytes);
    if (decoded == null) {
      throw const FormatException(
        'The camera JPEG frame could not be decoded.',
      );
    }
    return img.bakeOrientation(decoded);
  }

  img.Image _bgra8888ToImage(LiveCameraFrame frame) {
    if (frame.planes.isEmpty) {
      throw const FormatException('The BGRA camera frame has no image data.');
    }

    final plane = frame.planes.first;
    final image = img.Image(width: frame.width, height: frame.height);
    for (var y = 0; y < frame.height; y += 1) {
      final rowOffset = y * plane.bytesPerRow;
      for (var x = 0; x < frame.width; x += 1) {
        final index = rowOffset + x * 4;
        if (index + 2 >= plane.bytes.length) {
          continue;
        }
        image.setPixelRgb(
          x,
          y,
          plane.bytes[index + 2],
          plane.bytes[index + 1],
          plane.bytes[index],
        );
      }
    }
    return image;
  }

  img.Image _yuv420ToImage(LiveCameraFrame frame) {
    if (frame.planes.length < 3) {
      throw const FormatException('The YUV camera frame is missing planes.');
    }

    final yPlane = frame.planes[0];
    final uPlane = frame.planes[1];
    final vPlane = frame.planes[2];
    final image = img.Image(width: frame.width, height: frame.height);
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (var y = 0; y < frame.height; y += 1) {
      final yRowOffset = y * yPlane.bytesPerRow;
      final uvRow = y >> 1;
      for (var x = 0; x < frame.width; x += 1) {
        final yIndex = yRowOffset + x;
        final uvX = x >> 1;
        final uIndex = uvRow * uPlane.bytesPerRow + uvX * uPixelStride;
        final vIndex = uvRow * vPlane.bytesPerRow + uvX * vPixelStride;
        if (yIndex >= yPlane.bytes.length ||
            uIndex >= uPlane.bytes.length ||
            vIndex >= vPlane.bytes.length) {
          continue;
        }

        _setYuvPixel(
          image,
          x,
          y,
          yPlane.bytes[yIndex],
          uPlane.bytes[uIndex],
          vPlane.bytes[vIndex],
        );
      }
    }

    return image;
  }

  img.Image _nv21ToImage(LiveCameraFrame frame) {
    if (frame.planes.isEmpty) {
      throw const FormatException('The NV21 camera frame has no image data.');
    }

    final bytes = frame.planes.first.bytes;
    final image = img.Image(width: frame.width, height: frame.height);
    final frameSize = frame.width * frame.height;
    for (var y = 0; y < frame.height; y += 1) {
      for (var x = 0; x < frame.width; x += 1) {
        final yIndex = y * frame.width + x;
        final uvIndex = frameSize + (y >> 1) * frame.width + (x & ~1);
        if (yIndex >= bytes.length || uvIndex + 1 >= bytes.length) {
          continue;
        }

        _setYuvPixel(
          image,
          x,
          y,
          bytes[yIndex],
          bytes[uvIndex + 1],
          bytes[uvIndex],
        );
      }
    }
    return image;
  }

  void _setYuvPixel(
    img.Image image,
    int x,
    int y,
    int yValue,
    int uValue,
    int vValue,
  ) {
    final uOffset = uValue - 128;
    final vOffset = vValue - 128;
    image.setPixelRgb(
      x,
      y,
      _rgbByte(yValue + ((1436 * vOffset) >> 10)),
      _rgbByte(yValue - ((352 * uOffset + 731 * vOffset) >> 10)),
      _rgbByte(yValue + ((1815 * uOffset) >> 10)),
    );
  }

  int _rgbByte(int value) {
    if (value <= 0) {
      return 0;
    }
    if (value >= 255) {
      return 255;
    }
    return value;
  }

  int _elementCount(List<int> shape) {
    return shape.fold(1, (product, dimension) => product * dimension);
  }

  Future<tfl.Interpreter> _interpreterForInference() async {
    final existing = _interpreter;
    if (existing != null) {
      return existing;
    }

    final loading = _loadingInterpreter;
    if (loading != null) {
      return loading;
    }

    final future = _loadInterpreter();
    _loadingInterpreter = future;
    try {
      final interpreter = await future;
      _interpreter = interpreter;
      return interpreter;
    } finally {
      _loadingInterpreter = null;
    }
  }

  _YoloModelMetadata _metadataForInterpreter(tfl.Interpreter interpreter) {
    final existing = _modelMetadata;
    if (existing != null) {
      return existing;
    }

    final inputShape = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;
    final metadata = _YoloModelMetadata(
      inputWidth: _inputWidth(inputShape),
      inputHeight: _inputHeight(inputShape),
      outputElementCount: _elementCount(outputShape),
      outputLayout: _YoloTensorLayout.fromShape(outputShape),
    );
    _modelMetadata = metadata;
    return metadata;
  }

  Future<tfl.Interpreter> _loadInterpreter() async {
    final options = tfl.InterpreterOptions()..threads = 2;
    final interpreter = await tfl.Interpreter.fromAsset(
      _localYoloModelAsset,
      options: options,
    );
    interpreter.allocateTensors();
    return interpreter;
  }

  int _inputHeight(List<int> shape) {
    if (shape.length == 4 && shape[3] == 3) {
      return shape[1];
    }
    throw FormatException('Expected NHWC RGB input tensor, got $shape.');
  }

  int _inputWidth(List<int> shape) {
    if (shape.length == 4 && shape[3] == 3) {
      return shape[2];
    }
    throw FormatException('Expected NHWC RGB input tensor, got $shape.');
  }

  _YoloPreprocessedFrame _preprocessFrame(
    img.Image frame, {
    required _YoloModelMetadata metadata,
  }) {
    final inputWidth = metadata.inputWidth;
    final inputHeight = metadata.inputHeight;
    final scale = math.min(
      inputWidth / frame.width,
      inputHeight / frame.height,
    );
    final resizedWidth = math.max(1, (frame.width * scale).round());
    final resizedHeight = math.max(1, (frame.height * scale).round());
    final padX = ((inputWidth - resizedWidth) / 2).round();
    final padY = ((inputHeight - resizedHeight) / 2).round();

    final resized = img.copyResize(
      frame,
      width: resizedWidth,
      height: resizedHeight,
      interpolation: img.Interpolation.linear,
    );

    final input = _inputBufferForSize(inputWidth * inputHeight * 3);
    input.fillRange(0, input.length, _letterboxValue);

    final resizedBytes = resized.getBytes(order: img.ChannelOrder.rgb);
    final resizedRowStride = resizedWidth * 3;
    for (var y = 0; y < resizedHeight; y += 1) {
      var inputOffset = ((padY + y) * inputWidth + padX) * 3;
      var resizedOffset = y * resizedRowStride;
      for (var x = 0; x < resizedWidth; x += 1) {
        input[inputOffset++] = resizedBytes[resizedOffset++] * _byteToFloat;
        input[inputOffset++] = resizedBytes[resizedOffset++] * _byteToFloat;
        input[inputOffset++] = resizedBytes[resizedOffset++] * _byteToFloat;
      }
    }

    return _YoloPreprocessedFrame(
      input: input,
      originalWidth: frame.width,
      originalHeight: frame.height,
      inputWidth: inputWidth,
      inputHeight: inputHeight,
      scale: scale,
      padX: padX.toDouble(),
      padY: padY.toDouble(),
    );
  }

  List<ChickenDetection> _parseDetections(
    Float32List output,
    _YoloModelMetadata metadata,
    _YoloPreprocessedFrame frame,
  ) {
    final layout = metadata.outputLayout;
    final predictions = <_YoloPrediction>[];

    for (var candidate = 0; candidate < layout.candidateCount; candidate += 1) {
      final prediction = _predictionForCandidate(output, layout, candidate);
      if (prediction == null ||
          prediction.confidence <
              _confidenceThresholdForClass(prediction.classIndex)) {
        continue;
      }

      final box = _boxForPrediction(prediction, frame);
      if (box == null || !_looksLikeRoosterBox(box)) {
        continue;
      }

      predictions.add(prediction.copyWith(box: box));
    }

    predictions.sort((a, b) => b.confidence.compareTo(a.confidence));
    final selected = <_YoloPrediction>[];
    for (final prediction in predictions) {
      if (selected.length >= _maxDetections) {
        break;
      }

      final overlappingIndex = selected.indexWhere(
        (other) =>
            _intersectionOverUnion(other.box, prediction.box) >
            _sameRoosterIouThreshold,
      );
      if (overlappingIndex == -1) {
        selected.add(prediction);
        continue;
      }

      final existing = selected[overlappingIndex];
      if (_shouldReplaceOverlappingPrediction(
        current: existing,
        incoming: prediction,
      )) {
        selected[overlappingIndex] = prediction;
      }
    }

    return selected
        .map(
          (prediction) => ChickenDetection(
            box: prediction.box,
            label: _labelForClass(prediction.classIndex),
            confidence: prediction.confidence,
            condition: _conditionForClass(prediction.classIndex),
          ),
        )
        .toList(growable: false);
  }

  Float32List _inputBufferForSize(int length) {
    final existing = _inputBuffer;
    if (existing != null && existing.length == length) {
      return existing;
    }

    final buffer = Float32List(length);
    _inputBuffer = buffer;
    return buffer;
  }

  Float32List _outputBufferForSize(int length) {
    final existing = _outputBuffer;
    if (existing != null && existing.length == length) {
      return existing;
    }

    final buffer = Float32List(length);
    _outputBuffer = buffer;
    return buffer;
  }

  _YoloPrediction? _predictionForCandidate(
    Float32List output,
    _YoloTensorLayout layout,
    int candidate,
  ) {
    final attributeCount = layout.attributeCount;
    if (attributeCount < 5) {
      return null;
    }

    final hasObjectness = attributeCount == _labels.length + 5;
    final classStart = hasObjectness ? 5 : 4;
    final classCount = attributeCount - classStart;
    var bestClassIndex = 0;
    var bestClassScore = 0.0;
    var abnormalClassIndex = -1;
    var abnormalClassScore = 0.0;

    if (classCount <= 0) {
      bestClassScore = _scoreValue(layout.valueAt(output, candidate, 4));
    } else {
      for (var classOffset = 0; classOffset < classCount; classOffset += 1) {
        final score = _scoreValue(
          layout.valueAt(output, candidate, classStart + classOffset),
        );
        if (score > bestClassScore) {
          bestClassScore = score;
          bestClassIndex = classOffset;
        }
        if (classOffset < _labelConditions.length &&
            _labelConditions[classOffset] == HealthState.abnormal) {
          abnormalClassIndex = classOffset;
          abnormalClassScore = score;
        }
      }
    }

    final objectness = hasObjectness
        ? _scoreValue(layout.valueAt(output, candidate, 4))
        : 1.0;
    var selectedClassIndex = bestClassIndex;
    var confidence = objectness * bestClassScore;
    final abnormalConfidence = objectness * abnormalClassScore;
    if (abnormalClassIndex >= 0 &&
        abnormalConfidence >= _abnormalConfidenceThreshold &&
        abnormalConfidence >= confidence * _abnormalPriorityRatio) {
      selectedClassIndex = abnormalClassIndex;
      confidence = abnormalConfidence;
    }

    return _YoloPrediction(
      box: Rect.zero,
      classIndex: selectedClassIndex,
      confidence: confidence,
      centerX: layout.valueAt(output, candidate, 0),
      centerY: layout.valueAt(output, candidate, 1),
      width: layout.valueAt(output, candidate, 2),
      height: layout.valueAt(output, candidate, 3),
    );
  }

  bool _shouldReplaceOverlappingPrediction({
    required _YoloPrediction current,
    required _YoloPrediction incoming,
  }) {
    final currentCondition = _conditionForClass(current.classIndex);
    final incomingCondition = _conditionForClass(incoming.classIndex);
    if (incomingCondition == HealthState.abnormal &&
        currentCondition != HealthState.abnormal &&
        incoming.confidence >= current.confidence * _abnormalPriorityRatio) {
      return true;
    }

    if (incomingCondition != HealthState.abnormal &&
        currentCondition == HealthState.abnormal &&
        incoming.confidence < current.confidence / _abnormalPriorityRatio) {
      return false;
    }

    return incoming.confidence > current.confidence;
  }

  double _confidenceThresholdForClass(int classIndex) {
    return _conditionForClass(classIndex) == HealthState.abnormal
        ? _abnormalConfidenceThreshold
        : _confidenceThreshold;
  }

  bool _looksLikeRoosterBox(Rect box) {
    if (box.width <= 0 || box.height <= 0) {
      return false;
    }

    final area = box.width * box.height;
    if (area < _minimumBoxArea || area > _maximumBoxArea) {
      return false;
    }

    final aspectRatio = box.width / box.height;
    return aspectRatio >= _minimumBoxAspectRatio &&
        aspectRatio <= _maximumBoxAspectRatio;
  }

  Rect? _boxForPrediction(
    _YoloPrediction prediction,
    _YoloPreprocessedFrame frame,
  ) {
    var centerX = prediction.centerX;
    var centerY = prediction.centerY;
    var width = prediction.width;
    var height = prediction.height;

    final appearsNormalized =
        centerX.abs() <= 1.5 &&
        centerY.abs() <= 1.5 &&
        width.abs() <= 1.5 &&
        height.abs() <= 1.5;
    if (appearsNormalized) {
      centerX *= frame.inputWidth;
      centerY *= frame.inputHeight;
      width *= frame.inputWidth;
      height *= frame.inputHeight;
    }

    final left = (centerX - width / 2 - frame.padX) / frame.scale;
    final top = (centerY - height / 2 - frame.padY) / frame.scale;
    final right = (centerX + width / 2 - frame.padX) / frame.scale;
    final bottom = (centerY + height / 2 - frame.padY) / frame.scale;

    final normalizedLeft = (left / frame.originalWidth).clamp(0.0, 1.0);
    final normalizedTop = (top / frame.originalHeight).clamp(0.0, 1.0);
    final normalizedRight = (right / frame.originalWidth).clamp(0.0, 1.0);
    final normalizedBottom = (bottom / frame.originalHeight).clamp(0.0, 1.0);

    if (normalizedRight <= normalizedLeft ||
        normalizedBottom <= normalizedTop) {
      return null;
    }

    return Rect.fromLTRB(
      normalizedLeft.toDouble(),
      normalizedTop.toDouble(),
      normalizedRight.toDouble(),
      normalizedBottom.toDouble(),
    );
  }

  double _scoreValue(double value) {
    if (value >= 0 && value <= 1) {
      return value;
    }
    return 1 / (1 + math.exp(-value));
  }

  String _labelForClass(int classIndex) {
    if (classIndex >= 0 && classIndex < _displayLabels.length) {
      return _displayLabels[classIndex];
    }

    if (classIndex >= 0 && classIndex < _labels.length) {
      final label = _labels[classIndex].toLowerCase();
      if (label.contains('abnormal')) {
        return 'abnormal rooster';
      }
      if (label.contains('normal') || label.contains('healthy')) {
        return 'normal rooster';
      }
      return label.replaceAll('_', ' ');
    }
    return 'rooster';
  }

  HealthState _conditionForClass(int classIndex) {
    if (classIndex >= 0 && classIndex < _labelConditions.length) {
      return _labelConditions[classIndex];
    }

    final label = _labelForClass(classIndex).toLowerCase();
    if (label.contains('abnormal') ||
        label.contains('sick') ||
        label.contains('injur') ||
        label.contains('disease') ||
        label.contains('unhealthy')) {
      return HealthState.abnormal;
    }
    if (label.contains('healthy')) {
      return HealthState.healthy;
    }
    return HealthState.normal;
  }

  double _intersectionOverUnion(Rect a, Rect b) {
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

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _modelMetadata = null;
    _inputBuffer = null;
    _outputBuffer = null;
  }
}

class _YoloModelMetadata {
  const _YoloModelMetadata({
    required this.inputWidth,
    required this.inputHeight,
    required this.outputElementCount,
    required this.outputLayout,
  });

  final int inputWidth;
  final int inputHeight;
  final int outputElementCount;
  final _YoloTensorLayout outputLayout;
}

class _YoloPreprocessedFrame {
  const _YoloPreprocessedFrame({
    required this.input,
    required this.originalWidth,
    required this.originalHeight,
    required this.inputWidth,
    required this.inputHeight,
    required this.scale,
    required this.padX,
    required this.padY,
  });

  final Float32List input;
  final int originalWidth;
  final int originalHeight;
  final int inputWidth;
  final int inputHeight;
  final double scale;
  final double padX;
  final double padY;
}

class _YoloTensorLayout {
  const _YoloTensorLayout({
    required this.attributesFirst,
    required this.candidateCount,
    required this.attributeCount,
  });

  final bool attributesFirst;
  final int candidateCount;
  final int attributeCount;

  factory _YoloTensorLayout.fromShape(List<int> shape) {
    final dimensions = shape.length == 3 && shape.first == 1
        ? shape.sublist(1)
        : shape;
    if (dimensions.length != 2) {
      throw FormatException(
        'Expected YOLO output tensor with 2 dimensions, got $shape.',
      );
    }

    final first = dimensions[0];
    final second = dimensions[1];
    final attributesFirst = first <= 64 && second > first;
    return _YoloTensorLayout(
      attributesFirst: attributesFirst,
      candidateCount: attributesFirst ? second : first,
      attributeCount: attributesFirst ? first : second,
    );
  }

  double valueAt(Float32List values, int candidate, int attribute) {
    final index = attributesFirst
        ? attribute * candidateCount + candidate
        : candidate * attributeCount + attribute;
    return values[index];
  }
}

class _YoloPrediction {
  const _YoloPrediction({
    required this.box,
    required this.classIndex,
    required this.confidence,
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
  });

  final Rect box;
  final int classIndex;
  final double confidence;
  final double centerX;
  final double centerY;
  final double width;
  final double height;

  _YoloPrediction copyWith({Rect? box}) {
    return _YoloPrediction(
      box: box ?? this.box,
      classIndex: classIndex,
      confidence: confidence,
      centerX: centerX,
      centerY: centerY,
      width: width,
      height: height,
    );
  }
}
