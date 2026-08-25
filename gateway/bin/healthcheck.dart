/// Container health check.
///
/// A separate binary rather than `curl` in the compose file: the runtime image
/// is distroless, so it has no shell and no curl. Compiling this alongside the
/// server keeps the image minimal without giving up a health check.
library;

import 'dart:io';

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    // /live, not /v1/health: a health check must not need a credential, or
    // rotating the token would restart the container in a loop.
    final request = await client
        .get('127.0.0.1', port, '/live')
        .timeout(const Duration(seconds: 3));
    final response = await request.close().timeout(const Duration(seconds: 3));
    await response.drain<void>();
    exit(response.statusCode == 200 ? 0 : 1);
  } on Object {
    exit(1);
  } finally {
    client.close(force: true);
  }
}
