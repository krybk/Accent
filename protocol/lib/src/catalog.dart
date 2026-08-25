/// Model catalogue and service status types.
library;

/// A model the gateway can route to.
///
/// [minCacheableTokens] is not decoration. Below it a provider silently declines
/// to cache, and the "cheap" tier then costs more than the expensive one with a
/// working cache. The app shows it so a model choice is made with that in view.
class ModelInfo {
  const ModelInfo({
    required this.id,
    required this.displayName,
    required this.inputUsdPerMillion,
    required this.outputUsdPerMillion,
    required this.cacheReadUsdPerMillion,
    required this.minCacheableTokens,
    required this.contextWindow,
  });

  final String    id;
  final String displayName;
    final double inputUsdPerMillion;
  final double outputUsdPerMillion;
  final double cacheReadUsdPerMillion;

  /// Minimum prefix length at which this model caches at all. Measured, not
  /// assumed: it differs fourfold between tiers of the same family.
  final int minCacheableTokens;

  final int contextWindow;

  /// How much cheaper a cached input token is than a fresh one. This is the
  /// number that decides whether a tier is worth using, far more than the
  /// headline input price.
  double get cacheSavingFactor => cacheReadUsdPerMillion == 0
      ? 0
      : inputUsdPerMillion / cacheReadUsdPerMillion;

  factory ModelInfo.fromJson(Map<String, dynamic> json) => ModelInfo(
    id: json['id'] as String,
    displayName: json['display_name'] as String,
    inputUsdPerMillion: (json['input_usd_per_million'] as num).toDouble(),
    outputUsdPerMillion: (json['output_usd_per_million'] as num).toDouble(),
    cacheReadUsdPerMillion: (json['cache_read_usd_per_million'] as num)
        .toDouble(),
    minCacheableTokens: json['min_cacheable_tokens'] as int,
    contextWindow: json['context_window'] as int,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'display_name': displayName,
    'input_usd_per_million': inputUsdPerMillion,
    'output_usd_per_million': outputUsdPerMillion,
    'cache_read_usd_per_million': cacheReadUsdPerMillion,
    'min_cacheable_tokens': minCacheableTokens,
    'context_window': contextWindow,
  };
}

/// State of one container in the deployed stack.
class ServiceStatus {
  const ServiceStatus({required this.name, required this.healthy, this.detail});

  final String name;
  final bool healthy;
  final String? detail;

  factory ServiceStatus.fromJson(Map<String, dynamic> json) => ServiceStatus(
    name: json['name'] as String,
    healthy: json['healthy'] as bool,
    detail: json['detail'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'healthy': healthy,
    if (detail != null) 'detail': detail,
  };
}

class HealthStatus {
  const HealthStatus({required this.version, required this.services});

  final String version;
  final List<ServiceStatus> services;

  bool get allHealthy => services.every((service) => service.healthy);

  factory HealthStatus.fromJson(Map<String, dynamic> json) => HealthStatus(
    version: json['version'] as String,
    services: (json['services'] as List<dynamic>)
        .map((item) => ServiceStatus.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'services': services.map((s) => s.toJson()).toList(),
  };
}

/// An error the gateway reports deliberately.
///
/// [code] is machine-readable and stable; [message] is for a human and may be
/// reworded freely. The app must branch on the code, never on the message.
class ApiError implements Exception {
  const ApiError({required this.code, required this.message});

  final String code;
  final String message;

  factory ApiError.fromJson(Map<String, dynamic> json) => ApiError(
    code: json['code'] as String,
    message: json['message'] as String,
  );

  Map<String, dynamic> toJson() => {'code': code, 'message': message};

  @override
  String toString() => 'ApiError($code): $message';
}
