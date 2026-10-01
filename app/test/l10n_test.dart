import 'dart:convert';
import 'dart:io';

import 'package:accent/locale_controller.dart';
import 'package:accent/main.dart';
import 'package:accent/services/profile_repository.dart';
import 'package:accent/services/secret_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('en and ru ARB files have the same keys', () {
    Set<String> keysOf(String path) {
      final json = jsonDecode(File(path).readAsStringSync()) as Map;
      return json.keys
          .cast<String>()
          .where((key) => !key.startsWith('@'))
          .toSet();
    }

    expect(keysOf('lib/l10n/app_en.arb'), keysOf('lib/l10n/app_ru.arb'));
  });

  testWidgets('language menu switches from Russian to English', (tester) async {
    SharedPreferences.setMockInitialValues({'app.locale': 'ru'});
    final controller = LocaleController();
    await controller.load();

    await tester.pumpWidget(
      AccentApp(
        profiles: ProfileRepository(InMemorySecretStore()),
        localeController: controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Серверы'), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(find.text('Servers'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString('app.locale'),
      'en',
    );
  });
}
