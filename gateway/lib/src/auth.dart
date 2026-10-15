/// Bearer-token authentication.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';

/// Paths reachable without a credential.
///
/// Only liveness. A health check that needed the token would take the stack down
/// the moment the token was rotated, and a container that restarts on a rotated
/// credential is worse than no health check at all.
const _publicPaths = {'live'};

/// Compares two strings without leaking their difference through timing.
///
/// A plain `==` returns as soon as it finds a mismatched byte, so an attacker who
/// can measure response time learns the token prefix by prefix. Comparing every
/// byte regardless costs microseconds and removes that channel.
bool secureEquals(String a, String b) {
  final left = utf8.encode(a);
  final right = utf8.encode(b);
  // Length is not secret — it is visible in any request the client sends — but
  // returning early here would still reveal it, so fold it into the result.
  var mismatch = left.length ^ right.length;
  final shorter = left.length < right.length ? left.length : right.length;
  for (var i = 0; i < shorter; i++) {
    mismatch |= left[i] ^ right[i];
  }
  return mismatch == 0;
}

/// Rejects any request that does not carry a valid token.
///
/// A request passes with the environment token or with a token whose hash is in
/// a file of [tokensDir]. The directory is re-read on every request the
/// environment token does not match, with no cache, so writing or deleting a
/// file takes effect on the next request. One file per device: delete it to
/// revoke that device.
Middleware requireToken(String expected, {String? tokensDir}) =>
    (innerHandler) {
      return (request) {
        if (_publicPaths.contains(request.url.path)) {
          return innerHandler(request);
        }

        final header = request.headers['authorization'] ?? '';
        const prefix = 'Bearer ';
        final presented = header.startsWith(prefix)
            ? header.substring(prefix.length)
            : '';

        if (!(presented.isNotEmpty &&
            (secureEquals(presented, expected) ||
                _matchesTokenFile(presented, tokensDir)))) {
          // No detail in the body on purpose: distinguishing "no token" from
          // "wrong token" tells a prober whether it is on the right track.
          return Response.unauthorized(
            jsonEncode({'code': 'unauthorized', 'message': 'invalid token'}),
            headers: {'content-type': 'application/json'},
          );
        }

        return innerHandler(request);
      };
    };

final _hashLine = RegExp(r'^sha256:[0-9a-f]{64}$');

bool _matchesTokenFile(String presented, String? tokensDir) {
  if (presented.isEmpty || tokensDir == null) return false;
  final hash = 'sha256:${sha256.convert(utf8.encode(presented))}';
  final List<FileSystemEntity> entries;
  try {
    entries = Directory(tokensDir).listSync(followLinks: false);
  } on FileSystemException {
    return false; // No directory: only the environment token works.
  }
  // Every file is compared, with no early return, so the time taken does not
  // reveal which device's file matched.
  var matched = false;
  for (final entry in entries) {
    // A file being written is not yet a credential.
    if (entry is! File || entry.path.endsWith('.tmp')) continue;
    final String line;
    try {
      line = entry.readAsLinesSync().firstOrNull?.trim() ?? '';
    } on Object {
      continue; // Unreadable or not text: ignored, never a 500.
    }
    if (!_hashLine.hasMatch(line)) continue;
    if (secureEquals(hash, line)) matched = true;
  }
  return matched;
}
