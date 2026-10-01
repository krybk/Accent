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
}
