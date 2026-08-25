import 'dart:convert';

import 'package:accent_protocol/protocol.dart';
import 'package:test/test.dart';

/// Sends a value through real JSON encoding and back. Testing `toJson` against
/// `fromJson` directly would pass even if a field were unserialisable, which is
/// exactly the failure that only shows up over the wire.
T roundTrip<T>(
  Map<String, dynamic> Function() encode,
  T Function(Map<String, dynamic>) decode,
) => decode(jsonDecode(jsonEncode(encode())) as Map<String, dynamic>);

void main() {
  group('ChatMessage', () {
    test('survives a round trip with attachments', () {
      const original = ChatMessage(
        role: ChatRole.user,
        text: 'what is in this recording',
        attachments: [
          Attachment(
            id: 'att_1',
            mimeType: 'audio/m4a',
            sizeBytes: 20480,
            filename: 'note.m4a',
            transcript: 'remind me to renew the certificate',
          ),
        ],
      );

      final decoded = roundTrip(original.toJson, ChatMessage.fromJson);

      expect(decoded.role, ChatRole.user);
      expect(decoded.text, original.text);
      expect(decoded.attachments.single.id, 'att_1');
      expect(
        decoded.attachments.single.transcript,
        'remind me to renew the certificate',
      );
    });

    test('omits an empty attachment list rather than sending []', () {
      const message = ChatMessage(role: ChatRole.assistant, text: 'ok');
      // Every turn resends the whole history, so empty keys are not free.
      expect(message.toJson().containsKey('attachments'), isFalse);
    });

    test('rejects an unknown role instead of guessing', () {
      expect(
        () => ChatMessage.fromJson({'role': 'moderator', 'text': 'hi'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Usage', () {
    test('reports a cached turn', () {
      const usage = Usage(
        inputTokens: 13,
        outputTokens: 4,
        cacheReadTokens: 4738,
        costUsd: 0.000512,
      );

      expect(usage.servedFromCache, isTrue);
      expect(roundTrip(usage.toJson, Usage.fromJson).cacheReadTokens, 4738);
    });

    test('reports an uncached turn', () {
      // The shape produced when a prefix falls below the model's threshold:
      // everything billed as ordinary input, nothing written, nothing read.
      const usage = Usage(inputTokens: 2383, outputTokens: 4);

      expect(usage.servedFromCache, isFalse);
      expect(usage.cacheWriteTokens, 0);
    });

    test('tolerates a provider that has not published a cost yet', () {
      final decoded = Usage.fromJson({'input_tokens': 10, 'output_tokens': 2});
      expect(decoded.costUsd, isNull);
    });
  });

  group('ModelInfo', () {
    test('computes how much a cache hit saves', () {
      const sonnet = ModelInfo(
        id: 'anthropic/claude-sonnet-5',
        displayName: 'Sonnet 5',
        inputUsdPerMillion: 2.0,
        outputUsdPerMillion: 10.0,
        cacheReadUsdPerMillion: 0.2,
        minCacheableTokens: 1024,
        contextWindow: 1000000,
      );

      expect(sonnet.cacheSavingFactor, closeTo(10.0, 0.001));
      expect(
        roundTrip(sonnet.toJson, ModelInfo.fromJson).minCacheableTokens,
        1024,
      );
    });

    test('records that Haiku caches only behind a much longer prefix', () {
      // Measured, not assumed. This is the fact that makes the cheap tier
      // expensive on short prompts, so it belongs in a test, not a comment.
      const haiku = ModelInfo(
        id: 'anthropic/claude-haiku-4.5',
        displayName: 'Haiku 4.5',
        inputUsdPerMillion: 1.0,
        outputUsdPerMillion: 5.0,
        cacheReadUsdPerMillion: 0.1,
        minCacheableTokens: 4096,
        contextWindow: 200000,
      );

      expect(haiku.minCacheableTokens, greaterThan(1024));
      // Uncached Haiku input costs more than cached Sonnet input.
      expect(haiku.inputUsdPerMillion, greaterThan(0.2));
    });
  });

  group('HealthStatus', () {
    test('is unhealthy when any single service is down', () {
      const status = HealthStatus(
        version: '0.1.0',
        services: [
          ServiceStatus(name: 'litellm', healthy: true),
          ServiceStatus(
            name: 'postgres',
            healthy: false,
            detail: 'no connection',
          ),
        ],
      );

      expect(status.allHealthy, isFalse);
      expect(
        roundTrip(status.toJson, HealthStatus.fromJson).services.length,
        2,
      );
    });
  });

  group('ChatChunk', () {
    test('carries usage only on the closing frame', () {
      const text = ChatChunk(text: 'hel');
      const last = ChatChunk(
        done: true,
        model: 'anthropic/claude-sonnet-5',
        usage: Usage(inputTokens: 13, outputTokens: 7, cacheReadTokens: 4738),
      );

      expect(text.toJson().containsKey('usage'), isFalse);
      expect(text.toJson().containsKey('done'), isFalse);

      final decoded = roundTrip(last.toJson, ChatChunk.fromJson);
      expect(decoded.done, isTrue);
      expect(decoded.usage!.servedFromCache, isTrue);
      expect(decoded.model, 'anthropic/claude-sonnet-5');
    });
  });
}
