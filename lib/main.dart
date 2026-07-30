import 'dart:isolate';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:coolapp/esp32_sensor_service.dart';
import 'package:coolapp/l10n/app_localizations.dart';
import 'package:crypto/crypto.dart';
import 'package:fijkplayer_plus/fijkplayer_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_session.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:xml/xml.dart';

part 'src/app_constants.dart';
part 'src/rooster_watch_app.dart';
part 'src/theme/app_theme.dart';
part 'src/pages/app_pages.dart';
part 'src/pages/guidelines_redesign.dart';
part 'src/controllers/app_controller.dart';
part 'src/models/app_models.dart';
part 'src/services/on_device_yolo_detector.dart';
part 'src/widgets/landing_widgets.dart';
part 'src/services/rtsp_camera_scanner.dart';
part 'src/widgets/cctv_connection_panel.dart';
part 'src/widgets/v380_ptz_control_panel.dart';
part 'src/services/onvif_ptz_client.dart';
part 'src/services/camera_stream_helpers.dart';
part 'src/services/rtsp_recorder_service.dart';
part 'src/pages/recordings_page.dart';
part 'src/pages/multi_camera_fullscreen_page.dart';
part 'src/widgets/live_feed_card.dart';
part 'src/widgets/info_cards.dart';
part 'src/models/state_labels.dart';
part 'src/utils/time_labels.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  List<CameraDescription> cameras = const [];
  try {
    cameras = await availableCameras();
  } catch (_) {
    cameras = const [];
  }

  runApp(RoosterWatchApp(cameras: cameras));
}
