import 'dart:convert';

import 'package:accent_gateway/src/auth.dart';
import 'package:accent_gateway/src/config.dart';
import 'package:accent_gateway/src/routes.dart';
import 'package:accent_protocol/protocol.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const token = 'a-token-that-is-long-enough-to-pass-32';

GatewayConfig config() => GatewayConfig(
  token: token,
  litellmUrl: Uri.parse('http://litellm:4000'),
  litellmKey: 'internal-key',
);

/// Wraps the router in the same middleware chain the real server uses, so the
/// tests exercise authentication rather than bypassing it.
Handler handlerWith(http.Client client) => const Pipeline()
    .addMiddleware(requireToken(token))
    .addHandler(buildRouter(config(), client).call);

Request get(String path, {String? bearer}) => Request(
  'GET',
  Uri.parse('http://localhost/$path'),
  headers: bearer == null ? null : {'authorization': 'Bearer $bearer'},
);

/// Serialises upstream events the way LiteLLM does, so the parser is tested
/// against the real frame shape rather than a convenient one.
MockClient streamingLiteLlm(List<Map<String, dynamic>> events) =>
    MockClient.streaming((request, bodyStream) async {
      final lines = [
        for (final event in events) 'data: ${jsonEncode(event)}\n\n',
        'data: [DONE]\n\n',
      ];
      return http.StreamedResponse(
        Stream.fromIterable(lines.map(utf8.encode)),
        200,
      );
    });

Future<List<Map<String, dynamic>>> collectFrames(Response response) async {
  final text = await response.readAsString();
  return text
      .split('\n')
      .where((line) => line.startsWith('data:'))
      .map(
        (line) => jsonDecode(line.substring(5).trim()) as Map<String, dynamic>,
      )
      .toList();
}

void main() {
  group('authentication', () {
    test('liveness needs no credential', () async {
      // A health check that required the token would restart the container in a
      // loop the moment the token was rotated.
      final response = await handlerWith(
        MockClient((_) async => http.Response('', 200)),
      )(get('live'));
      expect(response.statusCode, 200);
    });

    test('everything else without a token is rejected', () async {
      final response = await handlerWith(
        MockClient((_) async => http.Response('', 200)),
      )(get('v1/models'));
      expect(response.statusCode, 401);
    });

    test('a wrong token is rejected', () async {
      final response = await handlerWith(
        MockClient((_) async => http.Response('', 200)),
      )(get('v1/models', bearer: 'nope'));
      expect(response.statusCode, 401);
    });

    test('the rejection does not say which part was wrong', () async {
      // Distinguishing "absent" from "incorrect" tells a prober whether it is
      // on the right track.
      final missing = await handlerWith(
        MockClient((_) async => http.Response('', 200)),
      )(get('v1/models'));
      final wrong = await handlerWith(
        MockClient((_) async => http.Response('', 200)),
      )(get('v1/models', bearer: 'nope'));

      expect(await missing.readAsString(), await wrong.readAsString());
    });

    test('comparison is length-safe and value-correct', () {
      expect(secureEquals('abc', 'abc'), isTrue);
      expect(secureEquals('abc', 'abd'), isFalse);
      expect(secureEquals('abc', 'abcd'), isFalse);
      expect(secureEquals('', ''), isTrue);
    });
  });

  group('configuration', () {
    test('refuses to start without a token', () {
      // Booting with an empty token would accept every request, quietly.
      expect(
        () => GatewayConfig.fromEnvironment({'LITELLM_MASTER_KEY': 'k'}),
        throwsA(isA<ApiError>()),
      );
    });

    test('refuses a token short enough to guess', () {
      expect(
        () => GatewayConfig.fromEnvironment({
          'GATEWAY_TOKEN': 'short',
          'LITELLM_MASTER_KEY': 'k',
        }),
        throwsA(isA<ApiError>()),
      );
    });
  });

  group('model catalogue', () {
    test('exposes tiers with their cache thresholds', () async {
      final response = await handlerWith(
        MockClient((_) async => http.Response('', 200)),
      )(get('v1/models', bearer: token));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      final models = (body['models'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      expect(
        models.map((m) => m['tier']),
        containsAll(['haiku', 'sonnet', 'opus']),
      );
      // The app needs the threshold to warn that a short prompt on Haiku will
      // not cache, so it has to travel with the catalogue.
      final haiku = models.firstWhere((m) => m['tier'] == 'haiku');
      expect(haiku['min_cacheable_tokens'], 4096);
    });
  });

  group('health', () {
    test('reports degraded with 503 when an upstream is down', () async {
      final response = await handlerWith(
        MockClient((_) async => http.Response('boom', 500)),
      )(get('v1/health', bearer: token));

      expect(response.statusCode, 503);
      final status = HealthStatus.fromJson(
        jsonDecode(await response.readAsString()) as Map<String, dynamic>,
      );
      expect(status.allHealthy, isFalse);
      expect(status.services.single.detail, contains('500'));
    });

    test('reports healthy with 200', () async {
      final response = await handlerWith(
        MockClient((_) async => http.Response('', 200)),
      )(get('v1/health', bearer: token));
      expect(response.statusCode, 200);
    });
  });

  group('chat', () {
    Future<Response> post(http.Client client, Object body) async =>
        await handlerWith(client)(
          Request(
            'POST',
            Uri.parse('http://localhost/v1/chat'),
            headers: {'authorization': 'Bearer $token'},
            body: jsonEncode(body),
          ),
        );

    test('rejects an unknown tier instead of substituting one', () async {
      final response = await post(
        MockClient((_) async => http.Response('', 200)),
        const ChatRequest(model: 'sonnnet', messages: []).toJson(),
      );

      expect(response.statusCode, 404);
      final error = ApiError.fromJson(
        jsonDecode(await response.readAsString()) as Map<String, dynamic>,
      );
      expect(error.code, 'unknown_tier');
    });

    test('streams text then a closing frame with usage', () async {
      final client = streamingLiteLlm([
        {
          'model': 'anthropic/claude-sonnet-5',
          'choices': [
            {
              'delta': {'content': 'he'},
            },
          ],
        },
        {
          'choices': [
            {
              'delta': {'content': 'llo'},
            },
          ],
        },
        // include_usage sends this as its own trailing event, with no choices.
        {
          'choices': <dynamic>[],
          'usage': {
            'prompt_tokens': 13,
            'completion_tokens': 2,
            'prompt_tokens_details': {'cached_tokens': 4738},
            'response_cost': 0.000512,
          },
        },
      ]);

      final frames = await collectFrames(
        await post(
          client,
          const ChatRequest(
            model: 'sonnet',
            messages: [ChatMessage(role: ChatRole.user, text: 'hi')],
          ).toJson(),
        ),
      );

      final chunks = frames.map(ChatChunk.fromJson).toList();
      expect(chunks.map((c) => c.text).whereType<String>().join(), 'hello');

      final last = chunks.last;
      expect(last.done, isTrue);
      expect(last.model, 'anthropic/claude-sonnet-5');
      expect(last.usage!.servedFromCache, isTrue);
      expect(last.usage!.cacheReadTokens, 4738);
      expect(last.usage!.costUsd, closeTo(0.000512, 1e-9));
    });

    test('reads cached tokens in the Anthropic field shape too', () async {
      // LiteLLM reports cached input as prompt_tokens_details.cached_tokens or
      // as cache_read_input_tokens depending on provider and version. Reading
      // only one is how a working cache gets reported as zero.
      final client = streamingLiteLlm([
        {
          'choices': <dynamic>[],
          'usage': {
            'input_tokens': 13,
            'output_tokens': 2,
            'cache_read_input_tokens': 4866,
            'cache_creation_input_tokens': 0,
          },
        },
      ]);

      final frames = await collectFrames(
        await post(
          client,
          const ChatRequest(
            model: 'haiku',
            messages: [ChatMessage(role: ChatRole.user, text: 'hi')],
          ).toJson(),
        ),
      );

      final usage = ChatChunk.fromJson(frames.last).usage!;
      expect(usage.cacheReadTokens, 4866);
      expect(usage.inputTokens, 13);
    });

    test('surfaces an upstream failure as an error frame', () async {
      final frames = await collectFrames(
        await post(
          MockClient.streaming(
            (_, _) async => http.StreamedResponse(
              Stream.value(utf8.encode('rate limited')),
              429,
            ),
          ),
          const ChatRequest(
            model: 'sonnet',
            messages: [ChatMessage(role: ChatRole.user, text: 'hi')],
          ).toJson(),
        ),
      );

      expect(frames.single['error'], isNotNull);
      final error = ApiError.fromJson(
        frames.single['error'] as Map<String, dynamic>,
      );
      expect(error.code, 'upstream_error');
      expect(error.message, contains('429'));
    });

    test('ignores keep-alive frames that are not JSON', () async {
      final client = MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream.fromIterable([
            utf8.encode(': keep-alive\n\n'),
            utf8.encode('data: \n\n'),
            utf8.encode('data: {"choices":[{"delta":{"content":"ok"}}]}\n\n'),
            utf8.encode('data: [DONE]\n\n'),
          ]),
          200,
        ),
      );

      final frames = await collectFrames(
        await post(
          client,
          const ChatRequest(
            model: 'sonnet',
            messages: [ChatMessage(role: ChatRole.user, text: 'hi')],
          ).toJson(),
        ),
      );

      final chunks = frames.map(ChatChunk.fromJson).toList();
      expect(chunks.map((c) => c.text).whereType<String>().join(), 'ok');
      expect(chunks.last.done, isTrue);
    });
  });
}
