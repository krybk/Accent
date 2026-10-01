import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('ru'),
  ];

  /// No description provided for @languageName.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageMenuTooltip;

  /// No description provided for @serversTitle.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get serversTitle;

  /// No description provided for @addServerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a server'**
  String get addServerTooltip;

  /// No description provided for @serverBootstrapped.
  ///
  /// In en, this message translates to:
  /// **'Bootstrapped'**
  String get serverBootstrapped;

  /// No description provided for @serverNotBootstrapped.
  ///
  /// In en, this message translates to:
  /// **'Not bootstrapped'**
  String get serverNotBootstrapped;

  /// No description provided for @serversLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the stored servers'**
  String get serversLoadFailed;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @serversEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No servers yet'**
  String get serversEmptyTitle;

  /// No description provided for @serversEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add a server to deploy the stack onto it and start a chat.'**
  String get serversEmptyHint;

  /// No description provided for @addServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a server'**
  String get addServerTitle;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Optional — the host is used when left blank'**
  String get fieldNameHelper;

  /// No description provided for @fieldHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get fieldHost;

  /// No description provided for @fieldHostHint.
  ///
  /// In en, this message translates to:
  /// **'name.example.com or 192.0.2.10'**
  String get fieldHostHint;

  /// No description provided for @fieldPort.
  ///
  /// In en, this message translates to:
  /// **'SSH port'**
  String get fieldPort;

  /// No description provided for @fieldUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get fieldUsername;

  /// No description provided for @sectionOneTimeSecrets.
  ///
  /// In en, this message translates to:
  /// **'Used once, never stored'**
  String get sectionOneTimeSecrets;

  /// No description provided for @fieldRootPassword.
  ///
  /// In en, this message translates to:
  /// **'Root password'**
  String get fieldRootPassword;

  /// No description provided for @fieldRootPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'The bootstrap installs a key with it and then drops it'**
  String get fieldRootPasswordHelper;

  /// No description provided for @fieldProviderKey.
  ///
  /// In en, this message translates to:
  /// **'Anthropic API key'**
  String get fieldProviderKey;

  /// No description provided for @fieldProviderKeyHelper.
  ///
  /// In en, this message translates to:
  /// **'The stack will not start without it'**
  String get fieldProviderKeyHelper;

  /// No description provided for @errorEnterHost.
  ///
  /// In en, this message translates to:
  /// **'Enter the host'**
  String get errorEnterHost;

  /// No description provided for @errorEnterUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter the username'**
  String get errorEnterUsername;

  /// No description provided for @errorEnterRootPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter the root password'**
  String get errorEnterRootPassword;

  /// No description provided for @errorEnterProviderKey.
  ///
  /// In en, this message translates to:
  /// **'Enter the Anthropic API key'**
  String get errorEnterProviderKey;

  /// No description provided for @errorPortRange.
  ///
  /// In en, this message translates to:
  /// **'Port must be a number between 1 and 65535'**
  String get errorPortRange;

  /// No description provided for @errorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the server: {error}'**
  String errorSaveFailed(String error);

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @saveServer.
  ///
  /// In en, this message translates to:
  /// **'Save the server'**
  String get saveServer;
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
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
