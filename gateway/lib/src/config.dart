/// Configuration, read once from the environment at start-up.
library;

import 'package:accent_protocol/protocol.dart';

class GatewayConfig {
  const GatewayConfig({
    required this.token,
    required this.litellmUrl,
    required this.litellmKey,
    this.port = 8080,
  });

  /// Bearer token the app must present. Root-equivalent, because the gateway
  /// holds the Docker socket.
  final String token;

  final Uri litellmUrl;
  final String litellmKey;
  final int port;

  /// Reads configuration, failing loudly on anything missing.
  ///
  /// Deliberately no defaults for the secrets: a gateway that starts with an
  /// empty token would accept every request, and it would do so quietly. Better
  /// to refuse to boot.
  factory GatewayConfig.fromEnvironment(Map<String, String> env) {
    String required(String name) {
      final value = env[name];
      if (value == null || value.isEmpty) {
        throw ApiError(
          code: 'config_missing',
          message: '$name is not set; refusing to start',
        );
      }
      return value;
    }

    final token = required('GATEWAY_TOKEN');
    // A short token is a guessable token, and this one is root-equivalent.
    if (token.length < 32) {
      throw const ApiError(
        code: 'config_weak_token',
        message: 'GATEWAY_TOKEN must be at least 32 characters',
      );
    }

    return GatewayConfig(
      token: token,
      litellmUrl: Uri.parse(env['LITELLM_URL'] ?? 'http://litellm:4000'),
      litellmKey: required('LITELLM_MASTER_KEY'),
      port: int.tryParse(env['PORT'] ?? '') ?? 8080,
    );
  }
}
