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
  /// **'Anthropic API key (optional)'**
  String get fieldProviderKey;

  /// No description provided for @fieldProviderKeyHelper.
  ///
  /// In en, this message translates to:
  /// **'Not needed for chat, which goes through the control plane. Only the stack\'s own /v1/chat uses it.'**
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

  /// No description provided for @navPlane.
  ///
  /// In en, this message translates to:
  /// **'Plane'**
  String get navPlane;

  /// No description provided for @navUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get navUsage;

  /// No description provided for @planeSectionPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get planeSectionPlans;

  /// No description provided for @planeSectionProviders.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get planeSectionProviders;

  /// No description provided for @planeSectionServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get planeSectionServices;

  /// No description provided for @planeSectionPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused models'**
  String get planeSectionPaused;

  /// No description provided for @planeSectionActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get planeSectionActions;

  /// No description provided for @planeNoPlans.
  ///
  /// In en, this message translates to:
  /// **'No plans'**
  String get planeNoPlans;

  /// No description provided for @planeSliceOf.
  ///
  /// In en, this message translates to:
  /// **'Stage {slice} of {total}'**
  String planeSliceOf(int slice, int total);

  /// No description provided for @planeSlice.
  ///
  /// In en, this message translates to:
  /// **'Stage {slice}'**
  String planeSlice(int slice);

  /// No description provided for @planeSliceNow.
  ///
  /// In en, this message translates to:
  /// **'Stage {slice} — now'**
  String planeSliceNow(int slice);

  /// No description provided for @planeSliceDone.
  ///
  /// In en, this message translates to:
  /// **'Stage {slice} — {done} of {total} tasks done'**
  String planeSliceDone(int slice, int done, int total);

  /// No description provided for @planeLater.
  ///
  /// In en, this message translates to:
  /// **'Later stages'**
  String get planeLater;

  /// No description provided for @providerCurrent.
  ///
  /// In en, this message translates to:
  /// **'current'**
  String get providerCurrent;

  /// No description provided for @providerNoKey.
  ///
  /// In en, this message translates to:
  /// **'no key'**
  String get providerNoKey;

  /// No description provided for @providerCooling.
  ///
  /// In en, this message translates to:
  /// **'cooling until {until} — {reason}'**
  String providerCooling(String until, String reason);

  /// No description provided for @pausedIndefinitely.
  ///
  /// In en, this message translates to:
  /// **'indefinitely'**
  String get pausedIndefinitely;

  /// No description provided for @actionArgPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get actionArgPrompt;

  /// No description provided for @actionRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get actionRun;

  /// No description provided for @actionExitCode.
  ///
  /// In en, this message translates to:
  /// **'Exit code {code}'**
  String actionExitCode(int code);

  /// No description provided for @usageToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get usageToday;

  /// No description provided for @usage7d.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get usage7d;

  /// No description provided for @usage30d.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get usage30d;

  /// No description provided for @usageSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get usageSteps;

  /// No description provided for @usageCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get usageCost;

  /// No description provided for @usageInput.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get usageInput;

  /// No description provided for @usageOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get usageOutput;

  /// No description provided for @usageCacheRead.
  ///
  /// In en, this message translates to:
  /// **'Cache read'**
  String get usageCacheRead;

  /// No description provided for @usageCacheWrite.
  ///
  /// In en, this message translates to:
  /// **'Cache write'**
  String get usageCacheWrite;

  /// No description provided for @usageUntracked.
  ///
  /// In en, this message translates to:
  /// **'{count} steps predate token accounting'**
  String usageUntracked(int count);

  /// No description provided for @usageRoles.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get usageRoles;

  /// No description provided for @usageRoleChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get usageRoleChat;

  /// No description provided for @usageGeneratedAt.
  ///
  /// In en, this message translates to:
  /// **'Generated at {time}'**
  String usageGeneratedAt(String time);

  /// No description provided for @gatewayErrorTopUp.
  ///
  /// In en, this message translates to:
  /// **'The model provider\'s balance is exhausted — top it up to continue'**
  String get gatewayErrorTopUp;

  /// No description provided for @gatewayErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'The gateway rejected the token'**
  String get gatewayErrorUnauthorized;

  /// No description provided for @gatewayErrorNoPlane.
  ///
  /// In en, this message translates to:
  /// **'No control plane is configured on this server'**
  String get gatewayErrorNoPlane;

  /// No description provided for @gatewayErrorPlaneDown.
  ///
  /// In en, this message translates to:
  /// **'The control plane is not answering'**
  String get gatewayErrorPlaneDown;

  /// No description provided for @gatewayErrorUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server'**
  String get gatewayErrorUnreachable;

  /// No description provided for @gatewayErrorNoCredentials.
  ///
  /// In en, this message translates to:
  /// **'No gateway credentials are stored for this server — bootstrap it again'**
  String get gatewayErrorNoCredentials;

  /// No description provided for @gatewayErrorOther.
  ///
  /// In en, this message translates to:
  /// **'{code}: {message}'**
  String gatewayErrorOther(String code, String message);

  /// No description provided for @bootstrapTitle.
  ///
  /// In en, this message translates to:
  /// **'Deploying the stack'**
  String get bootstrapTitle;

  /// No description provided for @bootstrapDone.
  ///
  /// In en, this message translates to:
  /// **'The server is ready'**
  String get bootstrapDone;

  /// No description provided for @bootstrapFailed.
  ///
  /// In en, this message translates to:
  /// **'The bootstrap failed'**
  String get bootstrapFailed;

  /// No description provided for @bootstrapClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get bootstrapClose;

  /// No description provided for @bootstrapFinish.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get bootstrapFinish;

  /// No description provided for @bootstrapStageConnect.
  ///
  /// In en, this message translates to:
  /// **'Connecting with the password'**
  String get bootstrapStageConnect;

  /// No description provided for @bootstrapStageInstallKey.
  ///
  /// In en, this message translates to:
  /// **'Installing the SSH key'**
  String get bootstrapStageInstallKey;

  /// No description provided for @bootstrapStageKeyOnlyConnect.
  ///
  /// In en, this message translates to:
  /// **'Checking the key works without the password'**
  String get bootstrapStageKeyOnlyConnect;

  /// No description provided for @bootstrapStageDiscover.
  ///
  /// In en, this message translates to:
  /// **'Looking at what the server already runs'**
  String get bootstrapStageDiscover;

  /// No description provided for @bootstrapStageInstallDocker.
  ///
  /// In en, this message translates to:
  /// **'Installing Docker'**
  String get bootstrapStageInstallDocker;

  /// No description provided for @bootstrapStageCheckout.
  ///
  /// In en, this message translates to:
  /// **'Fetching the stack sources'**
  String get bootstrapStageCheckout;

  /// No description provided for @bootstrapStageWriteEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Writing the gateway configuration'**
  String get bootstrapStageWriteEnvironment;

  /// No description provided for @bootstrapStageStartStack.
  ///
  /// In en, this message translates to:
  /// **'Starting the stack'**
  String get bootstrapStageStartStack;

  /// No description provided for @bootstrapStageAwaitHealth.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the stack to answer'**
  String get bootstrapStageAwaitHealth;

  /// No description provided for @bootstrapStageIssueToken.
  ///
  /// In en, this message translates to:
  /// **'Issuing this app a token'**
  String get bootstrapStageIssueToken;

  /// No description provided for @bootstrapStageReadCertificate.
  ///
  /// In en, this message translates to:
  /// **'Reading the certificate'**
  String get bootstrapStageReadCertificate;

  /// No description provided for @bootstrapStageStoreCredentials.
  ///
  /// In en, this message translates to:
  /// **'Storing the credentials'**
  String get bootstrapStageStoreCredentials;

  /// No description provided for @bootstrapStageSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped: the server already runs it'**
  String get bootstrapStageSkipped;

  /// No description provided for @discoveryExistingGateway.
  ///
  /// In en, this message translates to:
  /// **'Found a running Accent gateway: connecting to it, nothing will be rebuilt'**
  String get discoveryExistingGateway;

  /// No description provided for @discoveryPlaneOnly.
  ///
  /// In en, this message translates to:
  /// **'Found a control plane without a gateway: installing only the gateway'**
  String get discoveryPlaneOnly;

  /// No description provided for @discoveryNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing found: deploying the stack'**
  String get discoveryNothing;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatInputHint;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get chatNewConversation;

  /// No description provided for @chatTierOpus.
  ///
  /// In en, this message translates to:
  /// **'Opus'**
  String get chatTierOpus;

  /// No description provided for @chatTierSonnet.
  ///
  /// In en, this message translates to:
  /// **'Sonnet'**
  String get chatTierSonnet;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'Ask what is being done now and why'**
  String get chatEmpty;

  /// No description provided for @chatDoneCaption.
  ///
  /// In en, this message translates to:
  /// **'{model} · {input} in · {output} out'**
  String chatDoneCaption(String model, String input, String output);

  /// No description provided for @chatErrorRefused.
  ///
  /// In en, this message translates to:
  /// **'The model refused: {message}'**
  String chatErrorRefused(String message);

  /// No description provided for @chatErrorBusy.
  ///
  /// In en, this message translates to:
  /// **'Another chat answer is still running — wait for it to finish'**
  String get chatErrorBusy;

  /// No description provided for @chatErrorNoProvider.
  ///
  /// In en, this message translates to:
  /// **'No model provider is available for the chat'**
  String get chatErrorNoProvider;

  /// No description provided for @chatErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The answer took too long and was stopped'**
  String get chatErrorTimeout;

  /// No description provided for @chatErrorFailed.
  ///
  /// In en, this message translates to:
  /// **'The chat failed: {message}'**
  String chatErrorFailed(String message);

  /// No description provided for @chatErrorSwitched.
  ///
  /// In en, this message translates to:
  /// **'The model was switched off — send again'**
  String get chatErrorSwitched;

  /// No description provided for @chatErrorTooLong.
  ///
  /// In en, this message translates to:
  /// **'The message is too long'**
  String get chatErrorTooLong;

  /// No description provided for @sendToPlan.
  ///
  /// In en, this message translates to:
  /// **'Send to plan'**
  String get sendToPlan;

  /// No description provided for @sendToPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Guidance for a plan'**
  String get sendToPlanTitle;

  /// No description provided for @sendToPlanPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get sendToPlanPlan;

  /// No description provided for @sendToPlanText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get sendToPlanText;

  /// No description provided for @sendToPlanSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendToPlanSend;

  /// No description provided for @sendToPlanNoPlan.
  ///
  /// In en, this message translates to:
  /// **'There is no open plan'**
  String get sendToPlanNoPlan;

  /// No description provided for @sendToPlanSent.
  ///
  /// In en, this message translates to:
  /// **'Sent: {url}'**
  String sendToPlanSent(String url);

  /// No description provided for @sendToPlanCredential.
  ///
  /// In en, this message translates to:
  /// **'The text looks like a credential and was not sent'**
  String get sendToPlanCredential;

  /// No description provided for @sendToPlanNoSuchPlan.
  ///
  /// In en, this message translates to:
  /// **'This plan no longer exists'**
  String get sendToPlanNoSuchPlan;

  /// No description provided for @sendToPlanCommentFailed.
  ///
  /// In en, this message translates to:
  /// **'The server could not post the guidance'**
  String get sendToPlanCommentFailed;

  /// No description provided for @modelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get modelsTitle;

  /// No description provided for @modelOff.
  ///
  /// In en, this message translates to:
  /// **'Off — running on {standIn} ({standInModel})'**
  String modelOff(String standIn, String standInModel);

  /// No description provided for @modelOffNoStandIn.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get modelOffNoStandIn;

  /// No description provided for @modelOffUntil.
  ///
  /// In en, this message translates to:
  /// **'until {until}'**
  String modelOffUntil(String until);

  /// No description provided for @modelDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch {tier} off?'**
  String modelDisableTitle(String tier);

  /// No description provided for @modelDisableBody.
  ///
  /// In en, this message translates to:
  /// **'Running work is saved and continues on the stand-in model.'**
  String get modelDisableBody;

  /// No description provided for @modelDisableConfirm.
  ///
  /// In en, this message translates to:
  /// **'Switch off'**
  String get modelDisableConfirm;

  /// No description provided for @modelErrorLastModel.
  ///
  /// In en, this message translates to:
  /// **'This is the last model that is on; it cannot be switched off'**
  String get modelErrorLastModel;

  /// No description provided for @modelErrorNoSuchTier.
  ///
  /// In en, this message translates to:
  /// **'The server does not know this model'**
  String get modelErrorNoSuchTier;

  /// No description provided for @navQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get navQueue;

  /// No description provided for @queueOrderNote.
  ///
  /// In en, this message translates to:
  /// **'Plans are taken in this order.'**
  String get queueOrderNote;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No open plans'**
  String get queueEmpty;

  /// No description provided for @queueHeld.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get queueHeld;

  /// No description provided for @queueMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get queueMoveUp;

  /// No description provided for @queueMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get queueMoveDown;

  /// No description provided for @queueMoveTop.
  ///
  /// In en, this message translates to:
  /// **'Move to top'**
  String get queueMoveTop;

  /// No description provided for @queueMoveBottom.
  ///
  /// In en, this message translates to:
  /// **'Move to end'**
  String get queueMoveBottom;

  /// No description provided for @queueHold.
  ///
  /// In en, this message translates to:
  /// **'Put on hold'**
  String get queueHold;

  /// No description provided for @queueResume.
  ///
  /// In en, this message translates to:
  /// **'Return to queue'**
  String get queueResume;

  /// No description provided for @queueErrorNoSuchPlan.
  ///
  /// In en, this message translates to:
  /// **'This plan is no longer open'**
  String get queueErrorNoSuchPlan;

  /// No description provided for @navCapacity.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get navCapacity;

  /// No description provided for @navStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get navStats;

  /// No description provided for @queuePriority.
  ///
  /// In en, this message translates to:
  /// **'Priority {priority}'**
  String queuePriority(int priority);

  /// No description provided for @queueSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps {spent} of {limit}'**
  String queueSteps(int spent, int limit);

  /// No description provided for @queueSetPriority.
  ///
  /// In en, this message translates to:
  /// **'Set priority'**
  String get queueSetPriority;

  /// No description provided for @queueSetBudget.
  ///
  /// In en, this message translates to:
  /// **'Set step limit'**
  String get queueSetBudget;

  /// No description provided for @queuePriorityTitle.
  ///
  /// In en, this message translates to:
  /// **'Priority (1 goes first)'**
  String get queuePriorityTitle;

  /// No description provided for @queueDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get queueDefault;

  /// No description provided for @queueBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Step limit'**
  String get queueBudgetTitle;

  /// No description provided for @queueBudgetHelp.
  ///
  /// In en, this message translates to:
  /// **'{spent} spent. From 1 to 100000.'**
  String queueBudgetHelp(int spent);

  /// No description provided for @queueBudgetSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get queueBudgetSave;

  /// No description provided for @valueUnknown.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get valueUnknown;

  /// No description provided for @capacitySlots.
  ///
  /// In en, this message translates to:
  /// **'Agent slots: {slots}, running: {running}'**
  String capacitySlots(String slots, String running);

  /// No description provided for @capacityServer.
  ///
  /// In en, this message translates to:
  /// **'This server'**
  String get capacityServer;

  /// No description provided for @capacityCpu.
  ///
  /// In en, this message translates to:
  /// **'CPU: {pct}%'**
  String capacityCpu(String pct);

  /// No description provided for @capacityMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory: {pct}% ({free} of {total} MB free)'**
  String capacityMemory(String pct, String free, String total);

  /// No description provided for @capacityDisk.
  ///
  /// In en, this message translates to:
  /// **'Disk: {pct}% ({free} GB free)'**
  String capacityDisk(String pct, String free);

  /// No description provided for @capacityCores.
  ///
  /// In en, this message translates to:
  /// **'Cores: {cores}'**
  String capacityCores(String cores);

  /// No description provided for @capacityHostUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Not reachable'**
  String get capacityHostUnreachable;

  /// No description provided for @capacitySubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get capacitySubscription;

  /// No description provided for @capacityWindow.
  ///
  /// In en, this message translates to:
  /// **'{window}: {used} tokens ({pct}%), {burn} per hour'**
  String capacityWindow(String window, String used, String pct, String burn);

  /// No description provided for @capacitySlotsByPlan.
  ///
  /// In en, this message translates to:
  /// **'Slots by plan'**
  String get capacitySlotsByPlan;

  /// No description provided for @capacityPlanSlots.
  ///
  /// In en, this message translates to:
  /// **'Plan #{plan}: {slots} slots'**
  String capacityPlanSlots(String plan, String slots);

  /// No description provided for @capacityPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned load'**
  String get capacityPlanned;

  /// No description provided for @capacityPlannedRow.
  ///
  /// In en, this message translates to:
  /// **'#{plan} {repo}: {width} sessions, {mem} MB, {cores} cores'**
  String capacityPlannedRow(
    String plan,
    String repo,
    String width,
    String mem,
    String cores,
  );

  /// No description provided for @capacityPlannedTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {sessions} sessions, {mem} MB, {cores} cores'**
  String capacityPlannedTotal(String sessions, String mem, String cores);

  /// No description provided for @statsForecast.
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get statsForecast;

  /// No description provided for @statsProgress.
  ///
  /// In en, this message translates to:
  /// **'Requirements done: {pct}%'**
  String statsProgress(String pct);

  /// No description provided for @statsTasksLeft.
  ///
  /// In en, this message translates to:
  /// **'Tasks left in this slice: {left} of {total}'**
  String statsTasksLeft(String left, String total);

  /// No description provided for @statsEta.
  ///
  /// In en, this message translates to:
  /// **'At the current pace: {hours} h'**
  String statsEta(String hours);

  /// No description provided for @statsByKind.
  ///
  /// In en, this message translates to:
  /// **'By sphere and kind'**
  String get statsByKind;

  /// No description provided for @statsGroupRow.
  ///
  /// In en, this message translates to:
  /// **'{tasks} tasks · {wall} min wall · {work} min work · Opus {opus} / Sonnet {sonnet} tokens'**
  String statsGroupRow(
    String tasks,
    String wall,
    String work,
    String opus,
    String sonnet,
  );

  /// No description provided for @statsGroupResources.
  ///
  /// In en, this message translates to:
  /// **'Session memory p90 {mem} MB · cores p75 {cores} · gates p50 {gates} min'**
  String statsGroupResources(String mem, String cores, String gates);

  /// No description provided for @statsBySteps.
  ///
  /// In en, this message translates to:
  /// **'By step'**
  String get statsBySteps;

  /// No description provided for @statsStepRow.
  ///
  /// In en, this message translates to:
  /// **'{n} runs · p50 {p50} min · p90 {p90} min · {share}% of time'**
  String statsStepRow(String n, String p50, String p90, String share);

  /// No description provided for @statsWindow.
  ///
  /// In en, this message translates to:
  /// **'Last {days} days'**
  String statsWindow(String days);

  /// No description provided for @navSituation.
  ///
  /// In en, this message translates to:
  /// **'Situation'**
  String get navSituation;

  /// No description provided for @situationNeedsYou.
  ///
  /// In en, this message translates to:
  /// **'Needs you'**
  String get situationNeedsYou;

  /// No description provided for @situationNothingNeeded.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs you'**
  String get situationNothingNeeded;

  /// No description provided for @situationInfoCount.
  ///
  /// In en, this message translates to:
  /// **'For information: {count}'**
  String situationInfoCount(int count);

  /// No description provided for @situationStaleBanner.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh, showing earlier data'**
  String get situationStaleBanner;

  /// No description provided for @situationActionReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get situationActionReply;

  /// No description provided for @situationActionAddSteps.
  ///
  /// In en, this message translates to:
  /// **'Add steps'**
  String get situationActionAddSteps;

  /// No description provided for @situationActionResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get situationActionResume;

  /// No description provided for @situationActionModels.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get situationActionModels;

  /// No description provided for @situationActionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get situationActionOpen;

  /// No description provided for @situationDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get situationDone;

  /// No description provided for @situationSlots.
  ///
  /// In en, this message translates to:
  /// **'{running} of {slots} slots running, {free} free'**
  String situationSlots(int running, int slots, int free);

  /// No description provided for @situationSlotsWithReason.
  ///
  /// In en, this message translates to:
  /// **'{running} of {slots} slots running, {free} free: {reason}'**
  String situationSlotsWithReason(
    int running,
    int slots,
    int free,
    String reason,
  );

  /// No description provided for @situationUpdated.
  ///
  /// In en, this message translates to:
  /// **'updated {time}'**
  String situationUpdated(String time);

  /// No description provided for @situationPlansTitle.
  ///
  /// In en, this message translates to:
  /// **'Plans in work'**
  String get situationPlansTitle;

  /// No description provided for @situationNoPlans.
  ///
  /// In en, this message translates to:
  /// **'No plans in work'**
  String get situationNoPlans;

  /// No description provided for @situationPriority.
  ///
  /// In en, this message translates to:
  /// **'P{priority}'**
  String situationPriority(int priority);

  /// No description provided for @situationSessions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} session} other{{count} sessions}}'**
  String situationSessions(int count);

  /// No description provided for @situationForMin.
  ///
  /// In en, this message translates to:
  /// **'for {minutes} min'**
  String situationForMin(int minutes);

  /// No description provided for @situationMenuPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get situationMenuPriority;

  /// No description provided for @situationMenuHold.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get situationMenuHold;

  /// No description provided for @situationMenuResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get situationMenuResume;

  /// No description provided for @situationMenuBudget.
  ///
  /// In en, this message translates to:
  /// **'Step budget'**
  String get situationMenuBudget;

  /// No description provided for @situationMenuWrite.
  ///
  /// In en, this message translates to:
  /// **'Write to the plan'**
  String get situationMenuWrite;

  /// No description provided for @situationBuildQueue.
  ///
  /// In en, this message translates to:
  /// **'Build queue'**
  String get situationBuildQueue;

  /// No description provided for @situationWaited.
  ///
  /// In en, this message translates to:
  /// **'waiting {minutes} min'**
  String situationWaited(int minutes);

  /// No description provided for @situationNoBuildWait.
  ///
  /// In en, this message translates to:
  /// **'No one is waiting for a build slot'**
  String get situationNoBuildWait;

  /// No description provided for @situationHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get situationHistory;

  /// No description provided for @situationHours24.
  ///
  /// In en, this message translates to:
  /// **'24 h'**
  String get situationHours24;

  /// No description provided for @situationHours168.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get situationHours168;

  /// No description provided for @situationFreeShare.
  ///
  /// In en, this message translates to:
  /// **'Free slots: {percent}%'**
  String situationFreeShare(int percent);

  /// No description provided for @situationNoData.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get situationNoData;

  /// No description provided for @situationIdleSlotsTitle.
  ///
  /// In en, this message translates to:
  /// **'Idle slots by reason'**
  String get situationIdleSlotsTitle;

  /// No description provided for @situationSlotHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} slot-h'**
  String situationSlotHours(String hours);

  /// No description provided for @situationByPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Time by state'**
  String get situationByPlanTitle;

  /// No description provided for @situationSegment.
  ///
  /// In en, this message translates to:
  /// **'{label} {minutes} min'**
  String situationSegment(String label, int minutes);

  /// No description provided for @situationLongestTitle.
  ///
  /// In en, this message translates to:
  /// **'Longest intervals'**
  String get situationLongestTitle;

  /// No description provided for @situationLongest.
  ///
  /// In en, this message translates to:
  /// **'#{issue} {label} {minutes} min since {time} — {detail}'**
  String situationLongest(
    int issue,
    String label,
    int minutes,
    String time,
    String detail,
  );

  /// No description provided for @situationLongestNoDetail.
  ///
  /// In en, this message translates to:
  /// **'#{issue} {label} {minutes} min since {time}'**
  String situationLongestNoDetail(
    int issue,
    String label,
    int minutes,
    String time,
  );

  /// No description provided for @situationStateWorking.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get situationStateWorking;

  /// No description provided for @situationStateShortOfSlots.
  ///
  /// In en, this message translates to:
  /// **'Short of slots'**
  String get situationStateShortOfSlots;

  /// No description provided for @situationStateBuildWait.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a build slot'**
  String get situationStateBuildWait;

  /// No description provided for @situationStateDraining.
  ///
  /// In en, this message translates to:
  /// **'Round finishing'**
  String get situationStateDraining;

  /// No description provided for @situationStatePlanning.
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get situationStatePlanning;

  /// No description provided for @situationStatePlanningWait.
  ///
  /// In en, this message translates to:
  /// **'Waiting to plan'**
  String get situationStatePlanningWait;

  /// No description provided for @situationStateQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get situationStateQueued;

  /// No description provided for @situationStateCooldown.
  ///
  /// In en, this message translates to:
  /// **'Cooling down'**
  String get situationStateCooldown;

  /// No description provided for @situationStateWaitingMerge.
  ///
  /// In en, this message translates to:
  /// **'Waiting for merge'**
  String get situationStateWaitingMerge;

  /// No description provided for @situationStateWaitingOwner.
  ///
  /// In en, this message translates to:
  /// **'Waiting for you'**
  String get situationStateWaitingOwner;

  /// No description provided for @situationStateBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get situationStateBlocked;

  /// No description provided for @situationStateBudget.
  ///
  /// In en, this message translates to:
  /// **'Step budget used'**
  String get situationStateBudget;

  /// No description provided for @situationStateHeld.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get situationStateHeld;

  /// No description provided for @situationStateFrozen.
  ///
  /// In en, this message translates to:
  /// **'Frozen'**
  String get situationStateFrozen;

  /// No description provided for @situationStateIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get situationStateIdle;

  /// No description provided for @situationStateScheduler.
  ///
  /// In en, this message translates to:
  /// **'Scheduler has not topped up'**
  String get situationStateScheduler;

  /// No description provided for @situationStateNoWork.
  ///
  /// In en, this message translates to:
  /// **'No work'**
  String get situationStateNoWork;

  /// No description provided for @situationKindQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get situationKindQuestion;

  /// No description provided for @situationKindBlocked.
  ///
  /// In en, this message translates to:
  /// **'Plan blocked'**
  String get situationKindBlocked;

  /// No description provided for @situationKindBudget.
  ///
  /// In en, this message translates to:
  /// **'Step budget'**
  String get situationKindBudget;

  /// No description provided for @situationKindHeld.
  ///
  /// In en, this message translates to:
  /// **'Paused plan'**
  String get situationKindHeld;

  /// No description provided for @situationKindBuildWait.
  ///
  /// In en, this message translates to:
  /// **'Build slot wait'**
  String get situationKindBuildWait;

  /// No description provided for @situationKindDisk.
  ///
  /// In en, this message translates to:
  /// **'Disk'**
  String get situationKindDisk;

  /// No description provided for @situationKindHostBusy.
  ///
  /// In en, this message translates to:
  /// **'Build host busy'**
  String get situationKindHostBusy;

  /// No description provided for @situationKindService.
  ///
  /// In en, this message translates to:
  /// **'Service down'**
  String get situationKindService;

  /// No description provided for @situationKindProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider limit'**
  String get situationKindProvider;
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
