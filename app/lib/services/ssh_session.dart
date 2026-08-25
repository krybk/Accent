import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:pinenacl/ed25519.dart' as ed25519;

/// Where and as whom to connect.
///
/// A value type rather than a pile of named parameters because the bootstrap
/// connects to the same endpoint twice — once with the root password, then
/// again with the key it just installed — and the two calls must not be able to
/// disagree about the address. No credential lives here, so an endpoint is safe
/// to log, compare and put in an error message.
class SshEndpoint {
  const SshEndpoint({
    required this.host,
    required this.username,
    this.port = 22,
    this.timeout = const Duration(seconds: 15),
  });

  final String host;
  final String username;
  final int port;

  /// How long to wait for the TCP connection. Without a bound, a typo in the
  /// address leaves the add-a-server screen spinning until the platform's own
  /// timeout expires, which on a mobile network can be minutes.
  final Duration timeout;

  @override
  String toString() => 'SshEndpoint($username@$host:$port)';
}

/// What a remote command did.
class SshCommandResult {
  const SshCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  /// The remote exit code, or -1 when the process was killed by a signal or the
  /// server reported no code at all. Both are failures as far as bootstrap is
  /// concerned, so folding them into one non-zero value spares every caller a
  /// null check whose two branches would be identical.
  final int exitCode;

  final String stdout;

  /// Kept separate from [stdout] deliberately. A failed `docker compose up`
  /// says everything useful here, and a bootstrap that can only report "it
  /// failed" is the thing this interface exists to avoid.
  final String stderr;

  bool get ok => exitCode == 0;

  /// Safe to log: it carries the command's output but never the command, which
  /// may contain a key or a password.
  @override
  String toString() =>
      'SshCommandResult(exit $exitCode, '
      '${stdout.length} B out, ${stderr.length} B err)';
}

/// An open SSH connection, reduced to what the bootstrap needs.
///
/// An interface rather than a direct dependency on `dartssh2` for the same
/// reason `SecretStore` is one: `dartssh2` opens sockets, so anything using it
/// directly can only be tested on a device. The orchestration that will sit on
/// top of this is precisely the part that must be testable on the host, which
/// is what [ScriptedSshSession] is for.
abstract interface class SshSession {
  /// Runs [command] to completion and collects its output.
  Future<SshCommandResult> run(String command);

  /// Writes [bytes] to [remotePath], creating or truncating it.
  Future<void> upload(String remotePath, Uint8List bytes);

  /// Closes the connection. Safe to call more than once.
  Future<void> close();
}

/// Opens sessions. Separate from [SshSession] because the whole point of the
/// bootstrap is moving from the first credential to the second: connect with
/// the password the user typed, install a key, reconnect with the key alone,
/// and never store the password.
abstract interface class SshSessionFactory {
  /// Opens a session with a password. The password is used and dropped; nothing
  /// here stores or logs it.
  Future<SshSession> connectWithPassword(SshEndpoint endpoint, String password);

  /// Opens a session with a private key in OpenSSH PEM form, as produced by
  /// [SshKeys.generate] and held by the secret store.
  Future<SshSession> connectWithKey(SshEndpoint endpoint, String privateKeyPem);
}

/// A freshly generated key, in the two forms the caller actually needs: a line
/// to append to the server's `authorized_keys`, and text for the key store.
///
/// Raw key bytes are deliberately not exposed. The only thing a caller could do
/// with them is re-derive one of these two, and getting the wire encoding wrong
/// is the failure this class exists to prevent.
class GeneratedSshKey {
  const GeneratedSshKey({
    required this.privateKeyPem,
    required this.authorizedKeysLine,
    required this.comment,
  });

  /// The private half, OpenSSH PEM. Goes straight into the secret store; must
  /// never be logged or serialised into a profile.
  final String privateKeyPem;

  /// The public half, ready to append to `~/.ssh/authorized_keys`.
  final String authorizedKeysLine;

  final String comment;

  /// Names the key without revealing it. [privateKeyPem] is not printable and
  /// this must stay the reason it never accidentally is.
  @override
  String toString() => 'GeneratedSshKey($comment)';
}

/// Key generation and the `authorized_keys` encoding.
abstract final class SshKeys {
  /// Generates an ed25519 key pair.
  ///
  /// `dartssh2` reads keys but cannot generate them, so the key is built with
  /// `pinenacl` — the same ed25519 implementation `dartssh2` signs with, which
  /// keeps a second crypto library out of the dependency tree — and handed over
  /// as raw bytes, private half in the 64-byte seed‖public form.
  static GeneratedSshKey generate({String comment = 'accent'}) {
    final signing = ed25519.SigningKey.generate();
    final keyPair = OpenSSHEd25519KeyPair(
      Uint8List.fromList(signing.publicKey.toUint8List()),
      Uint8List.fromList(signing.toUint8List()),
      comment,
    );
    return GeneratedSshKey(
      privateKeyPem: keyPair.toPem(),
      authorizedKeysLine: authorizedKeysLine(keyPair.publicKey, comment),
      comment: comment,
    );
  }

  /// Rebuilds the `authorized_keys` line from a stored PEM, so a key already in
  /// the secret store can be installed on another server without the caller
  /// ever unpacking it. [comment] defaults to the one inside the PEM.
  ///
  /// Throws [ArgumentError] if the PEM is not an unencrypted OpenSSH ed25519
  /// key — the only kind [generate] produces.
  static String authorizedKeysLineFromPem(String pem, {String? comment}) {
    final List<SSHKeyPair> keys;
    try {
      keys = SSHKeyPair.fromPem(pem);
    } catch (error) {
      // The message is the parser's own and describes the container, not the
      // key material, so it is safe to pass on.
      throw ArgumentError('Not a readable private key PEM: $error');
    }
    final key = keys.isEmpty ? null : keys.first;
    if (key is! OpenSSHEd25519KeyPair) {
      throw ArgumentError(
        'Expected an OpenSSH ed25519 key, got ${key?.type ?? 'nothing'}',
      );
    }
    return authorizedKeysLine(key.publicKey, comment ?? key.comment);
  }

  /// Encodes a public key the way `sshd` wants it in `authorized_keys`:
  /// `ssh-ed25519 <base64 of SSH wire format> <comment>`.
  ///
  /// The wire format is length-prefixed strings, not the raw 32 bytes. Getting
  /// this wrong produces a line `sshd` silently ignores, which then presents as
  /// an authentication failure rather than an encoding mistake — which is why
  /// the encoding is written out here and pinned by a test on known bytes,
  /// rather than assembled at the call site.
  static String authorizedKeysLine(Uint8List publicKey, String comment) {
    final builder = BytesBuilder();
    void writeString(List<int> bytes) {
      builder.add([
        (bytes.length >> 24) & 0xff,
        (bytes.length >> 16) & 0xff,
        (bytes.length >> 8) & 0xff,
        bytes.length & 0xff,
      ]);
      builder.add(bytes);
    }

    writeString(utf8.encode('ssh-ed25519'));
    writeString(publicKey);
    return 'ssh-ed25519 ${base64.encode(builder.toBytes())} $comment';
  }
}

/// The real thing: `dartssh2` over a socket.
class DartsshSessionFactory implements SshSessionFactory {
  const DartsshSessionFactory();

  @override
  Future<SshSession> connectWithPassword(
    SshEndpoint endpoint,
    String password,
  ) async {
    final client = SSHClient(
      await SSHSocket.connect(
        endpoint.host,
        endpoint.port,
        timeout: endpoint.timeout,
      ),
      username: endpoint.username,
      // A callback rather than a stored field: dartssh2 asks for the password
      // when it needs it, and this closure is the only place it lives.
      onPasswordRequest: () => password,
    );
    return _authenticate(client, endpoint);
  }

  @override
  Future<SshSession> connectWithKey(
    SshEndpoint endpoint,
    String privateKeyPem,
  ) async {
    final client = SSHClient(
      await SSHSocket.connect(
        endpoint.host,
        endpoint.port,
        timeout: endpoint.timeout,
      ),
      username: endpoint.username,
      identities: SSHKeyPair.fromPem(privateKeyPem),
    );
    return _authenticate(client, endpoint);
  }

  /// Waits for authentication before handing the session out, so a caller never
  /// holds a session that will fail on its first command.
  Future<SshSession> _authenticate(
    SSHClient client,
    SshEndpoint endpoint,
  ) async {
    try {
      await client.authenticated;
    } catch (_) {
      await client.close();
      rethrow;
    }
    return DartsshSession(client);
  }
}

/// A `dartssh2` connection behind the [SshSession] interface.
class DartsshSession implements SshSession {
  DartsshSession(this._client);

  final SSHClient _client;
  SftpClient? _sftp;
  bool _closed = false;

  @override
  Future<SshCommandResult> run(String command) async {
    final result = await _client.runWithResult(command);
    return SshCommandResult(
      // dartssh2 reports null when the process died on a signal or the server
      // sent no exit status; see the note on SshCommandResult.exitCode.
      exitCode: result.exitCode ?? -1,
      stdout: utf8.decode(result.stdout, allowMalformed: true),
      stderr: utf8.decode(result.stderr, allowMalformed: true),
    );
  }

  @override
  Future<void> upload(String remotePath, Uint8List bytes) async {
    // One SFTP subsystem for the whole session: the bootstrap uploads several
    // files in a row, and opening a channel per file is pure round trips.
    final sftp = _sftp ??= await _client.sftp();
    final file = await sftp.open(
      remotePath,
      mode:
          SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    try {
      await file.write(Stream.value(bytes));
    } finally {
      await file.close();
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _sftp?.close();
    await _client.close();
  }
}

/// Thrown when a [ScriptedSshSession] is asked to do something the test did not
/// script. An [Error] rather than an exception on purpose: it means the code
/// under test and the test disagree about what should happen, which is a bug in
/// one of them and never something to recover from.
class UnexpectedSshRequest extends Error {
  UnexpectedSshRequest(this.message);

  final String message;

  @override
  String toString() => 'UnexpectedSshRequest: $message';
}

/// One scripted command: what is expected, and what to answer.
class ScriptedCommand {
  const ScriptedCommand(this.expected, this.result);

  /// Succeeds with empty output. The common case, since most of what the
  /// bootstrap runs is checked by its exit code alone.
  ScriptedCommand.ok(Pattern expected)
    : this(
        expected,
        const SshCommandResult(exitCode: 0, stdout: '', stderr: ''),
      );

  /// What the command must match. A [String] matches as a substring, a
  /// [RegExp] as a pattern — so a test can pin the part it cares about without
  /// restating quoting and paths it does not.
  final Pattern expected;

  final SshCommandResult result;

  bool matches(String command) => expected.allMatches(command).isNotEmpty;

  @override
  String toString() => 'ScriptedCommand($expected)';
}

/// A file a [ScriptedSshSession] was asked to upload.
class RecordedUpload {
  const RecordedUpload(this.remotePath, this.bytes);

  final String remotePath;
  final Uint8List bytes;

  String get text => utf8.decode(bytes, allowMalformed: true);

  @override
  String toString() => 'RecordedUpload($remotePath, ${bytes.length} B)';
}

/// A session that answers a fixed script.
///
/// It lives in `lib/` beside the real implementation rather than in a test
/// file, because the orchestration built on top of [SshSession] needs it too
/// and a fake that lives in one test file gets copied into the second.
///
/// The strictness is the point. Commands are answered in order and each must
/// match what was scripted; anything else throws [UnexpectedSshRequest]. A fake
/// that returned success for a command nobody anticipated would let the
/// orchestrator's tests pass while proving nothing.
class ScriptedSshSession implements SshSession {
  ScriptedSshSession([Iterable<ScriptedCommand> script = const []])
    : _script = List.of(script);

  final List<ScriptedCommand> _script;

  /// Every command asked for, in order, including the one that threw. Tests
  /// assert on this rather than on the script, so a command run twice or in the
  /// wrong order is visible.
  final List<String> commands = [];

  final List<RecordedUpload> uploads = [];

  bool get closed => _closed;
  bool _closed = false;

  /// Commands scripted but never asked for. A bootstrap that silently stops
  /// halfway leaves this non-empty, which is the cheapest way for a test to
  /// notice.
  List<ScriptedCommand> get pending => List.unmodifiable(_script);

  /// Adds to the end of the script. Convenient when a test builds up a run in
  /// the order it reads.
  void expectCommand(Pattern expected, [SshCommandResult? result]) {
    _script.add(
      result == null
          ? ScriptedCommand.ok(expected)
          : ScriptedCommand(expected, result),
    );
  }

  @override
  Future<SshCommandResult> run(String command) async {
    commands.add(command);
    if (_closed) {
      throw UnexpectedSshRequest('ran a command after close: $command');
    }
    if (_script.isEmpty) {
      throw UnexpectedSshRequest('the script is exhausted, but ran: $command');
    }
    final next = _script.first;
    if (!next.matches(command)) {
      throw UnexpectedSshRequest(
        'expected ${next.expected}, but ran: $command',
      );
    }
    _script.removeAt(0);
    return next.result;
  }

  @override
  Future<void> upload(String remotePath, Uint8List bytes) async {
    if (_closed) {
      throw UnexpectedSshRequest('uploaded after close: $remotePath');
    }
    uploads.add(RecordedUpload(remotePath, bytes));
  }

  @override
  Future<void> close() async => _closed = true;
}

/// How a [ScriptedSshSessionFactory] was asked to authenticate.
enum SshCredentialKind { password, key }

/// One connection attempt, recorded without the credential.
///
/// The credential is deliberately absent rather than redacted: a field that
/// holds a password is a field that can be printed by accident. What a test
/// needs to know is that the second connection used a key and not the password
/// the user typed, and [kind] says that.
class RecordedConnection {
  const RecordedConnection(this.endpoint, this.kind);

  final SshEndpoint endpoint;
  final SshCredentialKind kind;

  @override
  String toString() => 'RecordedConnection($endpoint, by ${kind.name})';
}

/// Hands out scripted sessions and records how each was opened.
///
/// Sessions are returned in the order given. Asking for one more than was
/// scripted throws [UnexpectedSshRequest] rather than inventing a session, for
/// the same reason [ScriptedSshSession] refuses an unscripted command.
class ScriptedSshSessionFactory implements SshSessionFactory {
  ScriptedSshSessionFactory(Iterable<ScriptedSshSession> sessions)
    : _sessions = List.of(sessions);

  final List<ScriptedSshSession> _sessions;

  final List<RecordedConnection> connections = [];

  @override
  Future<SshSession> connectWithPassword(
    SshEndpoint endpoint,
    String password,
  ) async => _next(endpoint, SshCredentialKind.password);

  @override
  Future<SshSession> connectWithKey(
    SshEndpoint endpoint,
    String privateKeyPem,
  ) async => _next(endpoint, SshCredentialKind.key);

  ScriptedSshSession _next(SshEndpoint endpoint, SshCredentialKind kind) {
    connections.add(RecordedConnection(endpoint, kind));
    if (_sessions.isEmpty) {
      throw UnexpectedSshRequest(
        'no session left to open for $endpoint by ${kind.name}',
      );
    }
    return _sessions.removeAt(0);
  }
}
