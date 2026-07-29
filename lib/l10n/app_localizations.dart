import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fil.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fil'),
  ];

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get navOverview;

  /// No description provided for @navUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get navUsers;

  /// No description provided for @navCctv.
  ///
  /// In en, this message translates to:
  /// **'CCTV'**
  String get navCctv;

  /// No description provided for @navInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get navInbox;

  /// No description provided for @navScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get navScan;

  /// No description provided for @navGuides.
  ///
  /// In en, this message translates to:
  /// **'Guides'**
  String get navGuides;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @loginAdminAccess.
  ///
  /// In en, this message translates to:
  /// **'Admin access'**
  String get loginAdminAccess;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Monitor your rooster, anytime, anywhere.'**
  String get loginSubtitle;

  /// No description provided for @loginUserSegment.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get loginUserSegment;

  /// No description provided for @loginAdminSegment.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get loginAdminSegment;

  /// No description provided for @loginUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username or email'**
  String get loginUsernameLabel;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get loginSigningIn;

  /// No description provided for @loginButtonUser.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginButtonUser;

  /// No description provided for @loginButtonAdmin.
  ///
  /// In en, this message translates to:
  /// **'Log in as Admin'**
  String get loginButtonAdmin;

  /// No description provided for @loginGoogleOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening Google...'**
  String get loginGoogleOpening;

  /// No description provided for @loginGoogleUser.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get loginGoogleUser;

  /// No description provided for @loginGoogleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Continue as Admin with Google'**
  String get loginGoogleAdmin;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust how the app looks and behaves.'**
  String get settingsSubtitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsAutoPlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-play CCTV Preview'**
  String get settingsAutoPlayTitle;

  /// No description provided for @settingsAutoPlaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start camera previews automatically'**
  String get settingsAutoPlaySubtitle;

  /// No description provided for @settingsDataSaverTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Saver'**
  String get settingsDataSaverTitle;

  /// No description provided for @settingsDataSaverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reduce data usage on mobile networks'**
  String get settingsDataSaverSubtitle;

  /// No description provided for @settingsCameraPermTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera Permissions'**
  String get settingsCameraPermTitle;

  /// No description provided for @settingsClearCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get settingsClearCacheTitle;

  /// No description provided for @settingsCacheEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cache is empty'**
  String get settingsCacheEmpty;

  /// No description provided for @settingsCacheSize.
  ///
  /// In en, this message translates to:
  /// **'{megabytes} MB'**
  String settingsCacheSize(String megabytes);

  /// No description provided for @settingsSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get settingsSaveButton;

  /// No description provided for @settingsCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancelButton;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fil'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fil':
      return AppLocalizationsFil();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
