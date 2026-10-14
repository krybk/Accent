import 'dart:async';
import 'dart:convert';

import 'package:accent/l10n/app_localizations.dart';
import 'package:accent/screens/chat_screen.dart';
import 'package:accent/services/gateway_client.dart';
import 'package:accent_protocol/protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

final _guidance = <http.Request>[];

Future<http.Response> _handler(http.Request request) async {
  final path = request.url.path;
  if (path == '/v1/plane/plans') {
    return _json({
      'plans': [
        {'id': 'p1', 'title': 'First plan', 'status': 'active', 'tasks': []},
      ],
    });
  }
  if (path == '/v1/plane/plans/p1/guidance') {
    _guidance.add(request);
    return _json({
      'plan_id': 'p1',
      'comment_url': 'https://example.com/c/1',
    }, 201);
  }
  return _json({'code': 'not_found', 'message': 'x'}, 404);
}

class _FakeClient extends GatewayClient {
  _FakeClient()
    : super(
        baseUri: Uri.parse('https://gateway.example.com:8443'),
        token: 't',
        httpClient: MockClient((r) async => _handler(r)),
      );

  final requests = <PlaneChatRequest>[];
  late StreamController<PlaneChatEvent> current;
  Object? failWith;

  @override
  Stream<PlaneChatEvent> chat(PlaneChatRequest r) {
    requests.add(r);
    if (failWith != null) return Stream.error(failWith!);
    current = StreamController<PlaneChatEvent>();
    return current.stream;
  }
}

const _done = PlaneChatDone(
  sessionId: 's1',
  model: 'm1',
  costUsd: null,
  inputTokens: 1200,
  outputTokens: 50,
  cacheReadTokens: 0,
  cacheWriteTokens: 0,
  turns: null,
);

void main() {
  late _FakeClient fake;

  setUp(() {
    _guidance.clear();
    fake = _FakeClient();
  });

  Future<void> open(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: ChatScreen(client: fake)),
    ),
  );

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('chat-input')), text);
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
  }

  Future<void> answer(WidgetTester tester) async {
    fake.current.add(const PlaneChatSession(sessionId: 's1', model: 'm1'));
    fake.current.add(const PlaneChatDelta(text: 'Hel'));
    await tester.pump();
    fake.current.add(const PlaneChatDelta(text: 'lo'));
    fake.current.add(_done);
    await fake.current.close();
    await tester.pump();
  }

  testWidgets('streams an answer into a bubble', (tester) async {
    await open(tester);
    await send(tester, 'hello');
    expect(fake.requests.single.message, 'hello');
    expect(fake.requests.single.sessionId, isNull);
    expect(fake.requests.single.tier, 'opus');

    fake.current.add(const PlaneChatSession(sessionId: 's1', model: 'm1'));
    fake.current.add(const PlaneChatDelta(text: 'Hel'));
    await tester.pump();
    expect(find.text('Hel'), findsOneWidget);
    fake.current.add(const PlaneChatDelta(text: 'lo'));
    await tester.pump();
    expect(find.text('Hello'), findsOneWidget);
    fake.current.add(_done);
    await fake.current.close();
    await tester.pump();
    expect(find.text('m1 · 1.2k in · 50 out'), findsOneWidget);
  });

  testWidgets('session continues until a new conversation', (tester) async {
    await open(tester);
    await send(tester, 'hello');
    await answer(tester);
    await send(tester, 'again');
    expect(fake.requests.last.sessionId, 's1');
    await answer(tester);
    await tester.tap(find.byKey(const Key('chat-new')));
    await tester.pump();
    await send(tester, 'third');
    expect(fake.requests.last.sessionId, isNull);
  });

  testWidgets('the Sonnet segment selects the tier', (tester) async {
    await open(tester);
    await tester.tap(find.text('Sonnet'));
    await tester.pump();
    await send(tester, 'hello');
    expect(fake.requests.single.tier, 'sonnet');
  });

  testWidgets('send to plan posts only after confirmation', (tester) async {
    await open(tester);
    await send(tester, 'hello');
    await answer(tester);

    await tester.tap(find.byKey(const Key('send-to-plan-0')));
    await tester.pumpAndSettle();
    expect(find.text('Guidance for a plan'), findsOneWidget);
    expect(_guidance, isEmpty);
    await tester.tap(find.byKey(const Key('guidance-send')));
    await tester.pumpAndSettle();
    expect(_guidance, hasLength(1));
    expect(jsonDecode(_guidance.single.body), {'text': 'hello'});
    expect(find.text('Sent: https://example.com/c/1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('send-to-plan-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(_guidance, hasLength(1));
  });

  testWidgets('shows a failed request', (tester) async {
    fake.failWith = const GatewayException(429, 'chat_busy', 'busy');
    await open(tester);
    await send(tester, 'hello');
    await tester.pump();
    expect(
      find.text('Another chat answer is still running — wait for it to finish'),
      findsOneWidget,
    );
  });

  testWidgets('shows an error event', (tester) async {
    await open(tester);
    await send(tester, 'hello');
    fake.current.add(
      const PlaneChatError(
        code: 'switched',
        message: 'x',
        subtype: null,
        apiErrorStatus: null,
      ),
    );
    await tester.pump();
    expect(
      find.text('The model was switched off — send again'),
      findsOneWidget,
    );
  });

  group('describeChatError', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    PlaneChatError event(String code, String message) => PlaneChatError(
      code: code,
      message: message,
      subtype: null,
      apiErrorStatus: null,
    );

    test('chat events', () {
      expect(
        describeChatError(l10n, event('refused', 'limit')),
        'The model refused: limit',
      );
      expect(
        describeChatError(l10n, event('timeout', 't')),
        l10n.chatErrorTimeout,
      );
      expect(
        describeChatError(l10n, event('failed', 'boom')),
        'The chat failed: boom',
      );
    });

    test('gateway errors', () {
      expect(
        describeChatError(
          l10n,
          const GatewayException(503, 'no_provider', 'x'),
        ),
        l10n.chatErrorNoProvider,
      );
      expect(
        describeChatError(l10n, const GatewayException(413, 'too_large', 'x')),
        l10n.chatErrorTooLong,
      );
      expect(
        describeChatError(l10n, const GatewayException(0, 'timeout', 't')),
        l10n.chatErrorTimeout,
      );
      expect(
        describeChatError(l10n, const GatewayException(402, 'credit', 'x')),
        l10n.gatewayErrorTopUp,
      );
    });
  });
}
