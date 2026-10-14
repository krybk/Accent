// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get languageName => 'Русский';

  @override
  String get languageSystem => 'Системный';

  @override
  String get languageMenuTooltip => 'Язык';

  @override
  String get serversTitle => 'Серверы';

  @override
  String get addServerTooltip => 'Добавить сервер';

  @override
  String get serverBootstrapped => 'Настроен';

  @override
  String get serverNotBootstrapped => 'Не настроен';

  @override
  String get serversLoadFailed => 'Не удалось прочитать сохранённые серверы';

  @override
  String get tryAgain => 'Повторить';

  @override
  String get serversEmptyTitle => 'Серверов пока нет';

  @override
  String get serversEmptyHint =>
      'Добавьте сервер, чтобы развернуть на нём стек и начать чат.';

  @override
  String get addServerTitle => 'Новый сервер';

  @override
  String get fieldName => 'Название';

  @override
  String get fieldNameHelper =>
      'Необязательно — если оставить пустым, будет использован хост';

  @override
  String get fieldHost => 'Хост';

  @override
  String get fieldHostHint => 'name.example.com или 192.0.2.10';

  @override
  String get fieldPort => 'SSH-порт';

  @override
  String get fieldUsername => 'Имя пользователя';

  @override
  String get sectionOneTimeSecrets =>
      'Используется один раз и нигде не сохраняется';

  @override
  String get fieldRootPassword => 'Пароль root';

  @override
  String get fieldRootPasswordHelper =>
      'С его помощью при настройке устанавливается ключ, после чего пароль забывается';

  @override
  String get fieldProviderKey => 'API-ключ Anthropic';

  @override
  String get fieldProviderKeyHelper => 'Без него стек не запустится';

  @override
  String get errorEnterHost => 'Укажите хост';

  @override
  String get errorEnterUsername => 'Укажите имя пользователя';

  @override
  String get errorEnterRootPassword => 'Укажите пароль root';

  @override
  String get errorEnterProviderKey => 'Укажите API-ключ Anthropic';

  @override
  String get errorPortRange => 'Порт должен быть числом от 1 до 65535';

  @override
  String errorSaveFailed(String error) {
    return 'Не удалось сохранить сервер: $error';
  }

  @override
  String get saving => 'Сохранение…';

  @override
  String get saveServer => 'Сохранить сервер';

  @override
  String get navPlane => 'Панель';

  @override
  String get navUsage => 'Расход';

  @override
  String get planeSectionPlans => 'Планы';

  @override
  String get planeSectionProviders => 'Провайдеры';

  @override
  String get planeSectionServices => 'Службы';

  @override
  String get planeSectionPaused => 'Приостановленные модели';

  @override
  String get planeSectionActions => 'Быстрые действия';

  @override
  String get planeNoPlans => 'Планов нет';

  @override
  String get providerCurrent => 'текущий';

  @override
  String get providerNoKey => 'нет ключа';

  @override
  String providerCooling(String until, String reason) {
    return 'пауза до $until — $reason';
  }

  @override
  String get pausedIndefinitely => 'бессрочно';

  @override
  String get actionArgPrompt => 'Введите число';

  @override
  String get actionRun => 'Выполнить';

  @override
  String actionExitCode(int code) {
    return 'Код завершения $code';
  }

  @override
  String get usageToday => 'Сегодня';

  @override
  String get usage7d => '7 дней';

  @override
  String get usage30d => '30 дней';

  @override
  String get usageSteps => 'Шаги';

  @override
  String get usageCost => 'Стоимость';

  @override
  String get usageInput => 'Вход';

  @override
  String get usageOutput => 'Выход';

  @override
  String get usageCacheRead => 'Чтение кэша';

  @override
  String get usageCacheWrite => 'Запись в кэш';

  @override
  String usageUntracked(int count) {
    return 'Шагов до учёта токенов: $count';
  }

  @override
  String get usageRoles => 'Роли';

  @override
  String get usageRoleChat => 'Чат';

  @override
  String usageGeneratedAt(String time) {
    return 'Сформировано $time';
  }

  @override
  String get gatewayErrorTopUp =>
      'Баланс провайдера модели исчерпан — пополните его, чтобы продолжить';

  @override
  String get gatewayErrorUnauthorized => 'Шлюз отклонил токен';

  @override
  String get gatewayErrorNoPlane =>
      'На этом сервере не настроена панель управления';

  @override
  String get gatewayErrorPlaneDown => 'Панель управления не отвечает';

  @override
  String get gatewayErrorUnreachable => 'Не удалось связаться с сервером';

  @override
  String get gatewayErrorNoCredentials =>
      'Для этого сервера не сохранены данные шлюза — разверните его заново';

  @override
  String gatewayErrorOther(String code, String message) {
    return '$code: $message';
  }

  @override
  String get bootstrapTitle => 'Развёртывание стека';

  @override
  String get bootstrapDone => 'Сервер готов';

  @override
  String get bootstrapFailed => 'Развёртывание не удалось';

  @override
  String get bootstrapClose => 'Закрыть';

  @override
  String get bootstrapFinish => 'Готово';

  @override
  String get bootstrapStageConnect => 'Подключение по паролю';

  @override
  String get bootstrapStageInstallKey => 'Установка SSH-ключа';

  @override
  String get bootstrapStageKeyOnlyConnect =>
      'Проверка входа по ключу без пароля';

  @override
  String get bootstrapStageInstallDocker => 'Установка Docker';

  @override
  String get bootstrapStageCheckout => 'Загрузка исходников стека';

  @override
  String get bootstrapStageWriteEnvironment => 'Запись конфигурации шлюза';

  @override
  String get bootstrapStageStartStack => 'Запуск стека';

  @override
  String get bootstrapStageAwaitHealth => 'Ожидание ответа стека';

  @override
  String get bootstrapStageReadCertificate => 'Чтение сертификата';

  @override
  String get bootstrapStageStoreCredentials => 'Сохранение учётных данных';

  @override
  String get navChat => 'Чат';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get chatInputHint => 'Сообщение';

  @override
  String get chatSend => 'Отправить';

  @override
  String get chatNewConversation => 'Новый разговор';

  @override
  String get chatTierOpus => 'Opus';

  @override
  String get chatTierSonnet => 'Sonnet';

  @override
  String get chatEmpty => 'Спросите, что сейчас делается и почему';

  @override
  String chatDoneCaption(String model, String input, String output) {
    return '$model · $input вход · $output выход';
  }

  @override
  String chatErrorRefused(String message) {
    return 'Модель отказала: $message';
  }

  @override
  String get chatErrorBusy =>
      'Другой ответ чата ещё идёт — дождитесь его окончания';

  @override
  String get chatErrorNoProvider => 'Для чата нет доступного провайдера модели';

  @override
  String get chatErrorTimeout => 'Ответ шёл слишком долго и был остановлен';

  @override
  String chatErrorFailed(String message) {
    return 'Чат завершился ошибкой: $message';
  }

  @override
  String get chatErrorSwitched => 'Модель была отключена — отправьте ещё раз';

  @override
  String get chatErrorTooLong => 'Сообщение слишком длинное';

  @override
  String get sendToPlan => 'Отправить в план';

  @override
  String get sendToPlanTitle => 'Указание плану';

  @override
  String get sendToPlanPlan => 'План';

  @override
  String get sendToPlanText => 'Текст';

  @override
  String get sendToPlanSend => 'Отправить';

  @override
  String get sendToPlanNoPlan => 'Нет открытого плана';

  @override
  String sendToPlanSent(String url) {
    return 'Отправлено: $url';
  }

  @override
  String get sendToPlanCredential => 'Текст похож на секрет и не был отправлен';

  @override
  String get sendToPlanNoSuchPlan => 'Этого плана больше нет';

  @override
  String get sendToPlanCommentFailed => 'Сервер не смог опубликовать указание';

  @override
  String get modelsTitle => 'Модели';

  @override
  String modelOff(String standIn, String standInModel) {
    return 'Выключена — работает $standIn ($standInModel)';
  }

  @override
  String get modelOffNoStandIn => 'Выключена';

  @override
  String modelOffUntil(String until) {
    return 'до $until';
  }

  @override
  String modelDisableTitle(String tier) {
    return 'Выключить $tier?';
  }

  @override
  String get modelDisableBody =>
      'Идущая работа сохраняется и продолжается на замещающей модели.';

  @override
  String get modelDisableConfirm => 'Выключить';

  @override
  String get modelErrorLastModel =>
      'Это последняя включённая модель, её нельзя выключить';

  @override
  String get modelErrorNoSuchTier => 'Сервер не знает эту модель';

  @override
  String get navQueue => 'Очередь';

  @override
  String get queueOrderNote => 'Планы берутся в работу в этом порядке.';

  @override
  String get queueEmpty => 'Открытых планов нет';

  @override
  String get queueHeld => 'Отложен';

  @override
  String get queueMoveUp => 'Поднять';

  @override
  String get queueMoveDown => 'Опустить';

  @override
  String get queueMoveTop => 'В начало';

  @override
  String get queueMoveBottom => 'В конец';

  @override
  String get queueHold => 'Отложить';

  @override
  String get queueResume => 'Вернуть в очередь';

  @override
  String get queueErrorNoSuchPlan => 'Этот план уже закрыт';
}
