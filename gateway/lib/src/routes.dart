/// HTTP surface of the gateway.
library;

import 'dart:async';
import 'dart:convert';

import 'package:accent_protocol/protocol.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'catalog.dart';
import 'config.dart';
import 'upstream_request.dart';

const gatewayVersion = '0.1.0';

Response _json(Object body, {int status = 200}) => Response(
  status,
  body: jsonEncode(body),
  headers: {'content-type': 'application/json'},
);

Response _error(ApiError error, {int status = 400}) =>
    _json(error.toJson(), status: status);

/// Builds the router. [client] is injectable so tests can drive the chat path
/// without a LiteLLM container.
Router buildRouter(GatewayConfig config, http.Client client) {
  final router = Router();

  // Liveness. Unauthenticated, and says nothing about the system beyond "the
  // process is answering" — this is what the container health check hits.
  router.get('/live', (Request _) => Response.ok('ok'));

  router.get('/v1/health', (Request _) async {
    final services = <ServiceStatus>[
      await _probe(
        'litellm',
        client,
        config.litellmUrl.resolve('/health/liveliness'),
        config.litellmKey,
      ),
    ];
    final status = HealthStatus(version: gatewayVersion, services: services);
    // 503 when degraded, so the app can react without parsing the body.
    return _json(status.toJson(), status: status.allHealthy ? 200 : 503);
  });

  // The catalogue the app populates its model picker from. Prices and cache
  // thresholds travel with it, so the choice is made with the cost in view.
  router.get(
    '/v1/models',
    (Request _) => _json({
      'models': modelCatalog.entries
          .map((entry) => {'tier': entry.key, ...entry.value.toJson()})
          .toList(),
    }),
  );

  router.post('/v1/chat', (Request request) async {
    final ChatRequest parsed;
    try {
      parsed = ChatRequest.fromJson(
        jsonDecode(await request.readAsString()) as Map<String, dynamic>,
      );
    } on Object catch (error) {
      return _error(ApiError(code: 'bad_request', message: '$error'));
    }

    final model = resolveTier(parsed.model);
    if (model == null) {
      // Named tiers only. Falling back to a default would turn a typo into a
      // bill on whichever tier the default happens to be.
      return _error(
        ApiError(
          code: 'unknown_tier',
          message:
              'unknown tier "${parsed.model}"; '
              'available: ${modelCatalog.keys.join(', ')}',
        ),
        status: 404,
      );
    }

    return Response.ok(
      _streamChat(config, client, parsed),
      headers: {
        'content-type': 'text/event-stream',
        'cache-control': 'no-cache',
        // Caddy is told to flush already; this covers any other proxy in front.
        'x-accel-buffering': 'no',
      },
      context: {'shelf.io.buffer_output': false},
    );
  });

  return router;
}

Future<ServiceStatus> _probe(
  String name,
  http.Client client,
  Uri url,
  String key,
) async {
  try {
    final response = await client
        .get(url, headers: {'authorization': 'Bearer $key'})
        .timeout(const Duration(seconds: 3));
    return ServiceStatus(
      name: name,
      healthy: response.statusCode == 200,
      detail: response.statusCode == 200 ? null : 'HTTP ${response.statusCode}',
    );
  } on Object catch (error) {
    return ServiceStatus(name: name, healthy: false, detail: '$error');
  }
}

/// Forwards a turn to LiteLLM and re-emits it as our own chunk stream.
///
/// The upstream shape is OpenAI-compatible SSE; we translate rather than proxy
/// verbatim so the app never depends on an upstream format we do not control.
Stream<List<int>> _streamChat(
  GatewayConfig config,
  http.Client client,
  ChatRequest request,
) async* {
  final body = buildUpstreamRequest(tier: request.model, request: request);

  final upstream =
      http.Request('POST', config.litellmUrl.resolve('/v1/chat/completions'))
        ..headers.addAll({
          'authorization': 'Bearer ${config.litellmKey}',
          'content-type': 'application/json',
        })
        ..body = jsonEncode(body);

  http.StreamedResponse response;
  try {
    response = await client.send(upstream);
  } on Object catch (error) {
    yield _frame(ChatChunk(text: null, done: true));
    yield _errorFrame('upstream_unreachable', '$error');
    return;
  }

  if (response.statusCode != 200) {
    final detail = await response.stream.bytesToString();
    yield _errorFrame('upstream_error', 'HTTP ${response.statusCode}: $detail');
    return;
  }

  String? servedModel;
  Usage? usage;

  await for (final line
      in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
    if (!line.startsWith('data:')) continue;
    final payload = line.substring(5).trim();
    if (payload.isEmpty || payload == '[DONE]') continue;

    final Map<String, dynamic> event;
    try {
      event = jsonDecode(payload) as Map<String, dynamic>;
    } on FormatException {
      continue; // A keep-alive or a comment frame; not fatal.
    }

    servedModel ??= event['model'] as String?;

    // Usage arrives on its own trailing event when include_usage is set, and
    // that event carries no choices — hence handling it before the delta.
    final rawUsage = event['usage'];
    if (rawUsage is Map<String, dynamic>) {
      usage = _readUsage(rawUsage);
    }

    final choices = event['choices'];
    if (choices is List && choices.isNotEmpty) {
      final delta = (choices.first as Map<String, dynamic>)['delta'];
      final text = delta is Map<String, dynamic> ? delta['content'] : null;
      if (text is String && text.isNotEmpty) {
        yield _frame(ChatChunk(text: text));
      }
    }
  }

  // Closing frame carries what the turn cost and whether the prefix was reused.
  yield _frame(ChatChunk(done: true, usage: usage, model: servedModel));
}

/// Normalises upstream usage into our own shape.
///
/// Field names differ by provider and by LiteLLM version: cached input arrives
/// either as `prompt_tokens_details.cached_tokens` (OpenAI shape) or as
/// `cache_read_input_tokens` (Anthropic shape). Reading only one of them is how
/// cache hits end up reported as zero on a system where caching works fine.
Usage _readUsage(Map<String, dynamic> raw) {
  final details = raw['prompt_tokens_details'];
  int pick(List<String> keys, Object? from) {
    if (from is! Map) return 0;
    for (final key in keys) {
      final value = from[key];
      if (value is int) return value;
    }
    return 0;
  }

  return Usage(
    inputTokens: pick(['prompt_tokens', 'input_tokens'], raw),
    outputTokens: pick(['completion_tokens', 'output_tokens'], raw),
    cacheReadTokens:
        pick(['cached_tokens'], details) +
        pick(['cache_read_input_tokens'], raw),
    cacheWriteTokens: pick(['cache_creation_input_tokens'], raw),
    costUsd: (raw['response_cost'] as num?)?.toDouble(),
  );
}

List<int> _frame(ChatChunk chunk) =>
    utf8.encode('data: ${jsonEncode(chunk.toJson())}\n\n');

List<int> _errorFrame(String code, String message) => utf8.encode(
  'data: ${jsonEncode({'error': ApiError(code: code, message: message).toJson()})}\n\n',
);
