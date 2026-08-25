import 'dart:convert';
import 'dart:typed_data';

import 'package:accent/services/ssh_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// A public key with no interesting structure, so a byte-order or offset slip in
/// the encoding shows up as a different value rather than as the same one.
final knownPublicKey = Uint8List.fromList(
  List<int>.generate(SshKeys.ed25519PublicKeyLength, (i) => i + 1),
);

/// The wire encoding of [knownPublicKey], written out from RFC 4253 §6.6 rather
/// than produced by the code under test: two length-prefixed strings, each
/// prefix a four-byte big-endian count.
const expectedBlob = <int>[
  // 11, the length of "ssh-ed25519".
  0x00, 0x00, 0x00, 0x0b,
  // "ssh-ed25519", byte by byte, so the test does not lean on the same
  // utf8.encode call the implementation uses.
  0x73, 0x73, 0x68, 0x2d, 0x65, 0x64, 0x32, 0x35, 0x35, 0x31, 0x39,
  // 32, the length of an ed25519 public key. The value sshd reads to know how
  // many bytes of key follow; the bug this pins is emitting the 32 bytes with
  // no prefix at all.
  0x00, 0x00, 0x00, 0x20,
  // knownPublicKey.
  0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, //
  0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, //
  0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, //
  0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20, //
];

void main() {
  group('the authorized_keys line', () {
    test('has the exact expected bytes, length prefixes included', () {
      final line = SshKeys.authorizedKeysLine(knownPublicKey, 'accent-test');
      final fields = line.split(' ');

      expect(fields, hasLength(3));
      expect(fields[0], 'ssh-ed25519');
      expect(fields[2], 'accent-test');
      expect(base64.decode(fields[1]), expectedBlob);
    });

    test('base64-encodes that blob exactly as sshd expects to read it', () {
      // The literal is redundant against the byte comparison above and that is
      // the point: it also pins the alphabet and the padding, so a switch to
      // base64Url would fail here rather than on a server.
      //
      // The AAAAC3NzaC1lZDI1NTE5AAAAI prefix is the one every real ed25519
      // public key line starts with, which is what makes this an external
      // check rather than a restatement of our own encoding.
      expect(
        SshKeys.authorizedKeysLine(knownPublicKey, 'accent-test'),
        'ssh-ed25519 '
        'AAAAC3NzaC1lZDI1NTE5AAAAIAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8g '
        'accent-test',
      );
    });

    test('refuses a key that is not 32 bytes', () {
      // Any other length still produces a syntactically valid line, so without
      // this the mistake surfaces as a server that rejects the key.
      expect(
        () => SshKeys.authorizedKeysLine(Uint8List(31), 'short'),
        throwsArgumentError,
      );
    });
  });

  group('key generation', () {
    test('a generated key survives export to PEM and back', () {
      final key = SshKeys.generate(comment: 'accent-round-trip');

      // Re-deriving the public line from the stored PEM proves the private half
      // came back intact: the line is computed from the public key inside it.
      expect(
        SshKeys.authorizedKeysLineFromPem(key.privateKeyPem),
        key.authorizedKeysLine,
      );
    });

    test('the PEM is the OpenSSH container the key store will hold', () {
      final key = SshKeys.generate();

      expect(key.privateKeyPem, startsWith('-----BEGIN OPENSSH'));
      expect(key.privateKeyPem.trimRight(), endsWith('KEY-----'));
    });

    test('the comment travels with the key', () {
      final key = SshKeys.generate(comment: 'accent-srv_1');

      expect(key.comment, 'accent-srv_1');
      expect(key.authorizedKeysLine, endsWith(' accent-srv_1'));
      expect(
        SshKeys.authorizedKeysLineFromPem(key.privateKeyPem),
        endsWith(' accent-srv_1'),
      );
      // And a caller can override it without touching the key material, which
      // is how the same key gets installed on a second server.
      expect(
        SshKeys.authorizedKeysLineFromPem(key.privateKeyPem, comment: 'other'),
        endsWith(' other'),
      );
    });

    test('the line carries a 32-byte key under the right prefixes', () {
      final key = SshKeys.generate();
      final blob = base64.decode(key.authorizedKeysLine.split(' ')[1]);

      expect(blob, hasLength(expectedBlob.length));
      // Everything but the key itself is fixed, so it must match the golden
      // blob's header byte for byte.
      expect(blob.sublist(0, 19), expectedBlob.sublist(0, 19));
    });

    test('two generated keys are different keys', () {
      // Cheap, and it is the one failure mode that would leave every server
      // sharing one key while every other test still passed.
      expect(
        SshKeys.generate().authorizedKeysLine,
        isNot(SshKeys.generate().authorizedKeysLine),
      );
    });

    test('a PEM that is not an ed25519 key is refused, not guessed at', () {
      expect(
        () => SshKeys.authorizedKeysLineFromPem('not a pem at all'),
        throwsArgumentError,
      );
    });
  });

  group('the scripted session', () {
    test('returns queued results in order', () async {
      final session = ScriptedSshSession([
        ScriptedCommand(
          'docker --version',
          const SshCommandResult(
            exitCode: 0,
            stdout: 'Docker version 27.0.0\n',
            stderr: '',
          ),
        ),
        ScriptedCommand(
          'docker compose up',
          const SshCommandResult(
            exitCode: 1,
            stdout: '',
            stderr: 'no configuration file provided\n',
          ),
        ),
      ]);

      final first = await session.run('docker --version');
      expect(first.ok, isTrue);
      expect(first.stdout, startsWith('Docker version'));

      final second = await session.run('docker compose up -d');
      expect(second.ok, isFalse);
      expect(second.exitCode, 1);
      // The reason a caller can act on, which is why stderr is its own field.
      expect(second.stderr, contains('no configuration file'));
    });

    test('records the commands it saw', () async {
      final session = ScriptedSshSession([
        ScriptedCommand.ok('mkdir'),
        ScriptedCommand.ok('chmod'),
      ]);

      await session.run('mkdir -p /opt/accent');
      await session.run('chmod 700 /opt/accent');

      expect(session.commands, [
        'mkdir -p /opt/accent',
        'chmod 700 /opt/accent',
      ]);
      expect(session.pending, isEmpty);
    });

    test('throws on an unexpected command rather than succeeding', () async {
      final session = ScriptedSshSession([ScriptedCommand.ok('docker')]);

      // The whole reason the fake exists: answering an unanticipated command
      // with success would let an orchestrator test pass while proving nothing.
      await expectLater(
        session.run('rm -rf /'),
        throwsA(isA<UnexpectedSshRequest>()),
      );
      // And it is still recorded, so the failure names what was actually run.
      expect(session.commands, ['rm -rf /']);
    });

    test('throws once the script is exhausted', () async {
      final session = ScriptedSshSession([ScriptedCommand.ok('uname')]);
      await session.run('uname -s');

      await expectLater(
        session.run('uname -s'),
        throwsA(isA<UnexpectedSshRequest>()),
      );
    });

    test('a command out of order is a failure, not a match', () async {
      final session = ScriptedSshSession([
        ScriptedCommand.ok('mkdir'),
        ScriptedCommand.ok('chmod'),
      ]);

      // 'chmod' is scripted, but not yet. Order matters: the bootstrap that
      // sets permissions before creating the directory is broken.
      await expectLater(
        session.run('chmod 700 /opt/accent'),
        throwsA(isA<UnexpectedSshRequest>()),
      );
    });

    test('a RegExp matches as a pattern, a String as a substring', () async {
      final session = ScriptedSshSession([
        ScriptedCommand.ok(RegExp(r'^docker compose -f \S+ up -d$')),
      ]);

      await expectLater(
        session.run('docker compose -f /opt/a.yml up'),
        throwsA(isA<UnexpectedSshRequest>()),
      );

      final anchored = ScriptedSshSession([
        ScriptedCommand.ok(RegExp(r'^docker compose -f \S+ up -d$')),
      ]);
      expect(
        (await anchored.run('docker compose -f /opt/a.yml up -d')).ok,
        isTrue,
      );
    });

    test('scripting after construction reads in run order', () async {
      final session = ScriptedSshSession()
        ..expectCommand('mkdir')
        ..expectCommand(
          'docker',
          const SshCommandResult(
            exitCode: 127,
            stdout: '',
            stderr: 'no docker',
          ),
        );

      expect((await session.run('mkdir -p /opt/accent')).ok, isTrue);
      expect((await session.run('docker --version')).exitCode, 127);
    });

    test('unrun scripted commands stay visible', () async {
      final session = ScriptedSshSession([
        ScriptedCommand.ok('mkdir'),
        ScriptedCommand.ok('docker compose up'),
      ]);

      await session.run('mkdir -p /opt/accent');

      // A bootstrap that stops halfway leaves this non-empty, which is how a
      // test notices it never reached the step that mattered.
      expect(session.pending, hasLength(1));
      expect(session.pending.single.expected, 'docker compose up');
    });

    test('records uploads with their bytes', () async {
      final session = ScriptedSshSession();

      await session.upload(
        '/opt/accent/compose.yaml',
        Uint8List.fromList(utf8.encode('services:\n')),
      );

      expect(session.uploads.single.remotePath, '/opt/accent/compose.yaml');
      expect(session.uploads.single.text, 'services:\n');
    });

    test('work after close is a failure, not a silent success', () async {
      final session = ScriptedSshSession([ScriptedCommand.ok('uname')]);

      await session.close();
      expect(session.closed, isTrue);
      // Closing twice is allowed; the interface promises that.
      await session.close();

      await expectLater(
        session.run('uname -s'),
        throwsA(isA<UnexpectedSshRequest>()),
      );
      await expectLater(
        session.upload('/tmp/x', Uint8List(0)),
        throwsA(isA<UnexpectedSshRequest>()),
      );
    });
  });

  group('the scripted factory', () {
    const endpoint = SshEndpoint(host: '192.0.2.10', username: 'root');

    test(
      'hands out sessions in order and records how each was opened',
      () async {
        final byPassword = ScriptedSshSession([ScriptedCommand.ok('id -un')]);
        final byKey = ScriptedSshSession([ScriptedCommand.ok('whoami')]);
        final factory = ScriptedSshSessionFactory([byPassword, byKey]);

        final first = await factory.connectWithPassword(endpoint, 'a-password');
        final second = await factory.connectWithKey(endpoint, 'a-pem');

        expect(first, same(byPassword));
        expect(second, same(byKey));
        // The transition this whole design exists to make: the second connection
        // used the key, not the password the user typed.
        expect(factory.connections.map((c) => c.kind), [
          SshCredentialKind.password,
          SshCredentialKind.key,
        ]);
        expect(factory.connections.first.endpoint.host, '192.0.2.10');
      },
    );

    test('refuses to invent a session it was not given', () async {
      final factory = ScriptedSshSessionFactory(const []);

      await expectLater(
        factory.connectWithPassword(endpoint, 'a-password'),
        throwsA(isA<UnexpectedSshRequest>()),
      );
      // Recorded even though it failed, so the test can say which connection
      // was one too many.
      expect(factory.connections, hasLength(1));
    });
  });

  group('hygiene', () {
    test('a generated key cannot be printed by accident', () {
      final key = SshKeys.generate(comment: 'accent-srv_1');

      final text = key.toString();
      expect(text, contains('accent-srv_1'));
      expect(text, isNot(contains('BEGIN')));
      expect(text, isNot(contains(key.privateKeyPem)));
    });

    test('a recorded connection has nowhere to keep a credential', () async {
      final factory = ScriptedSshSessionFactory([ScriptedSshSession()]);
      await factory.connectWithPassword(
        const SshEndpoint(host: '192.0.2.10', username: 'root'),
        'hunter2',
      );

      // Absent rather than redacted: a field that can hold a password is a
      // field that can be printed by mistake.
      expect(factory.connections.single.toString(), isNot(contains('hunter2')));
      expect(
        factory.connections.single.toString(),
        'RecordedConnection(SshEndpoint(root@192.0.2.10:22), by password)',
      );
    });

    test('a command result describes itself without quoting the command', () {
      // The command may embed the authorized_keys line or a token, so the
      // result names sizes only.
      const result = SshCommandResult(
        exitCode: 1,
        stdout: 'out',
        stderr: 'boom',
      );

      expect(result.toString(), 'SshCommandResult(exit 1, 3 B out, 4 B err)');
    });
  });
}
