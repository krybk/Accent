import 'dart:async';

import 'package:accent_protocol/protocol.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/gateway_client.dart';
import 'send_to_plan.dart';
import 'usage_screen.dart';

String describeChatError(AppLocalizations l10n, Object error) {
  if (error is PlaneChatError) {
    return switch (error.code) {
      'refused' => l10n.chatErrorRefused(error.message),
      'timeout' => l10n.chatErrorTimeout,
      'switched' => l10n.chatErrorSwitched,
      _ => l10n.chatErrorFailed(error.message),
    };
  }
  if (error is GatewayException) {
    if (error.statusCode == 429 && error.code == 'chat_busy') {
      return l10n.chatErrorBusy;
    }
    if (error.statusCode == 503 && error.code == 'no_provider') {
      return l10n.chatErrorNoProvider;
    }
    if (error.statusCode == 413) return l10n.chatErrorTooLong;
    if (error.statusCode == 0 && error.code == 'timeout') {
      return l10n.chatErrorTimeout;
    }
  }
  return describeGatewayError(l10n, error);
}

class _Bubble {
  _Bubble({required this.fromUser});

  final bool fromUser;
  final StringBuffer text = StringBuffer();
  String? caption;
  String? error;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.client, super.key});

  final GatewayClient client;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _bubbles = <_Bubble>[];
  final _controller = TextEditingController();
  String? _sessionId;
  String _tier = 'opus';
  StreamSubscription<PlaneChatEvent>? _sub;

  bool get _streaming => _sub != null;

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (text.runes.length > 20000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).chatErrorTooLong)),
      );
      return;
    }
    final assistant = _Bubble(fromUser: false);
    setState(() {
      _bubbles.add(_Bubble(fromUser: true)..text.write(text));
      _bubbles.add(assistant);
      _controller.clear();
      _sub = widget.client
          .chat(
            PlaneChatRequest(message: text, sessionId: _sessionId, tier: _tier),
          )
          .listen(
            (event) {
              if (!mounted) return;
              final l10n = AppLocalizations.of(context);
              setState(() {
                switch (event) {
                  case PlaneChatSession():
                    _sessionId = event.sessionId;
                  case PlaneChatDelta():
                    assistant.text.write(event.text);
                  case PlaneChatDone():
                    _sessionId = event.sessionId;
                    assistant.caption = l10n.chatDoneCaption(
                      event.model,
                      formatTokens(event.inputTokens),
                      formatTokens(event.outputTokens),
                    );
                  case PlaneChatError():
                    assistant.error = describeChatError(l10n, event);
                }
              });
            },
            onError: (Object error) {
              if (!mounted) return;
              final l10n = AppLocalizations.of(context);
              setState(() => assistant.error = describeChatError(l10n, error));
            },
            onDone: () {
              if (!mounted) return;
              setState(() => _sub = null);
            },
          );
    });
  }

  Widget _bubbleView(BuildContext context, int i) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bubble = _bubbles[i];
    return Align(
      alignment: bubble.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bubble.text.toString()),
              if (bubble.caption != null)
                Text(bubble.caption!, style: theme.textTheme.bodySmall),
              if (bubble.error != null)
                Text(
                  bubble.error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              IconButton(
                key: Key('send-to-plan-$i'),
                icon: const Icon(Icons.outbox_outlined),
                tooltip: l10n.sendToPlan,
                onPressed: bubble.text.isEmpty
                    ? null
                    : () => sendToPlan(
                        context,
                        widget.client,
                        bubble.text.toString(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Row(
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'opus', label: Text(l10n.chatTierOpus)),
                ButtonSegment(
                  value: 'sonnet',
                  label: Text(l10n.chatTierSonnet),
                ),
              ],
              selected: {_tier},
              onSelectionChanged: (s) => setState(() => _tier = s.first),
            ),
            IconButton(
              key: const Key('chat-new'),
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: l10n.chatNewConversation,
              onPressed: _streaming
                  ? null
                  : () => setState(() {
                      _bubbles.clear();
                      _sessionId = null;
                    }),
            ),
          ],
        ),
        Expanded(
          child: _bubbles.isEmpty
              ? Center(child: Text(l10n.chatEmpty))
              : ListView.builder(
                  itemCount: _bubbles.length,
                  itemBuilder: _bubbleView,
                ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('chat-input'),
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                decoration: InputDecoration(hintText: l10n.chatInputHint),
              ),
            ),
            IconButton(
              key: const Key('chat-send'),
              icon: const Icon(Icons.send),
              tooltip: l10n.chatSend,
              onPressed: _streaming ? null : _send,
            ),
          ],
        ),
      ],
    );
  }
}
