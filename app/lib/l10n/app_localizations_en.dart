// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageName => 'English';

  @override
  String get languageSystem => 'System';

  @override
  String get languageMenuTooltip => 'Language';

  @override
  String get serversTitle => 'Servers';

  @override
  String get addServerTooltip => 'Add a server';

  @override
  String get serverBootstrapped => 'Bootstrapped';

  @override
  String get serverNotBootstrapped => 'Not bootstrapped';

  @override
  String get serversLoadFailed => 'Could not read the stored servers';

  @override
  String get tryAgain => 'Try again';

  @override
  String get serversEmptyTitle => 'No servers yet';

  @override
  String get serversEmptyHint =>
      'Add a server to deploy the stack onto it and start a chat.';

  @override
  String get addServerTitle => 'Add a server';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldNameHelper => 'Optional — the host is used when left blank';

  @override
  String get fieldHost => 'Host';

  @override
  String get fieldHostHint => 'name.example.com or 192.0.2.10';

  @override
  String get fieldPort => 'SSH port';

  @override
  String get fieldUsername => 'Username';

  @override
  String get sectionOneTimeSecrets => 'Used once, never stored';

  @override
  String get fieldRootPassword => 'Root password';

  @override
  String get fieldRootPasswordHelper =>
      'The bootstrap installs a key with it and then drops it';

  @override
  String get fieldProviderKey => 'Anthropic API key';

  @override
  String get fieldProviderKeyHelper => 'The stack will not start without it';

  @override
  String get errorEnterHost => 'Enter the host';

  @override
  String get errorEnterUsername => 'Enter the username';

  @override
  String get errorEnterRootPassword => 'Enter the root password';

  @override
  String get errorEnterProviderKey => 'Enter the Anthropic API key';

  @override
  String get errorPortRange => 'Port must be a number between 1 and 65535';

  @override
  String errorSaveFailed(String error) {
    return 'Could not save the server: $error';
  }

  @override
  String get saving => 'Saving…';

  @override
  String get saveServer => 'Save the server';
}
