// Probe: does dartssh2 cover the whole Accent bootstrap chain?
//
// The app's add-a-server flow needs, in order: connect with a password, run a
// command, generate an ed25519 key, upload files over SFTP, append the public
// half to authorized_keys, then reconnect using the key alone. If any link is
// missing in pure Dart, Flutter is the wrong stack for this app and Tauri with
// russh is the right one. This decides that, rather than guessing.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:pinenacl/ed25519.dart' as ed25519;

const host = '127.0.0.1';
const port = 22;
const user = 'accentprobe';

int failures = 0;

void step(String name, bool ok, [String detail = '']) {
  final mark = ok ? 'PASS' : 'FAIL';
  if (!ok) failures++;
  stdout.writeln('[$mark] $name${detail.isEmpty ? '' : ' — $detail'}');
}

/// Encodes a public key the way sshd wants it in authorized_keys:
/// `ssh-ed25519 <base64 of SSH wire format> <comment>`.
///
/// The wire format is length-prefixed strings, not the raw 32 bytes. Getting
/// this wrong produces a line sshd silently ignores, which then looks like a
/// dartssh2 authentication bug rather than an encoding bug — worth doing
/// explicitly here so the app never has to debug it later.
String authorizedKeysLine(Uint8List publicKey, String comment) {
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

Future<void> main() async {
  final password = File('/tmp/probe-pw').readAsStringSync();

  // 1. Password authentication — how a server is first added in the app.
  SSHClient? byPassword;
  try {
    byPassword = SSHClient(
      await SSHSocket.connect(host, port),
      username: user,
      onPasswordRequest: () => password,
    );
    await byPassword.authenticated;
    step('connect with password', true);
  } catch (e) {
    step('connect with password', false, '$e');
    exit(1);
  }

  // 2. Remote command execution — needed to check for Docker and bring the
  // stack up.
  try {
    final out = await byPassword.run('id -un && uname -s');
    final text = utf8.decode(out).trim().replaceAll('\n', ' ');
    step('run a remote command', text.contains(user), text);
  } catch (e) {
    step('run a remote command', false, '$e');
  }

  // 3. Key generation. dartssh2 reads keys but does not generate them, so the
  // key is built here and handed to it as raw bytes. pinenacl is the same
  // ed25519 implementation dartssh2 signs with, which avoids a second crypto
  // library in the dependency tree.
  late OpenSSHEd25519KeyPair keyPair;
  try {
    final signing = ed25519.SigningKey.generate();
    keyPair = OpenSSHEd25519KeyPair(
      Uint8List.fromList(signing.publicKey.toUint8List()),
      Uint8List.fromList(signing.toUint8List()),
      'accent-probe',
    );
    step(
      'generate an ed25519 key',
      true,
      'public ${keyPair.publicKey.length} B, private ${keyPair.privateKey.length} B',
    );
  } catch (e) {
    step('generate an ed25519 key', false, '$e');
    exit(1);
  }

  // 4. Persisting the key. The app stores the private half in the phone's key
  // store, so it must survive a round trip through text.
  try {
    final pem = keyPair.toPem();
    final restored = SSHKeyPair.fromPem(pem).first as OpenSSHEd25519KeyPair;
    final same =
        restored.privateKey.toString() == keyPair.privateKey.toString();
    step('export the key to PEM and read it back', same);
  } catch (e) {
    step('export the key to PEM and read it back', false, '$e');
  }

  // 5. SFTP upload — how the compose bundle reaches the server.
  try {
    final sftp = await byPassword.sftp();
    final file = await sftp.open(
      '/home/$user/probe-upload.txt',
      mode:
          SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    await file.write(
      Stream.value(Uint8List.fromList(utf8.encode('accent bootstrap probe\n'))),
    );
    await file.close();
    final back = utf8.decode(
      await byPassword.run('cat /home/$user/probe-upload.txt'),
    );
    step('upload a file over SFTP', back.trim() == 'accent bootstrap probe');
  } catch (e) {
    step('upload a file over SFTP', false, '$e');
  }

  // 6. Installing the public key, exactly as the app will do it.
  try {
    final line = authorizedKeysLine(keyPair.publicKey, 'accent-probe');
    await byPassword.run(
      'mkdir -p ~/.ssh && chmod 700 ~/.ssh && '
      "printf '%s\\n' '$line' >> ~/.ssh/authorized_keys && "
      'chmod 600 ~/.ssh/authorized_keys',
    );
    step('append the public key to authorized_keys', true);
  } catch (e) {
    step('append the public key to authorized_keys', false, '$e');
  }

  byPassword.close();

  // 7. The decisive step: reconnect with the key only, no password anywhere.
  // This is what lets the app forget the root password after bootstrap.
  try {
    final byKey = SSHClient(
      await SSHSocket.connect(host, port),
      username: user,
      identities: [keyPair],
    );
    await byKey.authenticated;
    final whoami = utf8.decode(await byKey.run('whoami')).trim();
    step('reconnect using the key alone', whoami == user, whoami);
    byKey.close();
  } catch (e) {
    step('reconnect using the key alone', false, '$e');
  }

  stdout.writeln(
    failures == 0
        ? '\nAll steps passed: dartssh2 covers the bootstrap chain.'
        : '\n$failures step(s) failed: dartssh2 does not cover the chain.',
  );
  exit(failures == 0 ? 0 : 1);
}
