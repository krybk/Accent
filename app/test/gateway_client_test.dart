import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:accent/l10n/app_localizations.dart';
import 'package:accent/models/server_profile.dart';
import 'package:accent/services/gateway_client.dart';
import 'package:accent/services/profile_repository.dart';
import 'package:accent/services/secret_store.dart';
import 'package:accent_protocol/protocol.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _bucket = {
  'steps': 3,
  'untracked_steps': 1,
  'cost_usd': 1.5,
  'input_tokens': 100,
  'output_tokens': 50,
  'cache_read_tokens': 10,
  'cache_write_tokens': 5,
};

final _base = Uri.parse('https://gateway.example.com:8443');

GatewayClient _client(Future<http.Response> Function(http.Request) handler) =>
    GatewayClient(
      baseUri: _base,
      token: 'test-token',
      httpClient: MockClient(handler),
    );

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<http.Request> record(
    Future<void> Function(GatewayClient client) call,
    Object body,
  ) async {
    late http.Request seen;
    final client = _client((request) async {
      seen = request;
      return _json(body);
    });
    await call(client);
    expect(seen.headers['authorization'], 'Bearer test-token');
    return seen;
  }

  test('planeUsage', () async {
    final request = await record(
      (c) async {
        final usage = await c.planeUsage();
        expect(usage.models.single.model, 'm1');
        expect(usage.roles.single.role, 'worker');
        expect(usage.models.single.last7d.costUsd, 1.5);
      },
      {
        'generated_at': '2026-01-01T00:00:00Z',
        'models': [
          {
            'model': 'm1',
            'today': _bucket,
            'last_7d': _bucket,
            'last_30d': _bucket,
          },
        ],
        'roles': [
          {
            'role': 'worker',
            'model': 'm1',
            'today': _bucket,
            'last_7d': _bucket,
            'last_30d': _bucket,
          },
        ],
      },
    );
    expect(request.method, 'GET');
    expect(request.url.path, '/v1/plane/usage');
  });

  test('planeStalls', () async {
    final payload = {
      'slots': 4,
      'plans': [
        {'issue': 101, 'title': 'First plan', 'state': 'running'},
      ],
      'attention': [
        {'kind': 'review', 'severity': 'act', 'issue': 102},
      ],
    };
    final request = await record((c) async {
      final stalls = await c.planeStalls(hours: 168);
      expect(stalls.slots, 4);
      expect(stalls.plans.first.issue, 101);
      expect(stalls.attention.first.severity, 'act');
    }, payload);
    expect(request.method, 'GET');
    expect(request.url.path, '/v1/plane/stalls');
    expect(request.url.queryParameters['hours'], '168');

    final defaults = await record((c) => c.planeStalls(), payload);
    expect(defaults.url.queryParameters['hours'], '24');
  });

  test('planePlans', () async {
    final request = await record(
      (c) async {
        final plans = await c.planePlans();
        expect(plans.plans.single.title, 'Sample plan');
        expect(plans.plans.single.tasks.single.subtasksDone, 2);
      },
      {
        'plans': [
          {
            'id': 'p1',
            'title': 'Sample plan',
            'status': 'active',
            'tasks': [
              {
                'id': 't1',
                'title': 'Sample task',
                'status': 'open',
                'target': 'somewhere',
                'subtasks_done': 2,
                'subtasks_total': 4,
              },
            ],
          },
        ],
      },
    );
    expect(request.method, 'GET');
    expect(request.url.path, '/v1/plane/plans');
  });

  test('planeStatus', () async {
    final request = await record(
      (c) async {
        final status = await c.planeStatus();
        expect(status.providers.single.name, 'prov');
        expect(status.providers.single.coolingUntil, isNotNull);
        expect(status.services.single.healthy, isTrue);
        expect(status.paused.single.tier, 'low');
      },
      {
        'generated_at': '2026-01-01T00:00:00Z',
        'providers': [
          {
            'name': 'prov',
            'has_key': true,
            'current': true,
            'cooling_until': '2026-01-01T01:00:00Z',
            'reason': 'limit',
          },
        ],
        'services': [
          {'name': 'svc', 'healthy': true, 'detail': 'ok'},
        ],
        'paused': [
          {
            'tier': 'low',
            'model': 'm1',
            'use': 'all',
            'until': '2026-01-01T02:00:00Z',
            'reason': 'budget',
          },
        ],
      },
    );
    expect(request.method, 'GET');
    expect(request.url.path, '/v1/plane/status');
  });

  test('planeActions', () async {
    final request = await record(
      (c) async {
        final actions = await c.planeActions();
        expect(actions.actions.single.token, 'p');
        expect(actions.actions.single.args, 'opt-int');
      },
      {
        'actions': [
          {'token': 'p', 'args': 'opt-int', 'summary': 'Do a thing'},
        ],
      },
    );
    expect(request.method, 'GET');
    expect(request.url.path, '/v1/plane/actions');
  });

  test('runPlaneAction', () async {
    final request = await record((c) async {
      final result = await c.runPlaneAction(
        const PlaneActionRequest(token: 'p', arg: '3'),
      );
      expect(result.exitCode, 0);
      expect(result.output, 'done');
    }, {'token': 'p', 'exit_code': 0, 'output': 'done'});
    expect(request.method, 'POST');
    expect(request.url.path, '/v1/plane/actions');
    expect(request.headers['content-type'], startsWith('application/json'));
    expect(jsonDecode(request.body), {'token': 'p', 'arg': '3'});
  });

  test('error body is decoded into the exception', () async {
    final client = _client(
      (_) async =>
          http.Response('{"code":"plane_unavailable","message":"down"}', 503),
    );
    await expectLater(
      client.planeUsage(),
      throwsA(
        isA<GatewayException>()
            .having((e) => e.statusCode, 'statusCode', 503)
            .having((e) => e.code, 'code', 'plane_unavailable'),
      ),
    );
  });

  test('non-JSON error body falls back to http_<status>', () async {
    final client = _client((_) async => http.Response('oops', 500));
    await expectLater(
      client.planeUsage(),
      throwsA(
        isA<GatewayException>()
            .having((e) => e.code, 'code', 'http_500')
            .having((e) => e.message, 'message', 'oops'),
      ),
    );
  });

  test('socket failure maps to unreachable', () async {
    final client = _client((_) async => throw const SocketException('refused'));
    await expectLater(
      client.planeUsage(),
      throwsA(
        isA<GatewayException>()
            .having((e) => e.statusCode, 'statusCode', 0)
            .having((e) => e.code, 'code', 'unreachable'),
      ),
    );
  });

  group('describeGatewayError', () {
    test('402', () {
      expect(
        describeGatewayError(l10n, const GatewayException(402, 'x', 'y')),
        "The model provider's balance is exhausted — top it up to continue",
      );
    });
    test('401', () {
      expect(
        describeGatewayError(l10n, const GatewayException(401, 'x', 'y')),
        l10n.gatewayErrorUnauthorized,
      );
    });
    test('404 plane_not_configured', () {
      expect(
        describeGatewayError(
          l10n,
          const GatewayException(404, 'plane_not_configured', 'y'),
        ),
        l10n.gatewayErrorNoPlane,
      );
    });
    test('503 plane_unavailable', () {
      expect(
        describeGatewayError(
          l10n,
          const GatewayException(503, 'plane_unavailable', 'y'),
        ),
        l10n.gatewayErrorPlaneDown,
      );
    });
    test('0', () {
      expect(
        describeGatewayError(
          l10n,
          const GatewayException(0, 'unreachable', 'y'),
        ),
        l10n.gatewayErrorUnreachable,
      );
    });
    test('other', () {
      expect(
        describeGatewayError(l10n, const GatewayException(500, 'boom', 'bad')),
        'boom: bad',
      );
    });
    test('non-gateway error', () {
      expect(
        describeGatewayError(l10n, StateError('x')),
        startsWith('error: '),
      );
    });
  });

  test('forProfile without credentials throws StateError', () async {
    final repo = ProfileRepository(InMemorySecretStore());
    const profile = ServerProfile(
      id: 'srv_1',
      name: 'Test',
      host: 'gateway.example.com',
      username: 'root',
    );
    await expectLater(
      GatewayClient.forProfile(repo, profile),
      throwsA(isA<StateError>()),
    );
  });

  group('chat', () {
    GatewayClient streaming(
      Stream<List<int>> Function() body, {
      int status = 200,
      Duration? total,
      void Function(http.BaseRequest, Stream<List<int>>)? onRequest,
    }) => GatewayClient(
      baseUri: _base,
      token: 'test-token',
      httpClient: MockClient.streaming((request, requestBody) async {
        onRequest?.call(request, requestBody);
        return http.StreamedResponse(
          body(),
          status,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
      chatTotalTimeout: total ?? const Duration(seconds: 660),
    );

    const request = PlaneChatRequest(message: 'hi', tier: 'opus');

    GatewayClient fromText(List<String> parts) =>
        streaming(() => Stream.fromIterable(parts.map(utf8.encode)));

    test('full stream in chunks', () async {
      late http.BaseRequest seen;
      Object? sentBody;
      final client = streaming(
        () => Stream.fromIterable([
          utf8.encode('event: session\ndata: {"session_id":"s1","mo'),
          utf8.encode(
            'del":"m1"}\n\n: keepalive\n\nevent: delta\r\ndata: {"text":"Hel"}\r\n\r\nevent: delta\nid: 7\ndata: {"text":"lo"}\n\n',
          ),
          utf8.encode(
            'event: done\ndata: {"session_id":"s1","model":"m1","cost_usd":null,"input_tokens":1,"output_tokens":2,"cache_read_tokens":0,"cache_write_tokens":0,"turns":null}\n\nevent: delta\ndata: {"text":"after"}\n\n',
          ),
        ]),
        onRequest: (r, b) {
          seen = r;
          sentBody = utf8.decodeStream(b);
        },
      );
      final events = await client.chat(request).toList();
      expect(events, hasLength(4));
      expect(events[0], isA<PlaneChatSession>());
      expect((events[1] as PlaneChatDelta).text, 'Hel');
      expect((events[2] as PlaneChatDelta).text, 'lo');
      expect(events[3], isA<PlaneChatDone>());
      expect(seen.method, 'POST');
      expect(seen.url.path, '/v1/plane/chat');
      expect(seen.headers['authorization'], 'Bearer test-token');
      expect(jsonDecode(await (sentBody as Future<String>)), {
        'message': 'hi',
        'session_id': null,
        'tier': 'opus',
      });
    });

    test('a UTF-8 sequence split across chunks arrives intact', () async {
      final bytes = utf8.encode('event: delta\ndata: {"text":"Привет"}\n\n');
      final cut = bytes.indexOf(0xD0) + 1;
      final client = streaming(
        () => Stream.fromIterable([
          bytes.sublist(0, cut),
          bytes.sublist(cut),
          utf8.encode(
            'event: error\ndata: {"code":"failed","message":"m","subtype":null,"api_error_status":null}\n\n',
          ),
        ]),
      );
      final events = await client.chat(request).toList();
      expect((events.first as PlaneChatDelta).text, 'Привет');
    });

    test('an error event ends the stream', () async {
      final client = fromText([
        'event: error\ndata: {"code":"switched","message":"m","subtype":null,"api_error_status":null}\n\n',
        'event: delta\ndata: {"text":"x"}\n\n',
      ]);
      final events = await client.chat(request).toList();
      expect(events, hasLength(1));
      expect((events.single as PlaneChatError).code, 'switched');
    });

    test('non-200 statuses become GatewayException', () async {
      final busy = streaming(
        () =>
            Stream.value(utf8.encode('{"code":"chat_busy","message":"busy"}')),
        status: 429,
      );
      await expectLater(
        busy.chat(request).toList(),
        throwsA(
          isA<GatewayException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having((e) => e.code, 'code', 'chat_busy'),
        ),
      );
      final topUp = streaming(
        () => Stream.value(utf8.encode('{"code":"x","message":"y"}')),
        status: 402,
      );
      await expectLater(
        topUp.chat(request).toList(),
        throwsA(
          isA<GatewayException>()
              .having((e) => e.statusCode, 'statusCode', 402)
              .having(
                (e) => describeGatewayError(l10n, e),
                'text',
                l10n.gatewayErrorTopUp,
              ),
        ),
      );
    });

    test('a stream closing without done is unreachable', () async {
      final client = fromText(['event: delta\ndata: {"text":"x"}\n\n']);
      await expectLater(
        client.chat(request).toList(),
        throwsA(
          isA<GatewayException>().having((e) => e.code, 'code', 'unreachable'),
        ),
      );
    });

    test('an unknown event is skipped', () async {
      final client = fromText([
        'event: ping\ndata: {"a":1}\n\n',
        'event: delta\ndata: {"text":"x"}\n\n',
        'event: done\ndata: {"session_id":"s","model":"m","cost_usd":0.5,"input_tokens":1,"output_tokens":2,"cache_read_tokens":0,"cache_write_tokens":0,"turns":1}\n\n',
      ]);
      final events = await client.chat(request).toList();
      expect(events, hasLength(2));
      expect(events.first, isA<PlaneChatDelta>());
    });

    test('a stalled stream times out', () async {
      final controller = StreamController<List<int>>();
      controller.add(
        utf8.encode(
          'event: session\ndata: {"session_id":"s1","model":"m1"}\n\n',
        ),
      );
      final client = streaming(
        () => controller.stream,
        total: const Duration(milliseconds: 200),
      );
      await expectLater(
        client.chat(request).toList(),
        throwsA(
          isA<GatewayException>().having((e) => e.code, 'code', 'timeout'),
        ),
      );
    });

    test('non-JSON data is bad_stream', () async {
      final client = fromText(['event: delta\ndata: not json\n\n']);
      await expectLater(
        client.chat(request).toList(),
        throwsA(
          isA<GatewayException>().having((e) => e.code, 'code', 'bad_stream'),
        ),
      );
    });
  });

  test('postGuidance', () async {
    late http.Request seen;
    final client = _client((request) async {
      seen = request;
      return http.Response(
        jsonEncode({'plan_id': 'p1', 'comment_url': 'https://example.com/c/1'}),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final result = await client.postGuidance('p1', 'do X');
    expect(result.commentUrl, 'https://example.com/c/1');
    expect(seen.method, 'POST');
    expect(seen.url.path, '/v1/plane/plans/p1/guidance');
    expect(jsonDecode(seen.body), {'text': 'do X'});

    final rejecting = _client(
      (_) async =>
          http.Response('{"code":"looks_like_credential","message":"no"}', 400),
    );
    await expectLater(
      rejecting.postGuidance('p1', 'secret'),
      throwsA(
        isA<GatewayException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.code, 'code', 'looks_like_credential'),
      ),
    );
  });

  test('model switches', () async {
    const list = {
      'models': [
        {
          'tier': 'opus',
          'model': 'model-a',
          'enabled': true,
          'stand_in': null,
          'stand_in_model': null,
          'until': null,
          'reason': null,
        },
      ],
    };
    final seen = <http.Request>[];
    final client = _client((request) async {
      seen.add(request);
      return _json(list);
    });
    expect((await client.planeModels()).models.single.tier, 'opus');
    await client.disableModel('opus');
    await client.enableModel('opus');
    expect(seen.map((r) => '${r.method} ${r.url.path}'), [
      'GET /v1/plane/models',
      'POST /v1/plane/models/opus/disable',
      'POST /v1/plane/models/opus/enable',
    ]);
    expect(seen[1].body, isEmpty);
    expect(seen[2].body, isEmpty);

    final last = _client(
      (_) async => http.Response('{"code":"last_model","message":"last"}', 409),
    );
    await expectLater(
      last.disableModel('opus'),
      throwsA(
        isA<GatewayException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.code, 'code', 'last_model'),
      ),
    );
  });

  test('queue', () async {
    const payload = {
      'queue': [
        {
          'id': '11',
          'title': 'First',
          'status': 'running',
          'position': 1,
          'held': false,
          'owner_ordered': true,
        },
        {
          'id': '12',
          'title': 'Second',
          'status': 'waiting',
          'position': 2,
          'held': true,
          'owner_ordered': false,
        },
      ],
    };
    final seen = <http.Request>[];
    final client = _client((request) async {
      seen.add(request);
      return _json(payload);
    });
    final entries = (await client.planeQueue()).entries;
    expect(entries.map((e) => e.id), ['11', '12']);
    expect(entries[1].held, isTrue);
    expect(entries[0].ownerOrdered, isTrue);
    await client.moveInQueue('12', PlaneQueueVerb.top);
    await client.moveInQueue('a b', PlaneQueueVerb.resume);
    expect(seen.map((r) => '${r.method} ${r.url.path}'), [
      'GET /v1/plane/queue',
      'POST /v1/plane/queue/12/top',
      'POST /v1/plane/queue/a%20b/resume',
    ]);
    expect(seen[1].body, isEmpty);
    expect(seen[2].body, isEmpty);

    final missing = _client(
      (_) async =>
          http.Response('{"code":"no_such_plan","message":"closed"}', 404),
    );
    await expectLater(
      missing.moveInQueue('12', PlaneQueueVerb.up),
      throwsA(
        isA<GatewayException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.code, 'code', 'no_such_plan'),
      ),
    );
  });

  group('plane v2 endpoints', () {
    const queue = {
      'queue': [
        {
          'id': '11',
          'title': 'First',
          'status': 'waiting',
          'position': 1,
          'held': false,
          'owner_ordered': false,
        },
      ],
    };

    test('setPlanPriority', () async {
      final seen = <http.Request>[];
      final client = _client((request) async {
        seen.add(request);
        return _json(queue);
      });
      final queued = await client.setPlanPriority('11', 2);
      await client.setPlanPriority('11', null);
      expect(queued.entries.first.id, '11');
      expect(seen[0].method, 'POST');
      expect(seen[0].url.path, '/v1/plane/queue/11/priority');
      expect(jsonDecode(seen[0].body), {'priority': 2});
      expect(jsonDecode(seen[1].body), {'priority': null});
    });

    test('setPlanBudget', () async {
      final seen = <http.Request>[];
      final client = _client((request) async {
        seen.add(request);
        return _json(queue);
      });
      final queued = await client.setPlanBudget('12', 250);
      await client.setPlanBudget('12', null);
      expect(queued.entries.first.id, '11');
      expect(seen[0].method, 'POST');
      expect(seen[0].url.path, '/v1/plane/plans/12/budget');
      expect(jsonDecode(seen[0].body), {'steps': 250});
      expect(jsonDecode(seen[1].body), {'steps': null});
    });

    test('setPlanPriority on a closed plan throws', () async {
      final client = _client(
        (_) async =>
            http.Response('{"code":"no_such_plan","message":"closed"}', 404),
      );
      await expectLater(
        client.setPlanPriority('11', 1),
        throwsA(
          isA<GatewayException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.code, 'code', 'no_such_plan'),
        ),
      );
    });

    test('planeCapacity', () async {
      late http.Request seen;
      final client = _client((request) async {
        seen = request;
        return _json({
          'slots_now': 3,
          'state': {'running': 1},
        });
      });
      final capacity = await client.planeCapacity();
      expect(seen.method, 'GET');
      expect(seen.url.path, '/v1/plane/capacity');
      expect(capacity.slotsNow, 3);
      expect(capacity.running, 1);
    });

    test('planeStats', () async {
      late http.Request seen;
      final client = _client((request) async {
        seen = request;
        return _json({'days': 7, 'forecast': []});
      });
      final stats = await client.planeStats();
      expect(seen.method, 'GET');
      expect(seen.url.path, '/v1/plane/stats');
      expect(stats.days, 7);
    });
  });
}
