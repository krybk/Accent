/// Configuration, read once from the environment at start-up.
library;

import 'package:accent_protocol/protocol.dart';

/// Directory of per-device token files; inside the gateway-data volume.
const defaultTokensDir = '/var/lib/accent/tokens.d';

class GatewayConfig {
  const GatewayConfig({
    required this.token,
    required this.litellmUrl,
    required this.litellmKey,
    this.port = 8080,
    this.planeSocket,
    this.tokensDir = defaultTokensDir,
  });

  /// Bearer token the app must present. It is the credential for everything the
  /// gateway forwards, the control plane included, so treat it as seriously as
  /// any credential on the host.
  final String token;

  /// Null when no model provider is configured; then POST /v1/chat answers 503
  /// and /v1/health probes nothing.
  final Uri? litellmUrl;
  final String litellmKey;
  final int port;

  /// Path of the control plane's unix socket; `/v1/plane/*` is forwarded to it.
  /// Null when no plane is configured.
  final String? planeSocket;

  /// Directory whose files each hold `sha256:<hex>` of one device's token; see
  /// auth.dart.
  final String tokensDir;

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
    // A short token is a guessable token, and this one guards everything the
    // gateway forwards.
    if (token.length < 32) {
      throw const ApiError(
        code: 'config_weak_token',
        message: 'GATEWAY_TOKEN must be at least 32 characters',
      );
    }

    return GatewayConfig(
      token: token,
      litellmUrl: (env['LITELLM_URL'] ?? '').isEmpty
          ? null
          : Uri.parse(env['LITELLM_URL']!),
      litellmKey: required('LITELLM_MASTER_KEY'),
      port: int.tryParse(env['PORT'] ?? '') ?? 8080,
      planeSocket: (env['PLANE_SOCKET'] ?? '').isEmpty
          ? null
          : env['PLANE_SOCKET'],
      tokensDir: (env['GATEWAY_TOKENS_DIR'] ?? '').isEmpty
          ? defaultTokensDir
          : env['GATEWAY_TOKENS_DIR']!,
    );
  }
}
