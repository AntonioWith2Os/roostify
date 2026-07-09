part of '../../main.dart';

extension on HealthState {
  String get label => switch (this) {
    HealthState.healthy => 'Healthy',
    HealthState.normal => 'Normal',
    HealthState.abnormal => 'Abnormal',
  };

  Color get color => switch (this) {
    HealthState.healthy => const Color(0xFF26C281),
    HealthState.normal => const Color(0xFFE6B452),
    HealthState.abnormal => const Color(0xFFFF6B72),
  };
}

extension on CctvInspectionState {
  String get label => switch (this) {
    CctvInspectionState.idle => 'Idle',
    CctvInspectionState.waitingForFrame => 'Waiting',
    CctvInspectionState.capturing => 'Capturing',
    CctvInspectionState.inspecting => 'Model',
    CctvInspectionState.completed => 'Complete',
    CctvInspectionState.error => 'Error',
  };

  Color get color => switch (this) {
    CctvInspectionState.idle => const Color(0xFF8E97B8),
    CctvInspectionState.waitingForFrame => const Color(0xFFE6B452),
    CctvInspectionState.capturing => const Color(0xFF4DA1FF),
    CctvInspectionState.inspecting => const Color(0xFF4DA1FF),
    CctvInspectionState.completed => const Color(0xFF26C281),
    CctvInspectionState.error => const Color(0xFFFF6B72),
  };
}
