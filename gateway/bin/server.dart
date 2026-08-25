/// Gateway entry point.
library;

import 'dart:io';

import 'package:accent_gateway/src/auth.dart';
import 'package:accent_gateway/src/config.dart';
import 'package:accent_gateway/src/routes.dart';
import 'package:accent_protocol/protocol.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  final GatewayConfig config;
  try {
    config = GatewayConfig.fromEnvironment(Platform.environment);
  } on ApiError catch (error) {
    // Refusing to boot is the correct outcome: a gateway with no token would
    // accept everything, and it would do so silently.
    stderr.writeln('gateway: ${error.message}');
    exit(78); // EX_CONFIG
  }

  final client = http.Client();
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(requireToken(config.token))
      .addHandler(buildRouter(config, client).call);

  // Bound to all interfaces because Caddy reaches it across the compose
  // network. It is not published to the host — only Caddy's port is.
  final server = await io.serve(handler, InternetAddress.anyIPv4, config.port);
  stdout.writeln('gateway $gatewayVersion listening on ${server.port}');

  // Without this the container ignores `docker stop` until the 10s timeout and
  // is then killed, which loses in-flight streams on every deploy.
  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    signal.watch().listen((_) async {
      stdout.writeln('gateway: shutting down');
      await server.close(force: false);
      client.close();
      exit(0);
    });
  }
}
