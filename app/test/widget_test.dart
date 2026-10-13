import 'dart:convert';

import 'package:accent/locale_controller.dart';
import 'package:accent/main.dart';
import 'package:accent/models/server_profile.dart';
import 'package:accent/screens/add_server_screen.dart';
import 'package:accent/screens/bootstrap_screen.dart';
import 'package:accent/screens/server_home_screen.dart';
import 'package:accent/screens/servers_screen.dart';
import 'package:accent/services/gateway_client.dart';
import 'package:accent/services/profile_repository.dart';
import 'package:accent/services/secret_store.dart';
import 'package:accent/services/ssh_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late ProfileRepository profiles;

  setUp(() => profiles = ProfileRepository(InMemorySecretStore()));

  /// The whole app over an in-memory store. The repository is a parameter for
  /// exactly this reason: the Keystore lives behind a platform channel and would
  /// make every one of these tests need a device.
  Future<void> pumpApp(
    WidgetTester tester, {
    BootstrapRunner? bootstrapRunner,
    GatewayClientFactory? gatewayClients,
  }) async {
    await tester.pumpWidget(
      AccentApp(
        profiles: profiles,
        localeController: LocaleController(),
        bootstrapRunner: bootstrapRunner,
        gatewayClients: gatewayClients,
      ),
    );
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
    // Tall enough that the bootstrap screen's lazy list builds its last rows.
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      bootstrapRunner: (server) async* {
        yield const BootstrapStageStarted(BootstrapStage.connect);
        yield const BootstrapStageFailed(BootstrapStage.connect, 'refused');
      },
    );

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
      'sk-ant-a-provider-key',
    );
    await tester.ensureVisible(find.byKey(AddServerScreen.submitButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AddServerScreen.submitButton));
    await tester.pumpAndSettle();

    expect(find.text('The bootstrap failed'), findsOneWidget);
    await tester.tap(find.byKey(BootstrapScreen.closeButton));
    await tester.pumpAndSettle();

    // Back on the list, which has re-read the store rather than been told what
    // to add.
    expect(find.text('Servers'), findsOneWidget);
    expect(find.text('New server'), findsOneWidget);
    expect(find.text('root@192.0.2.20:22'), findsOneWidget);
    expect(find.text('Not bootstrapped'), findsOneWidget);

    // Nothing the list shows, and nothing it kept, carries either secret. The
    // secrets went only to the bootstrap runner.
    expect(find.textContaining('a-root-password'), findsNothing);
    expect(find.textContaining('sk-ant-'), findsNothing);
    expect(
      await profiles.providerKey((await profiles.list()).single.id),
      isNull,
    );
  });

  testWidgets('a bootstrapped server opens its home with the plane', (
    tester,
  ) async {
    await profiles.save(
      const ServerProfile(
        id: 'srv_1',
        name: 'Deployed',
        host: '192.0.2.10',
        username: 'root',
        bootstrapped: true,
      ),
    );
    Future<http.Response> handler(http.Request r) async {
      final body = switch (r.url.path) {
        '/v1/plane/plans' => {'plans': []},
        '/v1/plane/status' => {
          'generated_at': '2026-10-13T09:00:00Z',
          'providers': [],
          'services': [],
          'paused': [],
        },
        '/v1/plane/actions' => {'actions': []},
        '/v1/plane/usage' => {
          'generated_at': '2026-10-13T09:00:00Z',
          'models': [],
          'roles': [],
        },
        _ => null,
      };
      if (body == null) return http.Response('{}', 404);
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    await pumpApp(
      tester,
      gatewayClients: (profile) async => GatewayClient(
        baseUri: profile.gatewayUri,
        token: 't',
        httpClient: MockClient(handler),
      ),
    );

    await tester.tap(find.text('Deployed'));
    await tester.pumpAndSettle();

    expect(find.byType(ServerHomeScreen), findsOneWidget);
    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('Providers'), findsOneWidget);
    expect(find.text('Services'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('No plans'), findsOneWidget);
  });

  testWidgets('a row that is not bootstrapped does not open a home', (
    tester,
  ) async {
    await profiles.save(
      const ServerProfile(
        id: 'srv_2',
        name: 'Only added',
        host: '192.0.2.11',
        username: 'root',
      ),
    );
    await pumpApp(tester);

    await tester.tap(find.text('Only added'));
    await tester.pumpAndSettle();

    expect(find.byType(ServerHomeScreen), findsNothing);
  });
}
