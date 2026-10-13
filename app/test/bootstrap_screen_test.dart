import 'package:accent/l10n/app_localizations.dart';
import 'package:accent/models/server_profile.dart';
import 'package:accent/screens/add_server_screen.dart';
import 'package:accent/screens/bootstrap_screen.dart';
import 'package:accent/services/ssh_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

NewServer _server() => NewServer(
  profile: const ServerProfile(
    id: 'srv_1',
    name: 'Test',
    host: '192.0.2.10',
    username: 'root',
  ),
  password: RootPassword('password-for-tests'),
  anthropicApiKey: 'provider-key-for-tests',
);

Widget _app(BootstrapRunner runner, {Widget? home}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: home ?? BootstrapScreen(server: _server(), run: runner),
);

Stream<BootstrapEvent> _failingInstallDocker(NewServer server) async* {
  for (final s in [
    BootstrapStage.connect,
    BootstrapStage.installKey,
    BootstrapStage.keyOnlyConnect,
  ]) {
    yield BootstrapStageStarted(s);
    yield BootstrapStageSucceeded(s);
  }
  yield const BootstrapStageStarted(BootstrapStage.installDocker);
  yield const BootstrapStageFailed(
    BootstrapStage.installDocker,
    'apt failed',
    'E: Unable to locate package',
  );
}

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('shows every stage done and the finish button', (tester) async {
    _bigView(tester);
    Stream<BootstrapEvent> runner(NewServer server) async* {
      for (final s in BootstrapStage.values) {
        yield BootstrapStageStarted(s);
        yield BootstrapStageSucceeded(
          s,
          s == BootstrapStage.checkout ? 'at v1' : null,
        );
      }
    }

    await tester.pumpWidget(_app(runner));
    await tester.pumpAndSettle();

    expect(find.text('The server is ready'), findsOneWidget);
    expect(find.byKey(BootstrapScreen.finishButton), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(10));
    expect(find.text('at v1'), findsOneWidget);
    expect(find.textContaining('provider-key-for-tests'), findsNothing);
  });

  testWidgets('a failed stage shows its reason and stderr', (tester) async {
    _bigView(tester);
    await tester.pumpWidget(_app(_failingInstallDocker));
    await tester.pumpAndSettle();

    expect(find.text('The bootstrap failed'), findsOneWidget);
    expect(find.text('apt failed'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(BootstrapScreen.stageKey(BootstrapStage.checkout)),
        matching: find.byIcon(Icons.radio_button_unchecked),
      ),
      findsOneWidget,
    );
    expect(find.text('E: Unable to locate package'), findsNothing);
    await tester.tap(
      find.byKey(BootstrapScreen.stageKey(BootstrapStage.installDocker)),
    );
    await tester.pumpAndSettle();
    expect(find.text('E: Unable to locate package'), findsOneWidget);
    expect(find.byKey(BootstrapScreen.closeButton), findsOneWidget);
  });

  testWidgets('a thrown error fails the running stage', (tester) async {
    _bigView(tester);
    Stream<BootstrapEvent> runner(NewServer server) async* {
      yield const BootstrapStageStarted(BootstrapStage.connect);
      throw StateError('boom');
    }

    await tester.pumpWidget(_app(runner));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(BootstrapScreen.stageKey(BootstrapStage.connect)),
        matching: find.byIcon(Icons.error),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('boom'), findsOneWidget);
    expect(find.text('The bootstrap failed'), findsOneWidget);
  });

  testWidgets('closing after a failure pops false', (tester) async {
    _bigView(tester);
    bool? result;
    await tester.pumpWidget(
      _app(
        _failingInstallDocker,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => BootstrapScreen(
                    server: _server(),
                    run: _failingInstallDocker,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BootstrapScreen.closeButton));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
