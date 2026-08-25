import 'package:accent/models/server_profile.dart';
import 'package:accent/services/profile_repository.dart';
import 'package:accent/services/secret_store.dart';
import 'package:accent/services/ssh_bootstrap.dart';
import 'package:accent/services/ssh_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// The password used by every test.
///
/// Distinctive on purpose: the last test sweeps every command, upload, event and
/// stored value looking for it, and a password of "secret" would match prose.
const rootPassword = 'Pw-9xQvT2mLk-not-to-be-seen';

const providerKey = 'sk-or-v1-test-provider-key';

const profile = ServerProfile(
  id: 'srv1',
  name: 'Test server',
  host: '10.0.0.5',
  username: 'root',
);

/// A failure that is neither an [Error] nor an [Exception].
///
/// That is exactly the shape of `dartssh2`'s `SSHError`, and the orchestrator
/// has to turn it into a stage failure rather than let it escape the stream.
class TransportFailure {
  @override
  String toString() => 'TransportFailure(connection refused)';
}

/// Refuses every connection. There is no way to make
/// [ScriptedSshSessionFactory] fail a connect without exhausting it, and an
/// exhausted factory throws an [Error], which is deliberately not caught.
class RefusingSshSessionFactory implements SshSessionFactory {
  @override
  Future<SshSession> connectWithPassword(
    SshEndpoint endpoint,
    String password,
  ) async => throw TransportFailure();

  @override
  Future<SshSession> connectWithKey(
    SshEndpoint endpoint,
    String privateKeyPem,
  ) async => throw TransportFailure();
}

SshCommandResult _failed(int exitCode, [String stderr = '']) =>
    SshCommandResult(exitCode: exitCode, stdout: '', stderr: stderr);

const _caRoot =
    '-----BEGIN CERTIFICATE-----\nMIIB-not-a-real-one\n'
    '-----END CERTIFICATE-----';

/// The session that answers the password connection: everything up to and
/// including the key install.
ScriptedSshSession _passwordSession({bool keyAlreadyInstalled = false}) {
  final session = ScriptedSshSession();
  session.expectCommand(r'mkdir -p "$HOME/.ssh"');
  session.expectCommand('grep -qxF', keyAlreadyInstalled ? null : _failed(1));
  if (!keyAlreadyInstalled) session.expectCommand("printf '%s\\n'");
  return session;
}

/// The session that answers the key connection: Docker onwards.
ScriptedSshSession _keySession({
  bool dockerInstalled = true,
  bool cloned = false,
  bool tagExists = true,
  int healthAttempts = 1,
}) {
  final session = ScriptedSshSession();

  session.expectCommand(
    'docker compose version',
    dockerInstalled ? null : _failed(127, 'docker: not found'),
  );
  if (!dockerInstalled) {
    session.expectCommand('get.docker.com');
    session.expectCommand('docker compose version');
  }

  session.expectCommand('command -v git');
  session.expectCommand('git ls-remote', tagExists ? null : _failed(2));
  session.expectCommand('test -d', cloned ? null : _failed(1));
  session.expectCommand(cloned ? 'git -C' : 'git clone');
  session.expectCommand('checkout --force');
  session.expectCommand('chmod 600');
  session.expectCommand('up -d --build');
  for (var attempt = 1; attempt <= healthAttempts; attempt++) {
    session.expectCommand(
      'bin/healthcheck',
      attempt == healthAttempts ? null : _failed(1, 'not up yet'),
    );
  }
  session.expectCommand(
    'root.crt',
    SshCommandResult(exitCode: 0, stdout: '$_caRoot\n', stderr: ''),
  );
  return session;
}

/// One line per event, in order, for a readable expectation.
List<String> _trace(List<BootstrapEvent> events) => events
    .map(
      (event) => switch (event) {
        BootstrapStageStarted() => '${event.stage.name}: started',
        BootstrapStageSucceeded() => '${event.stage.name}: ok',
        BootstrapStageFailed() => '${event.stage.name}: failed',
      },
    )
    .toList();

/// The value of one key in the uploaded `gateway/.env`.
String _envValue(RecordedUpload upload, String key) {
  final line = upload.text
      .split('\n')
      .firstWhere((line) => line.startsWith('$key='));
  return line.substring(key.length + 1);
}

void main() {
  late InMemorySecretStore store;
  late ProfileRepository profiles;
  late List<Duration> sleeps;

  setUp(() {
    store = InMemorySecretStore();
    profiles = ProfileRepository(store);
    sleeps = [];
  });

  SshBootstrap bootstrapWith(
    SshSessionFactory sessions, {
    String version = '0.1.0',
    int healthAttempts = 30,
  }) => SshBootstrap(
    sessions: sessions,
    profiles: profiles,
    version: version,
    healthAttempts: healthAttempts,
    sleep: (duration) async => sleeps.add(duration),
  );

  Future<List<BootstrapEvent>> runBootstrap(
    SshBootstrap bootstrap, {
    RootPassword? password,
  }) => bootstrap
      .run(
        profile: profile,
        password: password ?? RootPassword(rootPassword),
        openRouterApiKey: providerKey,
      )
      .toList();

  group('the happy path', () {
    test('emits every stage in order and stores every secret', () async {
      final byPassword = _passwordSession();
      final byKey = _keySession();
      final factory = ScriptedSshSessionFactory([byPassword, byKey]);
      final password = RootPassword(rootPassword);

      final events = await runBootstrap(
        bootstrapWith(factory),
        password: password,
      );

      expect(_trace(events), [
        'connect: started',
        'connect: ok',
        'installKey: started',
        'installKey: ok',
        'keyOnlyConnect: started',
        'keyOnlyConnect: ok',
        'installDocker: started',
        'installDocker: ok',
        'checkout: started',
        'checkout: ok',
        'writeEnvironment: started',
        'writeEnvironment: ok',
        'startStack: started',
        'startStack: ok',
        'awaitHealth: started',
        'awaitHealth: ok',
        'readCertificate: started',
        'readCertificate: ok',
        'storeCredentials: started',
        'storeCredentials: ok',
      ]);

      // Every scripted command was actually asked for. A bootstrap that stopped
      // halfway would leave these non-empty.
      expect(byPassword.pending, isEmpty);
      expect(byKey.pending, isEmpty);
      expect(byPassword.closed, isTrue);
      expect(byKey.closed, isTrue);

      // The password opened the first connection and the key the second, which
      // is the whole point of the sequence.
      expect(factory.connections.map((c) => c.kind), [
        SshCredentialKind.password,
        SshCredentialKind.key,
      ]);
      expect(password.released, isTrue);
      expect(() => password.value, throwsStateError);

      final stored = (await profiles.list()).single;
      expect(stored.bootstrapped, isTrue);
      expect(await profiles.sshPrivateKey(profile.id), isNotNull);
      expect(await profiles.gatewayToken(profile.id), isNotNull);
      expect(await profiles.providerKey(profile.id), providerKey);
      expect(
        await profiles.gatewayCertificate(profile.id),
        contains('BEGIN CERTIFICATE'),
      );
      expect(await profiles.stackSecrets(profile.id), isNotNull);
    });

    test('checks out the version tag when the server reports it', () async {
      final factory = ScriptedSshSessionFactory([
        _passwordSession(),
        _keySession(),
      ]);

      final events = await runBootstrap(bootstrapWith(factory, version: '2.3'));

      final checkout = events.whereType<BootstrapStageSucceeded>().firstWhere(
        (event) => event.stage == BootstrapStage.checkout,
      );
      expect(checkout.detail, 'at v2.3');
    });

    test('falls back to main when the tag does not exist', () async {
      final byKey = _keySession(tagExists: false);
      final factory = ScriptedSshSessionFactory([_passwordSession(), byKey]);

      final events = await runBootstrap(bootstrapWith(factory));

      final checkout = events.whereType<BootstrapStageSucceeded>().firstWhere(
        (event) => event.stage == BootstrapStage.checkout,
      );
      expect(checkout.detail, 'at origin/main');
      expect(
        byKey.commands.singleWhere((c) => c.contains('checkout --force')),
        contains('origin/main'),
      );
    });

    test('installs Docker only when compose does not answer', () async {
      final byKey = _keySession(dockerInstalled: false);
      final factory = ScriptedSshSessionFactory([_passwordSession(), byKey]);

      final events = await runBootstrap(bootstrapWith(factory));

      final docker = events.whereType<BootstrapStageSucceeded>().firstWhere(
        (event) => event.stage == BootstrapStage.installDocker,
      );
      expect(docker.detail, 'installed Docker');
      expect(
        byKey.commands.where((c) => c.contains('get.docker.com')),
        hasLength(1),
      );
    });

    test('writes every value the compose file requires', () async {
      final byKey = _keySession();
      final factory = ScriptedSshSessionFactory([_passwordSession(), byKey]);

      await runBootstrap(bootstrapWith(factory));

      final upload = byKey.uploads.single;
      expect(upload.remotePath, '/opt/accent/gateway/.env');
      // Compose reads the .env beside the compose file, not one in the project
      // root, and declares OPENROUTER_API_KEY with `:?` — a missing value there
      // is a stack that refuses to start.
      for (final key in const [
        'GATEWAY_TOKEN',
        'LITELLM_MASTER_KEY',
        'POSTGRES_PASSWORD',
        'OPENROUTER_API_KEY',
        'GATEWAY_PORT',
      ]) {
        expect(_envValue(upload, key), isNotEmpty, reason: key);
      }
      expect(_envValue(upload, 'OPENROUTER_API_KEY'), providerKey);
      expect(_envValue(upload, 'GATEWAY_PORT'), '8443');
    });
  });

  group('the generated secrets', () {
    test('are at least 32 characters', () async {
      final byKey = _keySession();
      final factory = ScriptedSshSessionFactory([_passwordSession(), byKey]);

      await runBootstrap(bootstrapWith(factory));

      final upload = byKey.uploads.single;
      // GatewayConfig refuses to boot on a token under 32, and the failure
      // would present as a stack that will not start rather than as a short
      // token.
      for (final key in const [
        'GATEWAY_TOKEN',
        'LITELLM_MASTER_KEY',
        'POSTGRES_PASSWORD',
      ]) {
        expect(
          _envValue(upload, key).length,
          greaterThanOrEqualTo(SshBootstrap.minimumSecretLength),
          reason: key,
        );
      }
      expect(
        (await profiles.gatewayToken(profile.id))!.length,
        greaterThanOrEqualTo(SshBootstrap.minimumSecretLength),
      );
    });

    test('are url-safe, so the Postgres URL needs no escaping', () async {
      final byKey = _keySession();
      final factory = ScriptedSshSessionFactory([_passwordSession(), byKey]);

      await runBootstrap(bootstrapWith(factory));

      // The password goes into postgres://accent:<password>@postgres:5432 in
      // compose. A `/` or a `+` there would need percent-encoding.
      expect(
        _envValue(byKey.uploads.single, 'POSTGRES_PASSWORD'),
        matches(RegExp(r'^[A-Za-z0-9_-]+$')),
      );
    });

    test('differ between two servers', () async {
      final first = ScriptedSshSessionFactory([
        _passwordSession(),
        _keySession(),
      ]);
      await runBootstrap(bootstrapWith(first));
      final firstToken = await profiles.gatewayToken(profile.id);

      // A second, unrelated profile: nothing is carried over, so nothing may
      // repeat.
      store = InMemorySecretStore();
      profiles = ProfileRepository(store);
      final second = ScriptedSshSessionFactory([
        _passwordSession(),
        _keySession(),
      ]);
      await runBootstrap(bootstrapWith(second));

      expect(await profiles.gatewayToken(profile.id), isNot(firstToken));
    });
  });

  group('a failure', () {
    test('at connect names connect and stops', () async {
      final events = await runBootstrap(
        bootstrapWith(RefusingSshSessionFactory()),
      );

      expect(_trace(events), ['connect: started', 'connect: failed']);
      expect((events.last as BootstrapStageFailed).reason, contains('refused'));
      expect(await profiles.list(), isEmpty);
      expect(await profiles.sshPrivateKey(profile.id), isNull);
    });

    test('at key install names installKey and stops', () async {
      final byPassword = ScriptedSshSession();
      byPassword.expectCommand(
        r'mkdir -p "$HOME/.ssh"',
        _failed(1, 'mkdir: cannot create directory: Read-only file system'),
      );
      final factory = ScriptedSshSessionFactory([byPassword]);

      final events = await runBootstrap(bootstrapWith(factory));

      expect(_trace(events), [
        'connect: started',
        'connect: ok',
        'installKey: started',
        'installKey: failed',
      ]);
      final failure = events.last as BootstrapStageFailed;
      expect(failure.stderr, contains('Read-only file system'));
      // The session is closed even though the run ended early: a bootstrap that
      // leaks a connection on failure leaks one per retry.
      expect(byPassword.closed, isTrue);
      expect(await profiles.sshPrivateKey(profile.id), isNull);
      expect(await profiles.list(), isEmpty);
    });

    test('at the Docker install names installDocker and stops', () async {
      final byKey = ScriptedSshSession();
      byKey.expectCommand(
        'docker compose version',
        _failed(127, 'docker: not found'),
      );
      byKey.expectCommand(
        'get.docker.com',
        _failed(1, 'E: Unable to locate package docker-ce'),
      );
      final factory = ScriptedSshSessionFactory([_passwordSession(), byKey]);

      final events = await runBootstrap(bootstrapWith(factory));

      expect(_trace(events).last, 'installDocker: failed');
      expect(
        events.whereType<BootstrapStageFailed>().single.stage,
        BootstrapStage.installDocker,
      );
      expect(
        events.whereType<BootstrapStageFailed>().single.stderr,
        contains('Unable to locate package'),
      );
      expect(byKey.pending, isEmpty);
      // The key is kept: it is installed on the server, and a key on the server
      // that the phone has forgotten is a credential nothing will ever rotate.
      expect(await profiles.sshPrivateKey(profile.id), isNotNull);
      expect(await profiles.list(), isEmpty);
    });

    test('at compose up names startStack and stops', () async {
      // Everything up to `up -d --build` succeeds, and that command fails.
      final failing = ScriptedSshSession();
      for (final command in const [
        'docker compose version',
        'command -v git',
        'git ls-remote',
        'test -d',
        'git clone',
        'checkout --force',
        'chmod 600',
      ]) {
        failing.expectCommand(
          command,
          command == 'test -d' ? _failed(1) : null,
        );
      }
      failing.expectCommand(
        'up -d --build',
        _failed(1, 'failed to solve: process did not complete successfully'),
      );
      final factory = ScriptedSshSessionFactory([_passwordSession(), failing]);

      final events = await runBootstrap(bootstrapWith(factory));

      expect(_trace(events).last, 'startStack: failed');
      final failure = events.whereType<BootstrapStageFailed>().single;
      expect(failure.stage, BootstrapStage.startStack);
      expect(failure.stderr, contains('failed to solve'));
      expect(failing.pending, isEmpty);
      expect(await profiles.list(), isEmpty);
    });

    test('to come up names awaitHealth and reports the attempts', () async {
      // Three attempts, none of which answers.
      final byKey = ScriptedSshSession();
      for (final command in const [
        'docker compose version',
        'command -v git',
        'git ls-remote',
        'test -d',
        'git clone',
        'checkout --force',
        'chmod 600',
        'up -d --build',
      ]) {
        byKey.expectCommand(command, command == 'test -d' ? _failed(1) : null);
      }
      for (var attempt = 0; attempt < 3; attempt++) {
        byKey.expectCommand('bin/healthcheck', _failed(1, 'no such container'));
      }
      final factory = ScriptedSshSessionFactory([_passwordSession(), byKey]);

      final events = await runBootstrap(
        bootstrapWith(factory, healthAttempts: 3),
      );

      final failure = events.whereType<BootstrapStageFailed>().single;
      expect(failure.stage, BootstrapStage.awaitHealth);
      expect(failure.reason, contains('3 attempts'));
      expect(failure.stderr, contains('no such container'));
      // Waited between attempts, not before the first.
      expect(sleeps, hasLength(2));
      expect(await profiles.list(), isEmpty);
    });

    test('is not swallowed when it is a bug in this code', () async {
      // An exhausted script means the orchestrator ran a command the test did
      // not anticipate. That is an Error, and reporting it as "the server
      // failed" would hide exactly the mistake it exists to reveal.
      final byPassword = ScriptedSshSession();
      final factory = ScriptedSshSessionFactory([byPassword]);

      await expectLater(
        runBootstrap(bootstrapWith(factory)),
        throwsA(isA<UnexpectedSshRequest>()),
      );
    });
  });

  group('a second run', () {
    test('does not append the key twice and reuses the token', () async {
      // A server left behind by an interrupted bootstrap: the key is in
      // authorized_keys, the clone is there, and the phone kept what it
      // generated.
      final byPassword = _passwordSession(keyAlreadyInstalled: true);
      final byKey = _keySession(cloned: true);
      final factory = ScriptedSshSessionFactory([byPassword, byKey]);

      final key = SshKeys.generate(comment: 'accent-${profile.id}');
      await profiles.storeSshPrivateKey(profile.id, key.privateKeyPem);
      await profiles.storeGatewayCredentials(
        profile.id,
        token: 'a-token-that-is-at-least-32-characters',
        certificatePem: 'stale',
      );
      await profiles.storeStackSecrets(
        profile.id,
        litellmMasterKey: 'a-litellm-key-of-at-least-32-characters',
        postgresPassword: 'a-postgres-password-of-32-plus-chars',
      );

      final events = await runBootstrap(bootstrapWith(factory));

      expect(events.whereType<BootstrapStageFailed>(), isEmpty);
      expect(byPassword.pending, isEmpty);
      expect(byKey.pending, isEmpty);

      // Nothing was appended, and the existing key was reused rather than a
      // second one generated.
      expect(byPassword.commands.where((c) => c.contains('printf')), isEmpty);
      expect(byPassword.commands, hasLength(2));
      expect(await profiles.sshPrivateKey(profile.id), key.privateKeyPem);
      expect(byPassword.commands.last, contains(key.authorizedKeysLine));

      // Fetched rather than cloned, so an existing clone is not an obstacle.
      expect(byKey.commands.where((c) => c.contains('git clone')), isEmpty);
      expect(byKey.commands.where((c) => c.contains('fetch')), hasLength(1));

      // The token the app is already using survives, and so does the Postgres
      // password — Postgres only sets it when it initialises its volume, so a
      // fresh one would lock the stack out of its own database.
      final upload = byKey.uploads.single;
      expect(
        _envValue(upload, 'GATEWAY_TOKEN'),
        'a-token-that-is-at-least-32-characters',
      );
      expect(
        _envValue(upload, 'POSTGRES_PASSWORD'),
        'a-postgres-password-of-32-plus-chars',
      );
      // The certificate, by contrast, is re-read: it is the server's answer,
      // not the phone's.
      expect(
        await profiles.gatewayCertificate(profile.id),
        contains('BEGIN CERTIFICATE'),
      );
    });

    test('replaces a stored key it cannot install', () async {
      // A store that came back from a reset, or a key from a format we no
      // longer produce. Regenerating is recoverable; refusing is not.
      await profiles.storeSshPrivateKey(profile.id, 'not a PEM at all');
      final byPassword = _passwordSession();
      final factory = ScriptedSshSessionFactory([byPassword, _keySession()]);

      final events = await runBootstrap(bootstrapWith(factory));

      expect(events.whereType<BootstrapStageFailed>(), isEmpty);
      expect(
        await profiles.sshPrivateKey(profile.id),
        startsWith('-----BEGIN'),
      );
    });
  });

  group('the password', () {
    test('appears in no command, upload, event or stored value', () async {
      final byPassword = _passwordSession();
      final byKey = _keySession();
      final factory = ScriptedSshSessionFactory([byPassword, byKey]);
      final password = RootPassword(rootPassword);

      final events = await runBootstrap(
        bootstrapWith(factory),
        password: password,
      );

      final everythingSaid = [
        ...byPassword.commands,
        ...byKey.commands,
        ...byPassword.uploads.map((u) => u.text),
        ...byKey.uploads.map((u) => u.text),
        ...events.map((event) => event.toString()),
        ...events.whereType<BootstrapStageSucceeded>().map(
          (event) => event.detail ?? '',
        ),
        ...await Future.wait(
          store.keys.map((key) async => await store.read(key) ?? ''),
        ),
        password.toString(),
        (await profiles.list()).single.toString(),
        ...factory.connections.map((c) => c.toString()),
      ];

      for (final said in everythingSaid) {
        expect(said, isNot(contains(rootPassword)));
      }
      // And it is gone from the orchestrator's reach long before the run ends.
      expect(password.released, isTrue);
    });

    test('appears in no failure message either', () async {
      // Every failure path, since an error message is the likeliest place for a
      // credential to escape.
      final byPassword = ScriptedSshSession();
      byPassword.expectCommand(
        r'mkdir -p "$HOME/.ssh"',
        _failed(1, 'permission denied'),
      );
      final factories = <SshSessionFactory>[
        RefusingSshSessionFactory(),
        ScriptedSshSessionFactory([byPassword]),
      ];

      for (final factory in factories) {
        final events = await runBootstrap(bootstrapWith(factory));
        final failure = events.whereType<BootstrapStageFailed>().single;
        expect(failure.reason, isNot(contains(rootPassword)));
        expect(failure.stderr, isNot(contains(rootPassword)));
        expect(failure.toString(), isNot(contains(rootPassword)));
      }
    });

    test('is released even when a later stage fails', () async {
      final byKey = ScriptedSshSession();
      byKey.expectCommand('docker compose version', _failed(127));
      byKey.expectCommand('get.docker.com', _failed(1, 'no network'));
      final factory = ScriptedSshSessionFactory([_passwordSession(), byKey]);
      final password = RootPassword(rootPassword);

      await runBootstrap(bootstrapWith(factory), password: password);

      expect(password.released, isTrue);
    });
  });

  test(
    'a missing provider key is refused before anything is touched',
    () async {
      final factory = ScriptedSshSessionFactory([]);

      await expectLater(
        bootstrapWith(factory)
            .run(
              profile: profile,
              password: RootPassword(rootPassword),
              openRouterApiKey: '   ',
            )
            .toList(),
        throwsArgumentError,
      );
      expect(factory.connections, isEmpty);
    },
  );
}
