part of '../../main.dart';

String _timestampLabel() {
  return _timeLabelFor(DateTime.now());
}

String _sensorTimeLabel(DateTime value) {
  return _timeLabelFor(value);
}

String _timeLabelFor(DateTime value) {
  final now = value;
  final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
  final minute = now.minute.toString().padLeft(2, '0');
  final suffix = now.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}
