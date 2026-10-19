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
  String get fieldProviderKey => 'Ключ Anthropic API (необязательно)';

  @override
  String get fieldProviderKeyHelper =>
      'Для чата не нужен: он идёт через панель управления. Нужен только для /v1/chat самого стека.';

  @override
  String get errorEnterHost => 'Укажите хост';

  @override
  String get errorEnterUsername => 'Укажите имя пользователя';

  @override
  String get errorEnterRootPassword => 'Укажите пароль root';

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
  String planeSliceOf(int slice, int total) {
    return 'Этап $slice из $total';
  }

  @override
  String planeSlice(int slice) {
    return 'Этап $slice';
  }

  @override
  String planeSliceNow(int slice) {
    return 'Этап $slice — сейчас';
  }

  @override
  String planeSliceDone(int slice, int done, int total) {
    return 'Этап $slice — готово $done из $total задач';
  }

  @override
  String get planeLater => 'Следующие этапы';

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
  String get bootstrapStageDiscover =>
      'Изучение того, что уже работает на сервере';

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
  String get bootstrapStageIssueToken => 'Выдача токена этому приложению';

  @override
  String get bootstrapStageReadCertificate => 'Чтение сертификата';

  @override
  String get bootstrapStageStoreCredentials => 'Сохранение учётных данных';

  @override
  String get bootstrapStageSkipped => 'Пропущено: на сервере это уже есть';

  @override
  String get discoveryExistingGateway =>
      'Найден работающий шлюз Accent: подключаемся к нему, ничего не пересобираем';

  @override
  String get discoveryPlaneOnly =>
      'Найдена панель управления без шлюза: ставим только шлюз';

  @override
  String get discoveryNothing => 'Ничего не найдено: разворачиваем стек';

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

  @override
  String get navCapacity => 'Загрузка';

  @override
  String get navStats => 'Статистика';

  @override
  String queuePriority(int priority) {
    return 'Важность $priority';
  }

  @override
  String queueSteps(int spent, int limit) {
    return 'Шаги: $spent из $limit';
  }

  @override
  String get queueSetPriority => 'Задать важность';

  @override
  String get queueSetBudget => 'Задать лимит шагов';

  @override
  String get queuePriorityTitle => 'Важность (1 — первым)';

  @override
  String get queueDefault => 'По умолчанию';

  @override
  String get queueBudgetTitle => 'Лимит шагов';

  @override
  String queueBudgetHelp(int spent) {
    return 'Потрачено: $spent. От 1 до 100000.';
  }

  @override
  String get queueBudgetSave => 'Сохранить';

  @override
  String get valueUnknown => '—';

  @override
  String capacitySlots(String slots, String running) {
    return 'Слоты агентов: $slots, занято: $running';
  }

  @override
  String get capacityServer => 'Этот сервер';

  @override
  String capacityCpu(String pct) {
    return 'ЦП: $pct%';
  }

  @override
  String capacityMemory(String pct, String free, String total) {
    return 'Память: $pct% (свободно $free из $total МБ)';
  }

  @override
  String capacityDisk(String pct, String free) {
    return 'Диск: $pct% (свободно $free ГБ)';
  }

  @override
  String capacityCores(String cores) {
    return 'Ядер: $cores';
  }

  @override
  String get capacityHostUnreachable => 'Недоступен';

  @override
  String get capacitySubscription => 'Подписка';

  @override
  String capacityWindow(String window, String used, String pct, String burn) {
    return '$window: $used токенов ($pct%), $burn в час';
  }

  @override
  String get capacitySlotsByPlan => 'Слоты по планам';

  @override
  String capacityPlanSlots(String plan, String slots) {
    return 'План #$plan: слотов $slots';
  }

  @override
  String get capacityPlanned => 'Плановая нагрузка';

  @override
  String capacityPlannedRow(
    String plan,
    String repo,
    String width,
    String mem,
    String cores,
  ) {
    return '#$plan $repo: сессий $width, $mem МБ, ядер $cores';
  }

  @override
  String capacityPlannedTotal(String sessions, String mem, String cores) {
    return 'Всего: сессий $sessions, $mem МБ, ядер $cores';
  }

  @override
  String get statsForecast => 'Прогноз';

  @override
  String statsProgress(String pct) {
    return 'Требования выполнены: $pct%';
  }

  @override
  String statsTasksLeft(String left, String total) {
    return 'Задач в срезе осталось: $left из $total';
  }

  @override
  String statsEta(String hours) {
    return 'При текущем темпе: $hours ч';
  }

  @override
  String get statsByKind => 'По сферам и типам';

  @override
  String statsGroupRow(
    String tasks,
    String wall,
    String work,
    String opus,
    String sonnet,
  ) {
    return 'задач $tasks · $wall мин всего · $work мин работы · токены Opus $opus / Sonnet $sonnet';
  }

  @override
  String statsGroupResources(String mem, String cores, String gates) {
    return 'Память сессии p90 $mem МБ · ядра p75 $cores · гейты p50 $gates мин';
  }

  @override
  String get statsBySteps => 'По шагам';

  @override
  String statsStepRow(String n, String p50, String p90, String share) {
    return 'запусков $n · p50 $p50 мин · p90 $p90 мин · $share% времени';
  }

  @override
  String statsWindow(String days) {
    return 'За последние $days дн.';
  }
}
