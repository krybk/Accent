import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../models/server_profile.dart';
import 'profile_repository.dart';
import 'ssh_session.dart';

/// The app's own version, used to pick the ref the server checks out.
///
/// It must track `version:` in `app/pubspec.yaml`. Reading the pubspec at
/// runtime would mean shipping it as an asset or taking a dependency on
/// `package_info_plus`, and neither buys anything: a release is a tag, the tag
/// and the pubspec version are already required to agree by `release.yml`, and a
/// version bump is a visible commit either way.
const String accentVersion = '0.2.1';

/// Where the server clones from.
///
/// A clone rather than an uploaded bundle: `gateway/docker-compose.yml` builds
/// the gateway from source with `build.context: ..`, so a bundle would mean
/// shipping the gateway and protocol sources inside the APK and keeping them
/// from drifting. The repository is public and the server needs outbound network
/// for images and model calls anyway.
const String accentRepositoryUrl = 'https://github.com/krybk/Accent.git';

/// Where the clone lives on the server.
const String accentInstallDirectory = '/opt/accent';

/// Where the control plane's socket lives on the server: the compose default of
/// `PLANE_SOCKET_DIR`.
const String accentPlaneSocketDirectory = '/run/accent-plane';

/// The twelve steps of a bootstrap, in the order they run.
///
/// Named rather than counted because this takes minutes, touches someone else's
/// server and can fail at a dozen points; "something went wrong" after four
/// minutes is not a usable failure.
enum BootstrapStage {
  /// Connect with the root password the user typed.
  connect('Connecting with the password'),

  /// Generate a key — or reuse the one this profile already owns — and put its
  /// public half in `authorized_keys`.
  installKey('Installing the SSH key'),

  /// Reconnect with the key alone. The password is released here.
  keyOnlyConnect('Checking the key works without the password'),

  /// Look for a running Accent gateway and the control plane's socket.
  discover('Looking at what the server already runs'),

  /// Install Docker, unless `docker compose version` already answers.
  installDocker('Installing Docker'),

  /// Clone or fast-forward the repository at the pinned ref.
  checkout('Fetching the stack sources'),

  /// Write `gateway/.env` with the secrets generated on the phone.
  writeEnvironment('Writing the gateway configuration'),

  /// `docker compose up -d --build`.
  startStack('Starting the stack'),

  /// Poll the stack's own health check until it answers.
  awaitHealth('Waiting for the stack to answer'),

  /// Write this app's token hash into an existing gateway's tokens directory.
  issueToken('Issuing this app a token'),

  /// Read Caddy's internal CA root, which the app will pin.
  readCertificate('Reading the certificate'),

  /// Put the key, token, provider key and certificate in the key store and mark
  /// the profile bootstrapped.
  storeCredentials('Storing the credentials');

  const BootstrapStage(this.label);

  /// Short human-readable name, for a progress list in the UI. Safe to display:
  /// no stage label mentions a value, only a step.
  final String label;
}

/// What [BootstrapStage.discover] found on the server.
enum ServerDiscovery {
  /// A running Accent gateway to join.
  existingGateway,

  /// A control plane socket and no gateway.
  planeOnly,

  /// Neither.
  nothing,
}

/// Something a bootstrap stage did.
///
/// Every stage emits [BootstrapStageStarted] and then exactly one of
/// [BootstrapStageSucceeded] or [BootstrapStageFailed] — or, when it does not
/// apply to what [BootstrapStage.discover] found, only
/// [BootstrapStageSkipped]. A failure is terminal —
/// the run stops and the stream ends — so the last event of a run says whether
/// it worked.
sealed class BootstrapEvent {
  const BootstrapEvent(this.stage);

  final BootstrapStage stage;
}

/// A stage began.
final class BootstrapStageStarted extends BootstrapEvent {
  const BootstrapStageStarted(super.stage);

  @override
  String toString() => 'BootstrapStageStarted(${stage.name})';
}

/// A stage finished.
final class BootstrapStageSucceeded extends BootstrapEvent {
  const BootstrapStageSucceeded(super.stage, [this.detail]);

  /// What the stage decided, when there was a decision worth recording: which
  /// ref was checked out, whether Docker was already there, how many polls the
  /// health check needed. Never a value, only a fact about the run.
  final String? detail;

  @override
  String toString() =>
      'BootstrapStageSucceeded(${stage.name}${detail == null ? '' : ': $detail'})';
}

/// [BootstrapStage.discover] finished, and what it found.
final class BootstrapDiscovered extends BootstrapStageSucceeded {
  const BootstrapDiscovered(this.discovery, [String? detail])
    : super(BootstrapStage.discover, detail);

  final ServerDiscovery discovery;

  @override
  String toString() =>
      'BootstrapDiscovered(${discovery.name}${detail == null ? '' : ': $detail'})';
}

/// A stage that does not apply to what was discovered, and did not run.
final class BootstrapStageSkipped extends BootstrapEvent {
  const BootstrapStageSkipped(super.stage);

  @override
  String toString() => 'BootstrapStageSkipped(${stage.name})';
}

/// A stage failed, and the bootstrap stopped there.
final class BootstrapStageFailed extends BootstrapEvent {
  const BootstrapStageFailed(super.stage, this.reason, [this.stderr = '']);

  /// What went wrong, in one line. Built from exit codes and error types, never
  /// from a credential — see the note on [SshBootstrap].
  final String reason;

  /// The failing command's standard error, empty when the failure was not a
  /// command. This is what [SshCommandResult] keeps `stderr` separate for: a
  /// failed `docker compose up` says everything useful here.
  final String stderr;

  @override
  String toString() => 'BootstrapStageFailed(${stage.name}: $reason)';
}

/// The root password, in a box that can be emptied.
///
/// Dart strings are immutable, so "wiping the password" cannot mean overwriting
/// its characters — the only thing it can mean is dropping every reference and
/// letting the collector take it. A plain `String` parameter cannot be dropped:
/// its frame lives as long as the bootstrap does. So the password travels in
/// this box, and [release] empties the box the moment the key is proven to work
/// — while the run still has seven stages and several minutes to go.
///
/// The box is also why nothing needs to redact anything: there is no field on
/// [ServerProfile], no progress event and no log line that could hold a
/// password, and [toString] here says only whether one is still held.
final class RootPassword {
  RootPassword(this._value);

  String? _value;

  bool get released => _value == null;

  /// Throws [StateError] after [release]. A bootstrap that asks for the
  /// password once the key works has a stage in the wrong order, which is a bug
  /// to see rather than to work around.
  String get value =>
      _value ?? (throw StateError('the root password was already released'));

  void release() => _value = null;

  @override
  String toString() => 'RootPassword(${released ? 'released' : 'held'})';
}

/// Turns a root password into a deployed stack and a stored credential.
///
/// The sequence is in [BootstrapStage]. Two properties hold throughout:
///
/// **No secret leaves by the wrong door.** The generated secrets are written to
/// `gateway/.env` by SFTP upload, never interpolated into a command — a command
/// line is visible in `ps` on the server and is recorded by
/// [ScriptedSshSession] in tests. Nothing reads a secret back off the server.
/// The health check uses the unauthenticated liveness path so that not even the
/// gateway token appears in a command.
///
/// **Re-running is safe.** An interrupted bootstrap leaves a key installed, a
/// clone present, or containers up, and a second run must neither duplicate nor
/// refuse. Every stage checks before it acts, the SSH key is reused from the
/// store rather than regenerated, and the stack's own secrets are reused too:
/// Postgres sets its password only when it initialises its volume, so writing a
/// fresh `POSTGRES_PASSWORD` over an existing volume would lock the stack out of
/// its own database.
///
/// When [BootstrapStage.discover] finds a running gateway nothing is rebuilt,
/// and nothing under the install directory or any `.env` is read or written.
/// The app writes only the SHA-256 of its token into the gateway's tokens
/// directory, and only Caddy's environment, never the gateway's, is inspected.
class SshBootstrap {
  SshBootstrap({
    required SshSessionFactory sessions,
    required ProfileRepository profiles,
    String repositoryUrl = accentRepositoryUrl,
    String version = accentVersion,
    String installDirectory = accentInstallDirectory,
    int healthAttempts = 30,
    Duration healthInterval = const Duration(seconds: 5),
    Future<void> Function(Duration)? sleep,
  }) : _sessions = sessions,
       _profiles = profiles,
       _repositoryUrl = repositoryUrl,
       _version = version,
       _directory = installDirectory,
       _healthAttempts = healthAttempts,
       _healthInterval = healthInterval,
       _sleep = sleep ?? Future<void>.delayed;

  final SshSessionFactory _sessions;
  final ProfileRepository _profiles;
  final String _repositoryUrl;
  final String _version;
  final String _directory;

  /// How many times to ask the stack whether it is up before giving up. The
  /// first `--build` on a small server is minutes of compilation, so the bound
  /// is generous; it exists so that a stack which will never come up reports
  /// that instead of hanging.
  final int _healthAttempts;
  final Duration _healthInterval;

  /// Injected so tests do not sleep. Defaults to real time.
  final Future<void> Function(Duration) _sleep;

  /// 24 random bytes, which is 32 base64url characters — one above the 32
  /// `GatewayConfig` refuses to boot below, and 192 bits of entropy.
  ///
  /// base64url rather than base64 for a specific reason: `POSTGRES_PASSWORD`
  /// goes into `postgres://accent:<password>@postgres:5432/accent` in compose,
  /// and base64's `/` and `+` would need percent-encoding there while `-` and
  /// `_` do not.
  static const int _secretBytes = 24;

  /// The shortest a generated secret may be, checked by a test because
  /// `GatewayConfig` refuses a token under this length and the failure would
  /// otherwise appear as a stack that will not start.
  static const int minimumSecretLength = 32;

  /// Runs the bootstrap, reporting each stage as it goes.
  ///
  /// The stream is lazy: nothing touches the server until someone listens.
  /// It ends after the last stage, or after the first [BootstrapStageFailed].
  ///
  /// [password] is emptied during [BootstrapStage.keyOnlyConnect] and is of no
  /// further use to the caller afterwards. [anthropicApiKey] is an input, not a
  /// generated value, and it is optional: when empty the stack starts without
  /// LiteLLM (no `COMPOSE_PROFILES`), and chat, which goes through the control
  /// plane, does not need it. It is stored as a secret, never on the profile,
  /// and only when non-empty.
  Stream<BootstrapEvent> run({
    required ServerProfile profile,
    required RootPassword password,
    String anthropicApiKey = '',
  }) async* {
    final providerKey = anthropicApiKey.trim();

    final endpoint = SshEndpoint(
      host: profile.host,
      username: profile.username,
      port: profile.port,
    );

    // Cleanup handles only. The work below goes through non-nullable locals, so
    // that a stage cannot be handed a session the analyzer thinks might be null.
    SshSession? byPassword;
    SshSession? byKey;
    try {
      // 1. Connect with the password.
      yield const BootstrapStageStarted(BootstrapStage.connect);
      final passwordSession = await _guard(
        BootstrapStage.connect,
        'connecting to $endpoint',
        () => _sessions.connectWithPassword(endpoint, password.value),
      );
      byPassword = passwordSession;
      yield const BootstrapStageSucceeded(BootstrapStage.connect);

      // 2. Install the key.
      yield const BootstrapStageStarted(BootstrapStage.installKey);
      final key = await _keyFor(profile);
      final appended = await _installKey(passwordSession, key);
      yield BootstrapStageSucceeded(
        BootstrapStage.installKey,
        appended ? 'appended the public key' : 'the key was already installed',
      );

      // 3. Reconnect with the key alone, and let go of the password.
      yield const BootstrapStageStarted(BootstrapStage.keyOnlyConnect);
      final keySession = await _guard(
        BootstrapStage.keyOnlyConnect,
        'reconnecting with the key',
        () => _sessions.connectWithKey(endpoint, key.privateKeyPem),
      );
      byKey = keySession;
      password.release();
      // Persisted here rather than only in the last stage. A key that is
      // installed on the server but absent from the store is an orphan: it
      // still grants root, nothing will rotate it, and the next run would
      // generate a second one and append that too.
      await _profiles.storeSshPrivateKey(profile.id, key.privateKeyPem);
      // The password session is finished with. Closing it now, rather than in
      // the cleanup below, keeps the rest of the run demonstrably key-only.
      await passwordSession.close();
      byPassword = null;
      yield const BootstrapStageSucceeded(
        BootstrapStage.keyOnlyConnect,
        'the password is no longer needed',
      );

      // 4. What the server already runs.
      yield const BootstrapStageStarted(BootstrapStage.discover);
      final found = await _discover(keySession, profile);
      yield BootstrapDiscovered(found.discovery, found.detail);

      final String token;
      final String certificate;
      int? discoveredPort;
      if (found.discovery == ServerDiscovery.existingGateway) {
        yield const BootstrapStageSkipped(BootstrapStage.installDocker);
        yield const BootstrapStageSkipped(BootstrapStage.checkout);
        yield const BootstrapStageSkipped(BootstrapStage.writeEnvironment);
        yield const BootstrapStageSkipped(BootstrapStage.startStack);
        yield const BootstrapStageSkipped(BootstrapStage.awaitHealth);

        // 5. A token for this app, in the gateway's tokens directory.
        yield const BootstrapStageStarted(BootstrapStage.issueToken);
        token = await _issueToken(keySession, profile, found);
        yield const BootstrapStageSucceeded(
          BootstrapStage.issueToken,
          "wrote this app's token file",
        );

        // 6. The CA root the app will pin.
        yield const BootstrapStageStarted(BootstrapStage.readCertificate);
        certificate = await _readCertificateAuthority(
          keySession,
          'docker exec ${_quote(found.caddyId)} '
          'cat /data/caddy/pki/authorities/local/root.crt',
        );
        yield const BootstrapStageSucceeded(BootstrapStage.readCertificate);
        discoveredPort = found.port;
      } else {
        // 5. Docker.
        yield const BootstrapStageStarted(BootstrapStage.installDocker);
        final installed = await _installDocker(keySession);
        yield BootstrapStageSucceeded(
          BootstrapStage.installDocker,
          installed ? 'installed Docker' : 'Docker was already installed',
        );

        // 6. Sources, at a pinned ref.
        yield const BootstrapStageStarted(BootstrapStage.checkout);
        final ref = await _checkout(keySession);
        yield BootstrapStageSucceeded(BootstrapStage.checkout, 'at $ref');

        // 7. Configuration.
        yield const BootstrapStageStarted(BootstrapStage.writeEnvironment);
        token = await _writeEnvironment(
          keySession,
          profile,
          providerKey,
          planeSocket: found.discovery == ServerDiscovery.planeOnly,
        );
        yield const BootstrapStageSucceeded(BootstrapStage.writeEnvironment);

        // 8. Up.
        yield const BootstrapStageStarted(BootstrapStage.startStack);
        await _mustRun(
          keySession,
          BootstrapStage.startStack,
          'starting the stack',
          '$_cd && docker compose -f gateway/docker-compose.yml up -d --build',
        );
        yield const BootstrapStageSucceeded(BootstrapStage.startStack);

        // 9. Health.
        yield const BootstrapStageStarted(BootstrapStage.awaitHealth);
        final attempts = await _awaitHealth(keySession);
        yield BootstrapStageSucceeded(
          BootstrapStage.awaitHealth,
          'answered on attempt $attempts',
        );

        // The stack's own token is in its .env; there is nothing to issue.
        yield const BootstrapStageSkipped(BootstrapStage.issueToken);

        // 10. The CA root the app will pin.
        yield const BootstrapStageStarted(BootstrapStage.readCertificate);
        certificate = await _readCertificateAuthority(
          keySession,
          '$_cd && docker compose -f gateway/docker-compose.yml exec -T caddy '
          'cat /data/caddy/pki/authorities/local/root.crt',
        );
        yield const BootstrapStageSucceeded(BootstrapStage.readCertificate);
      }

      // 11. Keep what the app needs to talk to the gateway from now on.
      yield const BootstrapStageStarted(BootstrapStage.storeCredentials);
      await _guard(
        BootstrapStage.storeCredentials,
        'storing the credentials',
        () async {
          await _profiles.storeSshPrivateKey(profile.id, key.privateKeyPem);
          if (providerKey.isNotEmpty) {
            await _profiles.storeProviderKey(profile.id, providerKey);
          }
          await _profiles.storeGatewayCredentials(
            profile.id,
            token: token,
            certificatePem: certificate,
          );
          // A null port keeps the profile's own.
          await _profiles.save(
            profile.copyWith(bootstrapped: true, gatewayPort: discoveredPort),
          );
        },
      );
      yield const BootstrapStageSucceeded(BootstrapStage.storeCredentials);
    } on _StageFailure catch (failure) {
      yield BootstrapStageFailed(failure.stage, failure.reason, failure.stderr);
    } finally {
      // Both sessions, even on the happy path: the bootstrap is the only thing
      // that needs a shell on the server, and everything after it talks to the
      // gateway over TLS.
      await byPassword?.close();
      await byKey?.close();
    }
  }

  /// `cd` into the clone. Every compose command needs it, and repeating the
  /// literal in seven places is how one of them ends up pointing elsewhere.
  String get _cd => 'cd ${_quote(_directory)}';

  /// The key to install: the one this profile already owns, or a new one.
  ///
  /// Reuse is what makes a second run safe. Generating a fresh key each time
  /// would leave the previous public half in `authorized_keys` forever — a
  /// credential nothing will ever rotate, granted to a private half the phone
  /// has already thrown away.
  Future<GeneratedSshKey> _keyFor(ServerProfile profile) async {
    final comment = 'accent-${profile.id}';
    final stored = await _guard(
      BootstrapStage.installKey,
      'reading the stored key',
      () => _profiles.sshPrivateKey(profile.id),
    );
    if (stored == null || stored.isEmpty) {
      return SshKeys.generate(comment: comment);
    }
    try {
      return GeneratedSshKey(
        privateKeyPem: stored,
        authorizedKeysLine: SshKeys.authorizedKeysLineFromPem(
          stored,
          comment: comment,
        ),
        comment: comment,
      );
    } on ArgumentError {
      // The stored key is not one we can install — a store that was reset, or a
      // key from an older format. A fresh key is the recoverable answer; the
      // unusable one is overwritten at the end of stage 3.
      return SshKeys.generate(comment: comment);
    }
  }

  /// Puts the public half in `authorized_keys`, and says whether it had to.
  ///
  /// Three commands rather than one chain, because the difference between "the
  /// key is not there" and "the directory could not be created" is the
  /// difference between continuing and stopping, and a single `&&` chain reports
  /// both as one non-zero exit.
  Future<bool> _installKey(SshSession session, GeneratedSshKey key) async {
    const stage = BootstrapStage.installKey;
    const dir = r'"$HOME/.ssh"';
    const file = r'"$HOME/.ssh/authorized_keys"';
    await _mustRun(
      session,
      stage,
      'preparing the .ssh directory',
      'mkdir -p $dir && chmod 700 $dir '
          '&& touch $file && chmod 600 $file',
    );
    // A public key is not a secret, so this is the one credential-shaped thing
    // that may appear in a command line.
    final line = _quote(key.authorizedKeysLine);
    final present = await _run(
      session,
      stage,
      'looking for the key',
      'grep -qxF -- $line $file',
    );
    if (present.ok) return false;
    await _mustRun(
      session,
      stage,
      'appending the key',
      "printf '%s\\n' $line >> $file",
    );
    return true;
  }

  /// Installs Docker unless it is already there, and says which happened.
  Future<bool> _installDocker(SshSession session) async {
    const stage = BootstrapStage.installDocker;
    const probe = 'docker compose version';
    if ((await _run(session, stage, 'looking for Docker', probe)).ok) {
      return false;
    }
    await _mustRun(
      session,
      stage,
      'installing Docker',
      'curl -fsSL https://get.docker.com -o /tmp/get-docker.sh '
          '&& sh /tmp/get-docker.sh && rm -f /tmp/get-docker.sh',
    );
    // Asked again on purpose. The convenience script can exit zero having
    // installed a Docker without the compose plugin, and the next stage's
    // failure would then read as a problem with our compose file.
    await _mustRun(session, stage, 'checking the Docker install', probe);
    return true;
  }

  /// Clones or fast-forwards the repository, and returns the ref it left the
  /// working tree at.
  ///
  /// The ref is `v<version>` when the server can see that tag, and `origin/main`
  /// when it cannot — a released app deploys the sources it was built from, and
  /// a development build deploys the tip. Detached either way, because a deploy
  /// checkout is not a place anyone commits from.
  Future<String> _checkout(SshSession session) async {
    const stage = BootstrapStage.checkout;
    // Docker's convenience script installs Docker, not git, and a minimal
    // server may have neither. One line, three package managers, and idempotent
    // — the alternative is a bootstrap that stops on a fresh install to ask for
    // a package.
    await _mustRun(
      session,
      stage,
      'installing git',
      'command -v git >/dev/null 2>&1 '
          '|| { apt-get update -qq && apt-get install -y -qq git; } '
          '|| dnf install -y -q git '
          '|| apk add --no-cache git',
    );

    final url = _quote(_repositoryUrl);
    final tag = 'v$_version';
    final probe = await _run(
      session,
      stage,
      'looking for the tag $tag',
      'git ls-remote --tags --exit-code $url ${_quote('refs/tags/$tag')}',
    );
    final String ref;
    if (probe.ok) {
      ref = tag;
    } else if (probe.exitCode == 2) {
      // `--exit-code` reserves 2 for "no matching refs". Anything else is a
      // transport failure, and falling back to main on a broken network would
      // deploy a ref nobody asked for.
      ref = 'origin/main';
    } else {
      throw _StageFailure(
        stage,
        'could not reach $_repositoryUrl (exit ${probe.exitCode})',
        probe.stderr,
      );
    }

    final dir = _quote(_directory);
    final cloned = await _run(
      session,
      stage,
      'looking for an existing clone',
      'test -d ${_quote('$_directory/.git')}',
    );
    if (cloned.ok) {
      await _mustRun(
        session,
        stage,
        'fetching',
        'git -C $dir fetch --tags --force --prune origin',
      );
    } else {
      await _mustRun(session, stage, 'cloning', 'git clone $url $dir');
    }
    await _mustRun(
      session,
      stage,
      'checking out $ref',
      'git -c advice.detachedHead=false -C $dir checkout --force $ref',
    );
    return ref;
  }

  /// Writes `gateway/.env` and returns the gateway token it put there.
  ///
  /// The secrets are generated here, on the phone, and never read back off the
  /// server: the token the app must hold is a token the app already has, so it
  /// never has to travel over SSH in the other direction. The file goes up by
  /// SFTP rather than by `echo`, because a command line is visible in `ps`.
  Future<String> _writeEnvironment(
    SshSession session,
    ServerProfile profile,
    String providerKey, {
    bool planeSocket = false,
  }) async {
    const stage = BootstrapStage.writeEnvironment;
    final id = profile.id;

    // Reused when they exist, for two different reasons. The token: a working
    // credential that the app is already using should survive a repair run. The
    // Postgres password: the container sets it only when it initialises its
    // volume, so a fresh one written over an existing volume would leave the
    // gateway and LiteLLM unable to log in to their own database — a re-run that
    // breaks a working stack.
    final token = await _guard(
      stage,
      'reading the stored token',
      () => _profiles.gatewayToken(id),
    );
    final stack = await _guard(
      stage,
      'reading the stored stack secrets',
      () => _profiles.stackSecrets(id),
    );

    final gatewayToken = _orNew(token);
    final litellmKey = _orNew(stack?.litellmMasterKey);
    final postgresPassword = _orNew(stack?.postgresPassword);

    // LiteLLM sits behind that compose profile; without a key the stack starts
    // without it.
    final optional =
        (providerKey.isNotEmpty ? 'COMPOSE_PROFILES=litellm\n' : '') +
        (planeSocket ? 'PLANE_SOCKET_DIR=$accentPlaneSocketDirectory\n' : '');

    final env =
        '''
# Written by Accent during bootstrap. Do not edit by hand.
#
# The phone holds these values and rewrites this file on every bootstrap, so an
# edit here is lost on the next run. Rotating the gateway token means asking the
# app for it.
GATEWAY_TOKEN=$gatewayToken
LITELLM_MASTER_KEY=$litellmKey
POSTGRES_PASSWORD=$postgresPassword
ANTHROPIC_API_KEY=$providerKey
GATEWAY_PORT=${profile.gatewayPort}
GATEWAY_HOST=${profile.host}
$optional''';

    // Compose reads the `.env` beside the compose file, which is why this is
    // `gateway/.env` and not one in the project root.
    final path = '$_directory/gateway/.env';
    await _guard(
      stage,
      'uploading gateway/.env',
      () => session.upload(path, Uint8List.fromList(utf8.encode(env))),
    );
    await _mustRun(
      session,
      stage,
      'restricting gateway/.env',
      'chmod 600 ${_quote(path)}',
    );

    // Kept before the stack is up rather than after. If `up --build` fails
    // halfway, the next run must write the same Postgres password rather than
    // a new one.
    await _guard(
      stage,
      'storing the stack secrets',
      () => _profiles.storeStackSecrets(
        id,
        litellmMasterKey: litellmKey,
        postgresPassword: postgresPassword,
      ),
    );
    return gatewayToken;
  }

  /// Polls the stack's own health check until it answers, returning the attempt
  /// that succeeded.
  ///
  /// It runs the gateway container's own health check binary rather than curling
  /// the published port, for two reasons. `curl` is not guaranteed to exist on a
  /// server that already had Docker, whereas Docker is, by the stage before
  /// this. And that binary hits the unauthenticated liveness path, so the
  /// gateway token stays out of a command line — a health check that needed a
  /// credential would also put the token in `ps` on the server.
  Future<int> _awaitHealth(SshSession session) async {
    const stage = BootstrapStage.awaitHealth;
    SshCommandResult? last;
    for (var attempt = 1; attempt <= _healthAttempts; attempt++) {
      if (attempt > 1) await _sleep(_healthInterval);
      last = await _run(
        session,
        stage,
        'asking the stack whether it is up',
        '$_cd && docker compose -f gateway/docker-compose.yml '
            'exec -T gateway /app/bin/healthcheck',
      );
      if (last.ok) return attempt;
    }
    throw _StageFailure(
      stage,
      'the stack did not answer after $_healthAttempts attempts',
      last?.stderr ?? '',
    );
  }

  /// Reads the root certificate of Caddy's internal CA.
  ///
  /// The root, not the leaf: the leaf is reissued on renewal and a pin on it
  /// would break the app for no reason. `tls internal` in
  /// `gateway/caddy/Caddyfile` is why there is a CA to pin at all.
  Future<String> _readCertificateAuthority(
    SshSession session,
    String command,
  ) async {
    const stage = BootstrapStage.readCertificate;
    final result = await _mustRun(
      session,
      stage,
      'reading the CA root',
      command,
    );
    final pem = result.stdout.trim();
    if (!pem.contains('BEGIN CERTIFICATE')) {
      // Pinning whatever came back would produce a profile that cannot connect
      // and no explanation of why.
      throw _StageFailure(
        stage,
        'the CA root did not look like a certificate '
        '(${pem.length} bytes)',
        result.stderr,
      );
    }
    return pem;
  }

  /// Looks, read-only, for a running Accent gateway and the plane socket.
  ///
  /// The gateway container's own environment is never inspected — it holds the
  /// secrets. Caddy's holds only the host, which is what the certificate is
  /// issued for.
  Future<_Discovered> _discover(
    SshSession session,
    ServerProfile profile,
  ) async {
    const stage = BootstrapStage.discover;
    final probe = await _run(
      session,
      stage,
      'looking for an Accent gateway',
      "command -v docker >/dev/null 2>&1 && docker ps "
          "--filter label=accent.gateway.tokens-dir "
          "--format '{{.ID}} {{.Label \"com.docker.compose.project\"}} "
          "{{.Label \"accent.gateway.tokens-dir\"}}'",
    );
    final hasGateway = probe.ok && probe.stdout.trim().isNotEmpty;

    var gatewayId = '';
    var project = '';
    var tokensDirectory = '';
    var caddyId = '';
    var port = 0;
    if (hasGateway) {
      final fields = probe.stdout
          .trim()
          .split('\n')
          .first
          .split(RegExp(r'\s+'));
      if (fields.length < 3) {
        throw _StageFailure(stage, 'found a gateway outside a compose project');
      }
      gatewayId = fields[0];
      project = fields[1];
      tokensDirectory = fields[2];

      final caddy = await _mustRun(
        session,
        stage,
        "looking for the gateway's Caddy",
        "docker ps --filter ${_quote('label=com.docker.compose.project=$project')} "
            "--filter label=com.docker.compose.service=caddy --format '{{.ID}}'",
      );
      caddyId = caddy.stdout.trim().split('\n').first.trim();
      if (caddyId.isEmpty) {
        throw _StageFailure(stage, 'found a gateway without its Caddy');
      }

      final published = await _mustRun(
        session,
        stage,
        'reading the port Caddy publishes',
        'docker port ${_quote(caddyId)} 8443/tcp',
      );
      final line = published.stdout.trim().split('\n').first;
      final parsed = int.tryParse(
        line.substring(line.lastIndexOf(':') + 1).trim(),
      );
      if (parsed == null) {
        throw _StageFailure(
          stage,
          'could not read the port Caddy publishes',
          published.stdout,
        );
      }
      port = parsed;

      // Caddy's environment, not the gateway's: the gateway container holds the
      // secrets, Caddy's holds only the host the certificate is issued for.
      final environment = await _mustRun(
        session,
        stage,
        "reading Caddy's environment",
        "docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "
            '${_quote(caddyId)}',
      );
      const prefix = 'GATEWAY_HOST=';
      String? host;
      for (final entry in environment.stdout.split('\n')) {
        if (entry.startsWith(prefix)) {
          host = entry.substring(prefix.length).trim();
          break;
        }
      }
      if (host == null) {
        throw _StageFailure(stage, 'Caddy has no GATEWAY_HOST');
      }
      if (host != profile.host) {
        throw _StageFailure(
          stage,
          "the gateway's certificate is issued for $host; "
          'add the server with that address',
        );
      }
    }

    final plane = (await _run(
      session,
      stage,
      'looking for the plane socket',
      'test -S ${_quote('$accentPlaneSocketDirectory/plane.sock')}',
    )).ok;

    if (!hasGateway) {
      final busy = await _run(
        session,
        stage,
        'checking the gateway port is free',
        "command -v docker >/dev/null 2>&1 && docker ps "
            "--filter publish=${profile.gatewayPort} --format '{{.Names}}'",
      );
      final names = busy.stdout
          .split('\n')
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toList();
      if (busy.ok && names.isNotEmpty) {
        throw _StageFailure(
          stage,
          'port ${profile.gatewayPort} is already published by '
          '${names.join(', ')}',
        );
      }
    }

    if (hasGateway) {
      return _Discovered(
        ServerDiscovery.existingGateway,
        'gateway in compose project $project on port $port; '
        'plane socket ${plane ? 'present' : 'absent'}',
        gatewayId: gatewayId,
        caddyId: caddyId,
        tokensDirectory: tokensDirectory,
        port: port,
      );
    }
    if (plane) {
      return const _Discovered(
        ServerDiscovery.planeOnly,
        'plane socket present, no gateway',
      );
    }
    return const _Discovered(
      ServerDiscovery.nothing,
      'no gateway, no plane socket',
    );
  }

  /// Writes this app's token into the existing gateway's tokens directory and
  /// returns the token.
  ///
  /// Only the SHA-256 of the token goes into the command, and a hash is not a
  /// secret. The token itself never appears in a command, an event or a log.
  /// The file is named by profile id, so a re-run rewrites it instead of adding
  /// one, and deleting it revokes only this app.
  Future<String> _issueToken(
    SshSession session,
    ServerProfile profile,
    _Discovered found,
  ) async {
    const stage = BootstrapStage.issueToken;
    if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(profile.id)) {
      throw _StageFailure(stage, 'the profile id cannot name a token file');
    }
    final stored = await _guard(
      stage,
      'reading the stored token',
      () => _profiles.gatewayToken(profile.id),
    );
    final token = _orNew(stored);
    final hash = 'sha256:${sha256.convert(utf8.encode(token))}';
    final dir = found.tokensDirectory;
    final file = '$dir/${profile.id}';
    final temporary = '$file.tmp';
    final script =
        "umask 077 && mkdir -p ${_quote(dir)} "
        "&& printf '%s\\n' ${_quote(hash)} > ${_quote(temporary)} "
        '&& mv -f ${_quote(temporary)} ${_quote(file)}';
    await _mustRun(
      session,
      stage,
      'writing the token file',
      'docker exec ${_quote(found.gatewayId)} sh -c ${_quote(script)}',
    );
    return token;
  }

  /// A stored secret, or a new one.
  String _orNew(String? existing) =>
      existing == null || existing.length < minimumSecretLength
      ? _newSecret()
      : existing;

  /// 32 base64url characters from a cryptographic source.
  ///
  /// `Random.secure()` is not injectable on purpose. A seam here would be a
  /// seam through which a test — or a copy of a test — could put a predictable
  /// gateway token into the one class whose whole job is generating real ones.
  String _newSecret() {
    final random = Random.secure();
    final bytes = Uint8List(_secretBytes);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64Url.encode(bytes);
  }

  /// Runs a command and returns whatever it did, failure included.
  Future<SshCommandResult> _run(
    SshSession session,
    BootstrapStage stage,
    String what,
    String command,
  ) => _guard(stage, what, () => session.run(command));

  /// Runs a command that must succeed.
  Future<SshCommandResult> _mustRun(
    SshSession session,
    BootstrapStage stage,
    String what,
    String command,
  ) async {
    final result = await _run(session, stage, what, command);
    if (!result.ok) {
      // The command itself is deliberately absent from the message: it may hold
      // a path, a URL or a public key, and the useful half is the output.
      throw _StageFailure(
        stage,
        '$what failed with exit ${result.exitCode}',
        result.stderr,
      );
    }
    return result;
  }

  /// Turns anything thrown into a stage failure, so the stream reports which
  /// step broke instead of ending in an unhandled error.
  ///
  /// [Error]s are let through. `dartssh2` throws `SSHError`, which is neither an
  /// [Error] nor an [Exception], and a socket throws an [Exception] — those are
  /// server problems and belong in an event. An [Error] is a bug in this code or
  /// in the test driving it, [UnexpectedSshRequest] above all, and reporting it
  /// as "the server failed" would hide exactly the mistake it exists to reveal.
  Future<T> _guard<T>(
    BootstrapStage stage,
    String what,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on _StageFailure {
      rethrow;
    } on Error {
      rethrow;
    } catch (error) {
      throw _StageFailure(stage, '$what failed: $error');
    }
  }
}

/// Wraps a value for a POSIX shell.
///
/// Single quotes, with any single quote in the value closed and reopened around
/// an escaped one. Paths and public keys are the only things that ever go
/// through here, but a repository URL comes from a constructor argument and an
/// unquoted argument is how a path with a space becomes two arguments.
String _quote(String value) => "'${value.replaceAll("'", r"'\''")}'";

/// What [SshBootstrap._discover] found, with the ids later stages need.
class _Discovered {
  const _Discovered(
    this.discovery,
    this.detail, {
    this.gatewayId = '',
    this.caddyId = '',
    this.tokensDirectory = '',
    this.port = 0,
  });

  final ServerDiscovery discovery;
  final String detail;
  final String gatewayId;
  final String caddyId;
  final String tokensDirectory;
  final int port;
}

/// A stage that failed, on its way to becoming a [BootstrapStageFailed].
///
/// Private and never surfaced: the stream yields an event instead of throwing,
/// because a failure mid-bootstrap is an outcome the UI has to render, not an
/// exception it should have to catch.
class _StageFailure implements Exception {
  _StageFailure(this.stage, this.reason, [this.stderr = '']);

  final BootstrapStage stage;
  final String reason;
  final String stderr;

  @override
  String toString() => '_StageFailure(${stage.name}: $reason)';
}
