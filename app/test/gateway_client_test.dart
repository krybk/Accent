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
}
