import 'dart:convert';

import 'package:accent/l10n/app_localizations.dart';
import 'package:accent/screens/send_to_plan.dart';
import 'package:accent/services/gateway_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  final guidance = <http.Request>[];
  var plansEmpty = false;
  http.Response guidanceResponse = _json({
    'plan_id': 'p2',
    'comment_url': 'https://example.com/c/1',
  }, 201);

  Future<http.Response> handler(http.Request request) async {
    final path = request.url.path;
    if (path == '/v1/plane/plans') {
      return _json({
        'plans': plansEmpty
            ? []
            : [
                {
                  'id': 'p1',
                  'title': 'First plan',
                  'status': 'active',
                  'tasks': [],
                },
                {
                  'id': 'p2',
                  'title': 'Second plan',
                  'status': 'active',
                  'tasks': [],
                },
              ],
      });
    }
    if (path.startsWith('/v1/plane/plans/') && path.endsWith('/guidance')) {
      guidance.add(request);
      return guidanceResponse;
    }
    return _json({'code': 'not_found', 'message': 'x'}, 404);
  }

  setUp(() {
    guidance.clear();
    plansEmpty = false;
    guidanceResponse = _json({
      'plan_id': 'p2',
      'comment_url': 'https://example.com/c/1',
    }, 201);
  });

  Future<void> open(WidgetTester tester) async {
    final client = GatewayClient(
      baseUri: Uri.parse('https://gateway.example.com:8443'),
      token: 't',
      httpClient: MockClient(handler),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => sendToPlan(context, client, 'prefilled text'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('sends edited text to the chosen plan', (tester) async {
    await open(tester);
    expect(find.text('Guidance for a plan'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('guidance-text')))
          .controller!
          .text,
      'prefilled text',
    );
    expect(guidance, isEmpty);

    await tester.enterText(find.byKey(const Key('guidance-text')), 'edited');
    await tester.tap(find.byKey(const Key('guidance-plan')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second plan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guidance-send')));
    await tester.pumpAndSettle();

    expect(guidance, hasLength(1));
    expect(guidance.single.url.path, '/v1/plane/plans/p2/guidance');
    expect(jsonDecode(guidance.single.body), {'text': 'edited'});
    expect(find.text('Sent: https://example.com/c/1'), findsOneWidget);
  });

  testWidgets('cancel posts nothing', (tester) async {
    await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(guidance, isEmpty);
    expect(find.text('Guidance for a plan'), findsNothing);
  });

  testWidgets('clearing the text disables send', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('guidance-text')), '');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('guidance-send')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('no plan means no dialog', (tester) async {
    plansEmpty = true;
    await open(tester);
    expect(find.text('Guidance for a plan'), findsNothing);
    expect(find.text('There is no open plan'), findsOneWidget);
  });

  testWidgets('credential rejection is explained', (tester) async {
    guidanceResponse = _json({
      'code': 'looks_like_credential',
      'message': 'x',
    }, 400);
    await open(tester);
    await tester.tap(find.byKey(const Key('guidance-send')));
    await tester.pumpAndSettle();
    expect(
      find.text('The text looks like a credential and was not sent'),
      findsOneWidget,
    );
  });

  testWidgets('missing plan is explained', (tester) async {
    guidanceResponse = _json({'code': 'no_such_plan', 'message': 'x'}, 404);
    await open(tester);
    await tester.tap(find.byKey(const Key('guidance-send')));
    await tester.pumpAndSettle();
    expect(find.text('This plan no longer exists'), findsOneWidget);
  });

  test('describeGuidanceError maps codes and falls back', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      describeGuidanceError(
        l10n,
        const GatewayException(502, 'comment_failed', 'x'),
      ),
      'The server could not post the guidance',
    );
    expect(
      describeGuidanceError(l10n, const GatewayException(402, 'billing', 'x')),
      l10n.gatewayErrorTopUp,
    );
  });
}
