/// Bearer-token authentication.
library;

import 'dart:convert';

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

/// Rejects any request that does not carry the gateway token.
Middleware requireToken(String expected) => (innerHandler) {
  return (request) {
    if (_publicPaths.contains(request.url.path)) {
      return innerHandler(request);
    }

    final header = request.headers['authorization'] ?? '';
    const prefix = 'Bearer ';
    final presented = header.startsWith(prefix)
        ? header.substring(prefix.length)
        : '';

    if (!secureEquals(presented, expected)) {
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
