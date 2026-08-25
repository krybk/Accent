import 'package:accent/models/server_profile.dart';
import 'package:accent/screens/add_server_screen.dart';
import 'package:accent/services/profile_repository.dart';
import 'package:accent/services/secret_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySecretStore store;
  late ProfileRepository profiles;

  setUp(() {
    store = InMemorySecretStore();
    profiles = ProfileRepository(store);
  });

  const password = 'a-root-password';
  const providerKey = 'sk-or-v1-a-provider-key';

  group('validation', () {
    testWidgets('an empty form is rejected field by field, each named', (
      tester,
    ) async {
      await _openForm(tester, profiles);

      await _fill(tester, AddServerScreen.hostField, '');
      await _fill(tester, AddServerScreen.usernameField, '');
      await _fill(tester, AddServerScreen.portField, '70000');
      await _tapSubmit(tester);

      expect(find.text('Enter the host'), findsOneWidget);
      expect(find.text('Enter the username'), findsOneWidget);
      expect(find.text('Enter the root password'), findsOneWidget);
      expect(find.text('Enter the OpenRouter API key'), findsOneWidget);
      expect(
        find.text('Port must be a number between 1 and 65535'),
        findsOneWidget,
      );
      // Nothing was saved, which is the part that matters: a rejected form must
      // not leave a profile behind for the list to show.
      expect(await profiles.list(), isEmpty);
    });

    testWidgets('a port of zero is out of range', (tester) async {
      await _openForm(tester, profiles);

      await _fillAll(tester, port: '0');
      await _tapSubmit(tester);

      expect(
        find.text('Port must be a number between 1 and 65535'),
        findsOneWidget,
      );
      expect(await profiles.list(), isEmpty);
    });

    testWidgets('65535 is in range', (tester) async {
      await _openForm(tester, profiles);

      await _fillAll(tester, port: '65535');
      await _tapSubmit(tester);

      expect((await profiles.list()).single.port, 65535);
    });
  });

  group('submission', () {
    testWidgets('saves the profile with bootstrapped false', (tester) async {
      await _openForm(tester, profiles);

      await _fillAll(tester);
      await _tapSubmit(tester);

      final saved = (await profiles.list()).single;
      expect(saved.name, 'Home server');
      expect(saved.host, '192.0.2.10');
      expect(saved.username, 'root');
      expect(saved.port, 2222);
      // The profile exists before anything is deployed. That is what makes an
      // interrupted bootstrap resumable, and what the flag is for.
      expect(saved.bootstrapped, isFalse);
      expect(saved.id, isNotEmpty);
    });

    testWidgets('the id is generated, not derived from host or name', (
      tester,
    ) async {
      await _openForm(tester, profiles);
      await _fillAll(tester);
      await _tapSubmit(tester);

      final id = (await profiles.list()).single.id;
      // Deriving it would orphan every secret filed under it the first time
      // someone renames or re-addresses the server.
      expect(id, isNot(contains('192.0.2.10')));
      expect(id.toLowerCase(), isNot(contains('home')));
    });

    testWidgets('the name falls back to the host when left blank', (
      tester,
    ) async {
      await _openForm(tester, profiles);

      await _fillAll(tester, name: '');
      await _tapSubmit(tester);

      expect((await profiles.list()).single.name, '192.0.2.10');
    });

    testWidgets('hands the password and the provider key to the caller', (
      tester,
    ) async {
      final handedBack = await _openForm(tester, profiles);

      await _fillAll(tester);
      await _tapSubmit(tester);

      final created = handedBack.single;
      expect(created, isNotNull);
      expect(created!.profile.host, '192.0.2.10');
      // Still held: releasing it is the bootstrap's job, at the stage where the
      // key has been proven to work.
      expect(created.password.released, isFalse);
      expect(created.password.value, password);
      expect(created.openRouterApiKey, providerKey);
    });

    testWidgets('returns null when the form is left instead of submitted', (
      tester,
    ) async {
      final handedBack = await _openForm(tester, profiles);

      await _fillAll(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(handedBack.single, isNull);
      expect(await profiles.list(), isEmpty);
    });
  });

  group('secret hygiene', () {
    testWidgets('neither secret reaches the profile or the store', (
      tester,
    ) async {
      await _openForm(tester, profiles);

      await _fillAll(tester);
      await _tapSubmit(tester);

      final saved = (await profiles.list()).single;
      final json = ServerProfile.encodeList([saved]);
      expect(json, isNot(contains(password)));
      expect(json, isNot(contains(providerKey)));
      expect(saved.toString(), isNot(contains(password)));

      // The form saves the profile and nothing else. The provider key is stored
      // by the bootstrap's last stage, once there is a stack that uses it, so a
      // form that was submitted and never deployed leaves no billable key on the
      // device.
      expect(await profiles.providerKey(saved.id), isNull);
      expect(store.keys, ['profiles']);
    });

    testWidgets('neither secret appears in any widget after submission', (
      tester,
    ) async {
      final handedBack = await _openForm(tester, profiles);

      await _fillAll(tester);
      await _tapSubmit(tester);

      final rendered = _renderedText(tester);
      expect(rendered, isNot(contains(password)));
      expect(rendered, isNot(contains(providerKey)));
      // No snackbar either — the confirmation someone would reasonably write is
      // exactly the place a password should not be.
      expect(find.byType(SnackBar), findsNothing);
      // The values did survive the trip to the caller, so this is not passing by
      // having lost them.
      expect(handedBack.single?.openRouterApiKey, providerKey);
    });

    testWidgets('the password field is obscured while it is being typed', (
      tester,
    ) async {
      await _openForm(tester, profiles);

      await _fillAll(tester);
      await tester.pump();

      for (final key in [
        AddServerScreen.passwordField,
        AddServerScreen.providerKeyField,
      ]) {
        final field = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(TextField),
          ),
        );
        expect(field.obscureText, isTrue);
      }
    });

    testWidgets('NewServer describes itself without revealing anything', (
      tester,
    ) async {
      final handedBack = await _openForm(tester, profiles);

      await _fillAll(tester);
      await _tapSubmit(tester);

      final text = handedBack.single.toString();
      expect(text, isNot(contains(password)));
      expect(text, isNot(contains(providerKey)));
    });
  });
}

/// Opens the form the way `ServersScreen` does, and records what it hands back.
///
/// A pushed route rather than a bare `pumpWidget`, because returning the new
/// server to its caller instead of navigating onward is half of what this screen
/// is for. The returned list holds one entry per closed route.
Future<List<NewServer?>> _openForm(
  WidgetTester tester,
  ProfileRepository profiles,
) async {
  final handedBack = <NewServer?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => handedBack.add(
              await Navigator.of(context).push<NewServer>(
                MaterialPageRoute(
                  builder: (_) => AddServerScreen(profiles: profiles),
                ),
              ),
            ),
            child: const Text('Open the form'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open the form'));
  await tester.pumpAndSettle();
  return handedBack;
}

Future<void> _fill(WidgetTester tester, Key field, String value) async {
  await tester.enterText(find.byKey(field), value);
  await tester.pump();
}

/// A form that would be accepted, unless one field is overridden to something
/// that would not.
Future<void> _fillAll(
  WidgetTester tester, {
  String name = 'Home server',
  String host = '192.0.2.10',
  String port = '2222',
  String username = 'root',
  String password = 'a-root-password',
  String providerKey = 'sk-or-v1-a-provider-key',
}) async {
  await _fill(tester, AddServerScreen.nameField, name);
  await _fill(tester, AddServerScreen.hostField, host);
  await _fill(tester, AddServerScreen.portField, port);
  await _fill(tester, AddServerScreen.usernameField, username);
  await _fill(tester, AddServerScreen.passwordField, password);
  await _fill(tester, AddServerScreen.providerKeyField, providerKey);
}

/// The button is below the fold on a test-sized screen, so it has to be scrolled
/// to before it can be tapped.
Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(AddServerScreen.submitButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(AddServerScreen.submitButton));
  await tester.pumpAndSettle();
}

/// Every string the tree is currently showing, including the ones held by text
/// fields — a secret typed into a field is as visible as one in a label.
List<String> _renderedText(WidgetTester tester) => [
  ...tester
      .widgetList<Text>(find.byType(Text, skipOffstage: false))
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? ''),
  ...tester
      .widgetList<EditableText>(find.byType(EditableText, skipOffstage: false))
      .map((editable) => editable.controller.text),
];
