import 'package:accent/main.dart';
import 'package:accent/models/server_profile.dart';
import 'package:accent/screens/add_server_screen.dart';
import 'package:accent/screens/servers_screen.dart';
import 'package:accent/services/profile_repository.dart';
import 'package:accent/services/secret_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProfileRepository profiles;

  setUp(() => profiles = ProfileRepository(InMemorySecretStore()));

  /// The whole app over an in-memory store. The repository is a parameter for
  /// exactly this reason: the Keystore lives behind a platform channel and would
  /// make every one of these tests need a device.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(AccentApp(profiles: profiles));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state when no servers are configured', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Servers'), findsOneWidget);
    expect(find.text('No servers yet'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('a stored profile appears in the list, address and all', (
    tester,
  ) async {
    await profiles.save(
      const ServerProfile(
        id: 'srv_1',
        name: 'Home server',
        host: '192.0.2.10',
        username: 'root',
        port: 2222,
      ),
    );

    await pumpApp(tester);

    expect(find.text('No servers yet'), findsNothing);
    expect(find.text('Home server'), findsOneWidget);
    expect(find.text('root@192.0.2.10:2222'), findsOneWidget);
  });

  testWidgets('each row says whether that server is bootstrapped', (
    tester,
  ) async {
    // The point of the test: two profiles that look alike are how someone ends
    // up debugging a chat screen that was never going to connect.
    await profiles.save(
      const ServerProfile(
        id: 'srv_1',
        name: 'Deployed',
        host: '192.0.2.10',
        username: 'root',
        bootstrapped: true,
      ),
    );
    await profiles.save(
      const ServerProfile(
        id: 'srv_2',
        name: 'Only added',
        host: '192.0.2.11',
        username: 'root',
      ),
    );

    await pumpApp(tester);

    expect(find.text('Bootstrapped'), findsOneWidget);
    expect(find.text('Not bootstrapped'), findsOneWidget);
  });

  testWidgets('the add button opens the form rather than a snackbar', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(ServersScreen.addButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AddServerScreen.hostField), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('not ready yet'), findsNothing);
  });

  testWidgets('a server added through the form shows up in the list', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(ServersScreen.addButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(AddServerScreen.nameField), 'New server');
    await tester.enterText(find.byKey(AddServerScreen.hostField), '192.0.2.20');
    await tester.enterText(find.byKey(AddServerScreen.usernameField), 'root');
    await tester.enterText(
      find.byKey(AddServerScreen.passwordField),
      'a-root-password',
    );
    await tester.enterText(
      find.byKey(AddServerScreen.providerKeyField),
      'sk-or-v1-a-provider-key',
    );
    await tester.ensureVisible(find.byKey(AddServerScreen.submitButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AddServerScreen.submitButton));
    await tester.pumpAndSettle();

    // Back on the list, which has re-read the store rather than been told what
    // to add.
    expect(find.text('Servers'), findsOneWidget);
    expect(find.text('New server'), findsOneWidget);
    expect(find.text('root@192.0.2.20:22'), findsOneWidget);
    expect(find.text('Not bootstrapped'), findsOneWidget);

    // Nothing the list shows, and nothing it kept, carries either secret. This
    // screen does not start the bootstrap — that is the next task — so it drops
    // both the moment the form hands them over.
    expect(find.textContaining('a-root-password'), findsNothing);
    expect(find.textContaining('sk-or-v1'), findsNothing);
    expect(
      await profiles.providerKey((await profiles.list()).single.id),
      isNull,
    );
  });
}
