import 'package:accent_gateway/src/catalog.dart';
import 'package:accent_gateway/src/upstream_request.dart';
import 'package:accent_protocol/protocol.dart';
import 'package:test/test.dart';

/// These tests exist to hold the cache invariant in place. Prompt caching fails
/// silently — no error, no warning, just a larger bill — so the only way to keep
/// it working is to make a violation fail the build.
void main() {
  const turn = ChatRequest(
    model: sonnetTier,
    messages: [ChatMessage(role: ChatRole.user, text: 'what changed today')],
  );

  group('cache invariant', () {
    test('the cache breakpoint sits on the first, stable message', () {
      final body = buildUpstreamRequest(tier: sonnetTier, request: turn);
      final messages = body['messages'] as List<dynamic>;
      final first = messages.first as Map<String, dynamic>;
      final block =
          (first['content'] as List<dynamic>).single as Map<String, dynamic>;

      expect(first['role'], 'system');
      expect(block['cache_control'], {'type': 'ephemeral'});
    });

    test('nothing after the breakpoint is marked cacheable', () {
      // A second breakpoint on volatile content would move with every turn and
      // buy nothing, while spending a cache write each time.
      final body = buildUpstreamRequest(tier: sonnetTier, request: turn);
      final messages = (body['messages'] as List<dynamic>).skip(1);

      for (final message in messages) {
        expect(
          message.toString().contains('cache_control'),
          isFalse,
          reason: 'only the stable prefix may carry cache_control',
        );
      }
    });

    test('the stable prefix is byte-identical across turns', () {
      // The prefix must not contain a timestamp, a request id or a counter.
      // Any of those void the cache on every single turn.
      final first = buildUpstreamRequest(tier: sonnetTier, request: turn);
      final second = buildUpstreamRequest(
        tier: sonnetTier,
        request: const ChatRequest(
          model: sonnetTier,
          messages: [ChatMessage(role: ChatRole.user, text: 'a different ask')],
        ),
      );

      expect(
        (first['messages'] as List<dynamic>).first.toString(),
        (second['messages'] as List<dynamic>).first.toString(),
      );
    });

    test('history follows the prefix, in order', () {
      final body = buildUpstreamRequest(
        tier: sonnetTier,
        request: const ChatRequest(
          model: sonnetTier,
          messages: [
            ChatMessage(role: ChatRole.user, text: 'first'),
            ChatMessage(role: ChatRole.assistant, text: 'second'),
            ChatMessage(role: ChatRole.user, text: 'third'),
          ],
        ),
      );
      final messages = body['messages'] as List<dynamic>;

      expect(messages.length, 4);
      expect((messages[1] as Map)['content'], 'first');
      expect((messages[2] as Map)['role'], 'assistant');
      expect((messages[3] as Map)['content'], 'third');
    });
  });

  group('usage reporting', () {
    test('streamed responses are asked to include usage', () {
      // Omitting this makes cache reads invisible on exactly the requests that
      // dominate the bill.
      final body = buildUpstreamRequest(tier: sonnetTier, request: turn);
      expect(body['stream'], isTrue);
      expect(body['stream_options'], {'include_usage': true});
    });

    test('the tier name is sent, not a provider model string', () {
      // Provider pinning lives in LiteLLM's config. If the gateway sent a raw
      // provider model here it would bypass that config and lose the pin.
      final body = buildUpstreamRequest(tier: haikuTier, request: turn);
      expect(body['model'], 'haiku');
      expect(body['model'], isNot(contains('anthropic/')));
    });
  });

  group('attachments', () {
    test('are referenced, never inlined', () {
      final body = buildUpstreamRequest(
        tier: sonnetTier,
        request: const ChatRequest(
          model: sonnetTier,
          messages: [
            ChatMessage(
              role: ChatRole.user,
              text: 'look at this',
              attachments: [
                Attachment(
                  id: 'att_9',
                  mimeType: 'image/png',
                  sizeBytes: 918_273,
                  filename: 'screen.png',
                ),
              ],
            ),
          ],
        ),
      );

      final content =
          ((body['messages'] as List<dynamic>)[1] as Map)['content'] as String;
      expect(content, contains('screen.png'));
      expect(content, contains('image/png'));
      // Size is a hint for the model at most; the bytes stay out of history.
      expect(content, isNot(contains('base64')));
    });

    test('a recognised recording carries its transcript', () {
      final body = buildUpstreamRequest(
        tier: sonnetTier,
        request: const ChatRequest(
          model: sonnetTier,
          messages: [
            ChatMessage(
              role: ChatRole.user,
              text: '',
              attachments: [
                Attachment(
                  id: 'att_1',
                  mimeType: 'audio/m4a',
                  sizeBytes: 20480,
                  transcript: 'renew the certificate',
                ),
              ],
            ),
          ],
        ),
      );

      final content =
          ((body['messages'] as List<dynamic>)[1] as Map)['content'] as String;
      expect(content, contains('renew the certificate'));
    });
  });

  group('prefix threshold', () {
    test('the shipped preamble is honest about not caching on Haiku', () {
      // The preamble is a few hundred tokens, far below Haiku's ~4096. This test
      // documents that gap rather than pretending it does not exist: until the
      // prefix grows, Haiku turns are billed as fresh input every time.
      final haiku = resolveTier(haikuTier)!;
      expect(prefixWillCache(systemPreamble, haiku), isFalse);
    });

    test('a long prefix clears both thresholds', () {
      final long = systemPreamble * 200;
      expect(prefixWillCache(long, resolveTier(sonnetTier)!), isTrue);
      expect(prefixWillCache(long, resolveTier(haikuTier)!), isTrue);
    });
  });

  group('tier resolution', () {
    test('an unknown tier is rejected rather than defaulted', () {
      // Defaulting a typo to a working tier is how a mistake becomes a bill on
      // the most expensive model.
      expect(resolveTier('sonnnet'), isNull);
      expect(resolveTier(opusTier)!.id, 'anthropic/claude-opus-5');
    });
  });
}
