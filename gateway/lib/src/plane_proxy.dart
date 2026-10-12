/// Forwards `/v1/plane/*` verbatim to the control plane's unix socket. The
/// gateway does not interpret the plane's contract.
library;

import 'dart:convert';
import 'dart:io';

import 'package:accent_protocol/protocol.dart';
import 'package:shelf/shelf.dart';

Response _jsonError(int status, String code, String message) => Response(
  status,
  body: jsonEncode(ApiError(code: code, message: message).toJson()),
  headers: {'content-type': 'application/json'},
);

/// Handler mounted at `/v1/plane/`; [socketPath] is null when no plane exists.
Handler planeProxy(String? socketPath) {
  return (Request request) async {
    if (socketPath == null) {
      return _jsonError(
        404,
        'plane_not_configured',
        'no control plane is configured on this server',
      );
    }
    if (request.method != 'GET' && request.method != 'POST') {
      return _jsonError(
        405,
        'method_not_allowed',
        'only GET and POST are forwarded',
      );
    }

    final body = await request.read().expand((chunk) => chunk).toList();

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3)
      ..connectionFactory = (uri, proxyHost, proxyPort) => Socket.startConnect(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );

    final target = Uri(
      scheme: 'http',
      host: 'plane',
      path: '/v1/plane/${request.url.path}',
      query: request.url.hasQuery ? request.url.query : null,
    );

    final HttpClientResponse response;
    try {
      final upstream = await client.openUrl(request.method, target);
      upstream.contentLength = body.length;
      final contentType = request.headers['content-type'];
      if (contentType != null) {
        upstream.headers.set('content-type', contentType);
      }
      upstream.add(body);
      response = await upstream.close().timeout(const Duration(seconds: 30));
    } on Object catch (error) {
      client.close(force: true);
      return _jsonError(
        503,
        'plane_unavailable',
        'control plane unreachable: $error',
      );
    }

    // Let the active response finish, then release the client.
    client.close();
    final responseType = response.headers.value('content-type');
    // The response is passed through unbuffered, never read into memory: a
    // streamed body (SSE) must reach the app as it is produced.
    return Response(
      response.statusCode,
      body: response,
      headers: {'content-type': ?responseType, 'x-accel-buffering': 'no'},
      context: {'shelf.io.buffer_output': false},
    );
  };
}
