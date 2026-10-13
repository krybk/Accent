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

  @override
  String get navPlane => 'Plane';

  @override
  String get navUsage => 'Usage';

  @override
  String get planeSectionPlans => 'Plans';

  @override
  String get planeSectionProviders => 'Providers';

  @override
  String get planeSectionServices => 'Services';

  @override
  String get planeSectionPaused => 'Paused models';

  @override
  String get planeSectionActions => 'Quick actions';

  @override
  String get planeNoPlans => 'No plans';

  @override
  String get providerCurrent => 'current';

  @override
  String get providerNoKey => 'no key';

  @override
  String providerCooling(String until, String reason) {
    return 'cooling until $until — $reason';
  }

  @override
  String get pausedIndefinitely => 'indefinitely';

  @override
  String get actionArgPrompt => 'Enter a number';

  @override
  String get actionRun => 'Run';

  @override
  String actionExitCode(int code) {
    return 'Exit code $code';
  }

  @override
  String get usageToday => 'Today';

  @override
  String get usage7d => '7 days';

  @override
  String get usage30d => '30 days';

  @override
  String get usageSteps => 'Steps';

  @override
  String get usageCost => 'Cost';

  @override
  String get usageInput => 'Input';

  @override
  String get usageOutput => 'Output';

  @override
  String get usageCacheRead => 'Cache read';

  @override
  String get usageCacheWrite => 'Cache write';

  @override
  String usageUntracked(int count) {
    return '$count steps predate token accounting';
  }

  @override
  String get usageRoles => 'Roles';

  @override
  String get usageRoleChat => 'Chat';

  @override
  String usageGeneratedAt(String time) {
    return 'Generated at $time';
  }

  @override
  String get gatewayErrorTopUp =>
      'The model provider\'s balance is exhausted — top it up to continue';

  @override
  String get gatewayErrorUnauthorized => 'The gateway rejected the token';

  @override
  String get gatewayErrorNoPlane =>
      'No control plane is configured on this server';

  @override
  String get gatewayErrorPlaneDown => 'The control plane is not answering';

  @override
  String get gatewayErrorUnreachable => 'Could not reach the server';

  @override
  String get gatewayErrorNoCredentials =>
      'No gateway credentials are stored for this server — bootstrap it again';

  @override
  String gatewayErrorOther(String code, String message) {
    return '$code: $message';
  }

  @override
  String get bootstrapTitle => 'Deploying the stack';

  @override
  String get bootstrapDone => 'The server is ready';

  @override
  String get bootstrapFailed => 'The bootstrap failed';

  @override
  String get bootstrapClose => 'Close';

  @override
  String get bootstrapFinish => 'Done';

  @override
  String get bootstrapStageConnect => 'Connecting with the password';

  @override
  String get bootstrapStageInstallKey => 'Installing the SSH key';

  @override
  String get bootstrapStageKeyOnlyConnect =>
      'Checking the key works without the password';

  @override
  String get bootstrapStageInstallDocker => 'Installing Docker';

  @override
  String get bootstrapStageCheckout => 'Fetching the stack sources';

  @override
  String get bootstrapStageWriteEnvironment =>
      'Writing the gateway configuration';

  @override
  String get bootstrapStageStartStack => 'Starting the stack';

  @override
  String get bootstrapStageAwaitHealth => 'Waiting for the stack to answer';

  @override
  String get bootstrapStageReadCertificate => 'Reading the certificate';

  @override
  String get bootstrapStageStoreCredentials => 'Storing the credentials';
}
