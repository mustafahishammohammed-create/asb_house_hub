import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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
    Locale('ar'),
    Locale('en'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'ASB House Hub'**
  String get appTitle;

  /// Emerald House name
  ///
  /// In en, this message translates to:
  /// **'Emerald'**
  String get houseEmerald;

  /// Ruby House name
  ///
  /// In en, this message translates to:
  /// **'Ruby'**
  String get houseRuby;

  /// Sapphire House name
  ///
  /// In en, this message translates to:
  /// **'Sapphire'**
  String get houseSapphire;

  /// Topaz House name
  ///
  /// In en, this message translates to:
  /// **'Topaz'**
  String get houseTopaz;

  /// Bottom navigation label for Home
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom navigation label for Arena
  ///
  /// In en, this message translates to:
  /// **'Arena'**
  String get navArena;

  /// Bottom navigation label for Leaderboard
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get navLeaderboard;

  /// Bottom navigation label for Wallet
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get navWallet;

  /// Bottom navigation label for Academics
  ///
  /// In en, this message translates to:
  /// **'Academics'**
  String get navAcademics;

  /// Navigation label for Events
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get navEvents;

  /// Navigation label for Elections
  ///
  /// In en, this message translates to:
  /// **'Elections'**
  String get navElections;

  /// Navigation label for Sports
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get navSports;

  /// Generic Save action
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// Generic Cancel action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Generic Delete action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// Generic Close action
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// Generic Submit action
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get actionSubmit;

  /// Generic Confirm action
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// Generic Retry action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// Generic Search action
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// Generic Filter action
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get actionFilter;

  /// Generic Edit action
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// Generic Back action
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// Generic Next action
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// Generic Done action
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// Accessibility label for closing dialogs
  ///
  /// In en, this message translates to:
  /// **'Close dialog'**
  String get closeDialog;

  /// Login button or header label
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Sign Up button or header label
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signup;

  /// Email input field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password input field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Confirm Password input field label
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// Scholar Number input field label
  ///
  /// In en, this message translates to:
  /// **'Scholar Number'**
  String get scholarNumber;

  /// Accessibility label to reveal password text
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// Accessibility label to conceal password text
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// Forgot password link label
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// Sign In button label
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Sign Out button label
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Create Account action label
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// Prompt for existing account users
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign In'**
  String get alreadyHaveAccount;

  /// Prompt for new users to register
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign Up'**
  String get dontHaveAccount;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
