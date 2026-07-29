// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Filipino Pilipino (`fil`).
class AppLocalizationsFil extends AppLocalizations {
  AppLocalizationsFil([String locale = 'fil']) : super(locale);

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navOverview => 'Pangkalahatang-ideya';

  @override
  String get navUsers => 'Mga Gumagamit';

  @override
  String get navCctv => 'CCTV';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navScan => 'I-scan';

  @override
  String get navGuides => 'Mga Gabay';

  @override
  String get navProfile => 'Profile';

  @override
  String get loginAdminAccess => 'Pag-access ng Admin';

  @override
  String get loginTitle => 'Mag-log in';

  @override
  String get loginSubtitle =>
      'Subaybayan ang iyong tandang, kahit kailan, kahit saan.';

  @override
  String get loginUserSegment => 'Gumagamit';

  @override
  String get loginAdminSegment => 'Admin';

  @override
  String get loginUsernameLabel => 'Username o email';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginSigningIn => 'Nagla-log in...';

  @override
  String get loginButtonUser => 'Mag-log in';

  @override
  String get loginButtonAdmin => 'Mag-log in bilang Admin';

  @override
  String get loginGoogleOpening => 'Binubuksan ang Google...';

  @override
  String get loginGoogleUser => 'Magpatuloy gamit ang Google';

  @override
  String get loginGoogleAdmin => 'Magpatuloy bilang Admin gamit ang Google';

  @override
  String get settingsTitle => 'Mga Setting ng App';

  @override
  String get settingsSubtitle =>
      'I-ayos kung paano lumalabas at kumikilos ang app.';

  @override
  String get settingsLanguage => 'Wika';

  @override
  String get settingsAutoPlayTitle => 'Awtomatikong i-play ang CCTV Preview';

  @override
  String get settingsAutoPlaySubtitle =>
      'Awtomatikong simulan ang preview ng camera';

  @override
  String get settingsDataSaverTitle => 'Data Saver';

  @override
  String get settingsDataSaverSubtitle =>
      'Bawasan ang paggamit ng data sa mobile network';

  @override
  String get settingsCameraPermTitle => 'Pahintulot sa Camera';

  @override
  String get settingsClearCacheTitle => 'I-clear ang Cache';

  @override
  String get settingsCacheEmpty => 'Walang laman ang cache';

  @override
  String settingsCacheSize(String megabytes) {
    return '$megabytes MB';
  }

  @override
  String get settingsSaveButton => 'I-save ang mga Setting';

  @override
  String get settingsCancelButton => 'Kanselahin';
}
