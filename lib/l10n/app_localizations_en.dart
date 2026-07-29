// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navOverview => 'Overview';

  @override
  String get navUsers => 'Users';

  @override
  String get navCctv => 'CCTV';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navScan => 'Scan';

  @override
  String get navGuides => 'Guides';

  @override
  String get navProfile => 'Profile';

  @override
  String get loginAdminAccess => 'Admin access';

  @override
  String get loginTitle => 'Log in';

  @override
  String get loginSubtitle => 'Monitor your rooster, anytime, anywhere.';

  @override
  String get loginUserSegment => 'User';

  @override
  String get loginAdminSegment => 'Admin';

  @override
  String get loginUsernameLabel => 'Username or email';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginSigningIn => 'Signing in...';

  @override
  String get loginButtonUser => 'Log in';

  @override
  String get loginButtonAdmin => 'Log in as Admin';

  @override
  String get loginGoogleOpening => 'Opening Google...';

  @override
  String get loginGoogleUser => 'Continue with Google';

  @override
  String get loginGoogleAdmin => 'Continue as Admin with Google';

  @override
  String get settingsTitle => 'App Settings';

  @override
  String get settingsSubtitle => 'Adjust how the app looks and behaves.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsAutoPlayTitle => 'Auto-play CCTV Preview';

  @override
  String get settingsAutoPlaySubtitle => 'Start camera previews automatically';

  @override
  String get settingsDataSaverTitle => 'Data Saver';

  @override
  String get settingsDataSaverSubtitle =>
      'Reduce data usage on mobile networks';

  @override
  String get settingsCameraPermTitle => 'Camera Permissions';

  @override
  String get settingsClearCacheTitle => 'Clear Cache';

  @override
  String get settingsCacheEmpty => 'Cache is empty';

  @override
  String settingsCacheSize(String megabytes) {
    return '$megabytes MB';
  }

  @override
  String get settingsSaveButton => 'Save Settings';

  @override
  String get settingsCancelButton => 'Cancel';
}
