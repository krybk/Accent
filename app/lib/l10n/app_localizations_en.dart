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
  String get fieldProviderKey => 'Anthropic API key (optional)';

  @override
  String get fieldProviderKeyHelper =>
      'Not needed for chat, which goes through the control plane. Only the stack\'s own /v1/chat uses it.';

  @override
  String get errorEnterHost => 'Enter the host';

  @override
  String get errorEnterUsername => 'Enter the username';

  @override
  String get errorEnterRootPassword => 'Enter the root password';

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
  String planeSliceOf(int slice, int total) {
    return 'Stage $slice of $total';
  }

  @override
  String planeSlice(int slice) {
    return 'Stage $slice';
  }

  @override
  String planeSliceNow(int slice) {
    return 'Stage $slice — now';
  }

  @override
  String planeSliceDone(int slice, int done, int total) {
    return 'Stage $slice — $done of $total tasks done';
  }

  @override
  String get planeLater => 'Later stages';

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
  String get bootstrapStageDiscover =>
      'Looking at what the server already runs';

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
  String get bootstrapStageIssueToken => 'Issuing this app a token';

  @override
  String get bootstrapStageReadCertificate => 'Reading the certificate';

  @override
  String get bootstrapStageStoreCredentials => 'Storing the credentials';

  @override
  String get bootstrapStageSkipped => 'Skipped: the server already runs it';

  @override
  String get discoveryExistingGateway =>
      'Found a running Accent gateway: connecting to it, nothing will be rebuilt';

  @override
  String get discoveryPlaneOnly =>
      'Found a control plane without a gateway: installing only the gateway';

  @override
  String get discoveryNothing => 'Nothing found: deploying the stack';

  @override
  String get navChat => 'Chat';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get chatInputHint => 'Message';

  @override
  String get chatSend => 'Send';

  @override
  String get chatNewConversation => 'New conversation';

  @override
  String get chatTierOpus => 'Opus';

  @override
  String get chatTierSonnet => 'Sonnet';

  @override
  String get chatEmpty => 'Ask what is being done now and why';

  @override
  String chatDoneCaption(String model, String input, String output) {
    return '$model · $input in · $output out';
  }

  @override
  String chatErrorRefused(String message) {
    return 'The model refused: $message';
  }

  @override
  String get chatErrorBusy =>
      'Another chat answer is still running — wait for it to finish';

  @override
  String get chatErrorNoProvider =>
      'No model provider is available for the chat';

  @override
  String get chatErrorTimeout => 'The answer took too long and was stopped';

  @override
  String chatErrorFailed(String message) {
    return 'The chat failed: $message';
  }

  @override
  String get chatErrorSwitched => 'The model was switched off — send again';

  @override
  String get chatErrorTooLong => 'The message is too long';

  @override
  String get sendToPlan => 'Send to plan';

  @override
  String get sendToPlanTitle => 'Guidance for a plan';

  @override
  String get sendToPlanPlan => 'Plan';

  @override
  String get sendToPlanText => 'Text';

  @override
  String get sendToPlanSend => 'Send';

  @override
  String get sendToPlanNoPlan => 'There is no open plan';

  @override
  String sendToPlanSent(String url) {
    return 'Sent: $url';
  }

  @override
  String get sendToPlanCredential =>
      'The text looks like a credential and was not sent';

  @override
  String get sendToPlanNoSuchPlan => 'This plan no longer exists';

  @override
  String get sendToPlanCommentFailed =>
      'The server could not post the guidance';

  @override
  String get modelsTitle => 'Models';

  @override
  String modelOff(String standIn, String standInModel) {
    return 'Off — running on $standIn ($standInModel)';
  }

  @override
  String get modelOffNoStandIn => 'Off';

  @override
  String modelOffUntil(String until) {
    return 'until $until';
  }

  @override
  String modelDisableTitle(String tier) {
    return 'Switch $tier off?';
  }

  @override
  String get modelDisableBody =>
      'Running work is saved and continues on the stand-in model.';

  @override
  String get modelDisableConfirm => 'Switch off';

  @override
  String get modelErrorLastModel =>
      'This is the last model that is on; it cannot be switched off';

  @override
  String get modelErrorNoSuchTier => 'The server does not know this model';

  @override
  String get navQueue => 'Queue';

  @override
  String get queueOrderNote => 'Plans are taken in this order.';

  @override
  String get queueEmpty => 'No open plans';

  @override
  String get queueHeld => 'On hold';

  @override
  String get queueMoveUp => 'Move up';

  @override
  String get queueMoveDown => 'Move down';

  @override
  String get queueMoveTop => 'Move to top';

  @override
  String get queueMoveBottom => 'Move to end';

  @override
  String get queueHold => 'Put on hold';

  @override
  String get queueResume => 'Return to queue';

  @override
  String get queueErrorNoSuchPlan => 'This plan is no longer open';

  @override
  String get navCapacity => 'Load';

  @override
  String get navStats => 'Stats';

  @override
  String queuePriority(int priority) {
    return 'Priority $priority';
  }

  @override
  String queueSteps(int spent, int limit) {
    return 'Steps $spent of $limit';
  }

  @override
  String get queueSetPriority => 'Set priority';

  @override
  String get queueSetBudget => 'Set step limit';

  @override
  String get queuePriorityTitle => 'Priority (1 goes first)';

  @override
  String get queueDefault => 'Default';

  @override
  String get queueBudgetTitle => 'Step limit';

  @override
  String queueBudgetHelp(int spent) {
    return '$spent spent. From 1 to 100000.';
  }

  @override
  String get queueBudgetSave => 'Save';

  @override
  String get valueUnknown => '—';

  @override
  String capacitySlots(String slots, String running) {
    return 'Agent slots: $slots, running: $running';
  }

  @override
  String get capacityServer => 'This server';

  @override
  String capacityCpu(String pct) {
    return 'CPU: $pct%';
  }

  @override
  String capacityMemory(String pct, String free, String total) {
    return 'Memory: $pct% ($free of $total MB free)';
  }

  @override
  String capacityDisk(String pct, String free) {
    return 'Disk: $pct% ($free GB free)';
  }

  @override
  String capacityCores(String cores) {
    return 'Cores: $cores';
  }

  @override
  String get capacityHostUnreachable => 'Not reachable';

  @override
  String get capacitySubscription => 'Subscription';

  @override
  String capacityWindow(String window, String used, String pct, String burn) {
    return '$window: $used tokens ($pct%), $burn per hour';
  }

  @override
  String get capacitySlotsByPlan => 'Slots by plan';

  @override
  String capacityPlanSlots(String plan, String slots) {
    return 'Plan #$plan: $slots slots';
  }

  @override
  String get capacityPlanned => 'Planned load';

  @override
  String capacityPlannedRow(
    String plan,
    String repo,
    String width,
    String mem,
    String cores,
  ) {
    return '#$plan $repo: $width sessions, $mem MB, $cores cores';
  }

  @override
  String capacityPlannedTotal(String sessions, String mem, String cores) {
    return 'Total: $sessions sessions, $mem MB, $cores cores';
  }

  @override
  String get statsForecast => 'Forecast';

  @override
  String statsProgress(String pct) {
    return 'Requirements done: $pct%';
  }

  @override
  String statsTasksLeft(String left, String total) {
    return 'Tasks left in this slice: $left of $total';
  }

  @override
  String statsEta(String hours) {
    return 'At the current pace: $hours h';
  }

  @override
  String get statsByKind => 'By sphere and kind';

  @override
  String statsGroupRow(
    String tasks,
    String wall,
    String work,
    String opus,
    String sonnet,
  ) {
    return '$tasks tasks · $wall min wall · $work min work · Opus $opus / Sonnet $sonnet tokens';
  }

  @override
  String statsGroupResources(String mem, String cores, String gates) {
    return 'Session memory p90 $mem MB · cores p75 $cores · gates p50 $gates min';
  }

  @override
  String get statsBySteps => 'By step';

  @override
  String statsStepRow(String n, String p50, String p90, String share) {
    return '$n runs · p50 $p50 min · p90 $p90 min · $share% of time';
  }

  @override
  String statsWindow(String days) {
    return 'Last $days days';
  }
}
