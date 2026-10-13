import 'dart:convert';

import 'package:accent/l10n/app_localizations.dart';
import 'package:accent/screens/usage_screen.dart';
import 'package:accent/services/gateway_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _bucketJson(int steps, {int untracked = 0}) => {
  'steps': steps,
  'untracked_steps': untracked,
  'cost_usd': 1.5,
  'input_tokens': 12345,
  'output_tokens': 100,
  'cache_read_tokens': 0,
  'cache_write_tokens': 0,
};

final _fixture = {
  'generated_at': '2026-10-13T09:00:00Z',
  'models': [
    {
      'model': 'example-model',
      'today': _bucketJson(3),
      'last_7d': _bucketJson(42, untracked: 2),
      'last_30d': _bucketJson(100),
    },
  ],
  'roles': [
    {
      'role': 'chat',
      'model': 'example-model',
      'today': _bucketJson(0),
      'last_7d': _bucketJson(5),
      'last_30d': _bucketJson(5),
    },
    {
      'role': 'executor',
      'model': 'example-model',
      'today': _bucketJson(0),
      'last_7d': _bucketJson(37),
      'last_30d': _bucketJson(37),
    },
  ],
};

Future<void> _pump(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
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
      home: Scaffold(body: UsageScreen(client: client)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<http.Response> _ok(http.Request r) async => http.Response(
  jsonEncode(_fixture),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('formatTokens', () {
    test('formats plain, thousands and millions', () {
      expect(formatTokens(999), '999');
      expect(formatTokens(12345), '12.3k');
      expect(formatTokens(4560000), '4.56M');
    });
  });

  testWidgets('shows the 7 day window by default', (tester) async {
    await _pump(tester, _ok);
    expect(find.text('Steps: 42'), findsOneWidget);
    expect(find.text('2 steps predate token accounting'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('chat'), findsNothing);
    expect(find.text('executor'), findsOneWidget);
  });

  testWidgets('switching to Today changes the figures and hides idle roles', (
    tester,
  ) async {
    await _pump(tester, _ok);
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('Steps: 3'), findsOneWidget);
    expect(find.text('Steps: 42'), findsNothing);
    expect(find.text('executor'), findsNothing);
  });

  testWidgets('shows the error and a retry button', (tester) async {
    await _pump(
      tester,
      (r) async => http.Response(
        jsonEncode({'code': 'plane_unavailable', 'message': 'down'}),
        503,
        headers: {'content-type': 'application/json'},
      ),
    );
    expect(find.text('The control plane is not answering'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
