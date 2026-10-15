import 'dart:async';
import 'dart:convert';

import 'package:accent/l10n/app_localizations.dart';
import 'package:accent/screens/queue_screen.dart';
import 'package:accent/services/gateway_client.dart';
import 'package:accent_protocol/protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _entry(
  String id,
  String title,
  String status,
  int position, {
  bool held = false,
  bool ownerOrdered = false,
}) => {
  'id': id,
  'title': title,
  'status': status,
  'position': position,
  'held': held,
  'owner_ordered': ownerOrdered,
};

final _queue3 = {
  'queue': [
    _entry('11', 'First', 'running', 1, ownerOrdered: true),
    _entry('12', 'Second', 'waiting', 2, held: true),
    _entry('13', 'Third', 'waiting', 3),
  ],
};

Future<http.Response> _json(Object body, [int status = 200]) async =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Future<void> _pump(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler, {
  bool settle = true,
}) async {
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
      home: Scaffold(body: QueueScreen(client: client)),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(Key('queue-menu-$id')));
  await tester.pumpAndSettle();
}

Future<void> _closeMenu(WidgetTester tester) async {
  await tester.tapAt(Offset.zero);
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<PopupMenuItem<PlaneQueueVerb>>(find.byKey(Key(key))).enabled;

double _top(WidgetTester tester, String id) =>
    tester.getTopLeft(find.byKey(Key('queue-row-$id'))).dy;

void main() {
  testWidgets('rows render in payload order with status and held chip', (
    tester,
  ) async {
    await _pump(tester, (r) => _json(_queue3));
    expect(_top(tester, '11'), lessThan(_top(tester, '12')));
    expect(_top(tester, '12'), lessThan(_top(tester, '13')));
    expect(find.text('#11 First'), findsOneWidget);
    expect(find.text('running'), findsOneWidget);
    expect(find.text('Plans are taken in this order.'), findsOneWidget);
    expect(find.text('On hold'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('queue-row-12')),
        matching: find.text('On hold'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('move items are disabled at the ends of the queue', (
    tester,
  ) async {
    await _pump(tester, (r) => _json(_queue3));
    await _openMenu(tester, '11');
    expect(_enabled(tester, 'queue-up-11'), isFalse);
    expect(_enabled(tester, 'queue-top-11'), isFalse);
    expect(_enabled(tester, 'queue-down-11'), isTrue);
    expect(_enabled(tester, 'queue-bottom-11'), isTrue);
    await _closeMenu(tester);
    await _openMenu(tester, '13');
    expect(_enabled(tester, 'queue-down-13'), isFalse);
    expect(_enabled(tester, 'queue-bottom-13'), isFalse);
    expect(_enabled(tester, 'queue-up-13'), isTrue);
    expect(_enabled(tester, 'queue-top-13'), isTrue);
  });

  testWidgets('hold and resume are offered by held state', (tester) async {
    await _pump(tester, (r) => _json(_queue3));
    await _openMenu(tester, '11');
    expect(find.byKey(const Key('queue-hold-11')), findsOneWidget);
    expect(find.byKey(const Key('queue-resume-11')), findsNothing);
    await _closeMenu(tester);
    await _openMenu(tester, '12');
    expect(find.byKey(const Key('queue-resume-12')), findsOneWidget);
    expect(find.byKey(const Key('queue-hold-12')), findsNothing);
  });

  testWidgets('a move posts once and re-renders the answered order', (
    tester,
  ) async {
    final posts = <String>[];
    await _pump(tester, (r) {
      if (r.method == 'POST') {
        posts.add('${r.method} ${r.url.path}');
        return _json({
          'queue': [
            _entry('12', 'Second', 'waiting', 1, held: true),
            _entry('13', 'Third', 'waiting', 2),
            _entry('11', 'First', 'running', 3, ownerOrdered: true),
          ],
        });
      }
      return _json(_queue3);
    });
    await _openMenu(tester, '11');
    await tester.tap(find.byKey(const Key('queue-bottom-11')));
    await tester.pumpAndSettle();
    expect(posts, ['POST /v1/plane/queue/11/bottom']);
    expect(_top(tester, '12'), lessThan(_top(tester, '13')));
    expect(_top(tester, '13'), lessThan(_top(tester, '11')));
    expect(
      find.descendant(
        of: find.byKey(const Key('queue-row-11')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('no_such_plan keeps the list, then the reload replaces it', (
    tester,
  ) async {
    final reload = Completer<http.Response>();
    var gets = 0;
    await _pump(tester, (r) {
      if (r.method == 'POST') {
        return _json({'code': 'no_such_plan', 'message': 'closed'}, 404);
      }
      return ++gets == 1 ? _json(_queue3) : reload.future;
    });
    await _openMenu(tester, '12');
    await tester.tap(find.byKey(const Key('queue-up-12')));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.text('This plan is no longer open'), findsOneWidget);
    expect(_top(tester, '11'), lessThan(_top(tester, '12')));
    expect(_top(tester, '12'), lessThan(_top(tester, '13')));
    reload.complete(
      await _json({
        'queue': [
          _entry('11', 'First', 'running', 1, ownerOrdered: true),
          _entry('13', 'Third', 'waiting', 2),
        ],
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('queue-row-12')), findsNothing);
    expect(find.byKey(const Key('queue-row-13')), findsOneWidget);
  });

  testWidgets('menus are disabled and progress shown while a move is pending', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    await _pump(
      tester,
      (r) => r.method == 'POST' ? pending.future : _json(_queue3),
    );
    await _openMenu(tester, '11');
    await tester.tap(find.byKey(const Key('queue-hold-11')));
    await tester.pump();
    final buttons = tester.widgetList<PopupMenuButton<PlaneQueueVerb>>(
      find.byType(PopupMenuButton<PlaneQueueVerb>),
    );
    expect(buttons, hasLength(3));
    expect(buttons.every((b) => !b.enabled), isTrue);
    expect(find.byKey(const Key('queue-progress')), findsOneWidget);
    pending.complete(await _json(_queue3));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<PopupMenuButton<PlaneQueueVerb>>(
            find.byType(PopupMenuButton<PlaneQueueVerb>),
          )
          .every((b) => b.enabled),
      isTrue,
    );
    expect(find.byKey(const Key('queue-progress')), findsNothing);
  });

  testWidgets('a move finishing after the screen is gone does not throw', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    await _pump(
      tester,
      (r) => r.method == 'POST' ? pending.future : _json(_queue3),
    );
    await _openMenu(tester, '11');
    await tester.tap(find.byKey(const Key('queue-down-11')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete(await _json(_queue3));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the initial load finishing after the screen is gone is safe', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    await _pump(tester, (r) => pending.future, settle: false);
    await tester.pumpWidget(const SizedBox());
    pending.complete(await _json(_queue3));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed first load offers Try again', (tester) async {
    var ok = false;
    await _pump(
      tester,
      (r) => ok
          ? _json(_queue3)
          : _json({'code': 'plane_unavailable', 'message': 'x'}, 503),
    );
    expect(find.text('The control plane is not answering'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    ok = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('queue-row-11')), findsOneWidget);
    expect(find.byKey(const Key('queue-row-13')), findsOneWidget);
  });

  testWidgets('an empty queue says so', (tester) async {
    await _pump(tester, (r) => _json({'queue': []}));
    expect(find.text('No open plans'), findsOneWidget);
  });
}
