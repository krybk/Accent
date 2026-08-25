/// Builds the request the gateway sends upstream to LiteLLM.
///
/// This file exists as its own unit because the cache invariant lives here, and
/// an invariant that is only described in a comment is an invariant that breaks.
/// The rule: everything stable comes first, `cache_control` marks the end of the
/// stable part, and everything that changes per turn comes after it. Put the
/// volatile part first and the prefix shifts on every turn, so nothing is ever
/// reused and the whole history is billed at full price — silently.
library;

import 'package:accent_protocol/protocol.dart';

/// The instruction block shared by every conversation on this server.
///
/// Kept as one constant on purpose. It is the largest stable span available, so
/// it is what makes the prefix long enough to cache — and it must be
/// byte-identical between turns, which is why nothing here is interpolated.
const systemPreamble = '''
You are the assistant of an Accent server. You have access to the tools the
gateway exposes and to the files the user uploads. Answer in the language the
user writes in. Prefer doing the work over describing it.
''';

/// Rough token estimate, used only to warn when a prefix will not cache.
///
/// Four characters per token is a crude average; it is not used for billing or
/// for truncation, only to decide whether a warning is worth logging. Counting
/// exactly would mean a tokeniser per model, which is not worth it for a hint.
int estimateTokens(String text) => (text.length / 4).ceil();

/// Whether the stable prefix is long enough for [model] to cache it at all.
///
/// Below the threshold the provider silently declines to cache, so the gateway
/// logs it rather than letting the cost appear as an unexplained line on a bill.
bool prefixWillCache(String prefix, ModelInfo model) =>
    estimateTokens(prefix) >= model.minCacheableTokens;

/// Maps our roles onto the OpenAI-compatible roles LiteLLM expects.
String _wireRole(ChatRole role) => switch (role) {
  ChatRole.user => 'user',
  ChatRole.assistant => 'assistant',
  ChatRole.system => 'system',
};

/// Renders one message, folding attachment references into the text.
///
/// Attachment bytes are never inlined: history is replayed every turn, so an
/// inlined file would be resent every turn. A reference plus a transcript is
/// what the model actually needs to reason about it.
String _renderMessage(ChatMessage message) {
  if (message.attachments.isEmpty) return message.text;

  final parts = [message.text];
  for (final attachment in message.attachments) {
    final label = attachment.filename ?? attachment.id;
    parts.add(
      attachment.transcript == null
          ? '[attachment $label (${attachment.mimeType})]'
          : '[attachment $label (${attachment.mimeType}), '
                'speech recognised as: ${attachment.transcript}]',
    );
  }
  return parts.join('\n');
}

/// Builds the upstream body for a chat turn.
///
/// [tier] is the LiteLLM `model_name`, not a provider model string — provider
/// pinning and the concrete model live in LiteLLM's config, so they cannot be
/// forgotten by a caller here.
Map<String, dynamic> buildUpstreamRequest({
  required String tier,
  required ChatRequest request,
  int maxTokens = 8192,
}) {
  // The system turn is the cache boundary. cache_control goes on this block and
  // nowhere else: it is the last thing that is identical across turns.
  final messages = <Map<String, dynamic>>[
    {
      'role': 'system',
      'content': [
        {
          'type': 'text',
          'text': systemPreamble,
          'cache_control': {'type': 'ephemeral'},
        },
      ],
    },
  ];

  // Everything below changes per turn and therefore must stay after the
  // breakpoint above.
  for (final message in request.messages) {
    messages.add({
      'role': _wireRole(message.role),
      'content': _renderMessage(message),
    });
  }

  return {
    'model': tier,
    'messages': messages,
    'max_tokens': maxTokens,
    'stream': true,
    // Without this, a streamed response closes with no token counts, and cache
    // hits become invisible exactly where the spend is.
    'stream_options': {'include_usage': true},
  };
}
