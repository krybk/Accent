import 'dart:convert';
import 'dart:io';

import 'package:accent_gateway/src/auth.dart';
import 'package:accent_gateway/src/config.dart';
import 'package:accent_gateway/src/plane_proxy.dart';
import 'package:accent_gateway/src/routes.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

class Recorded {
  Recorded(
    this.method,
    this.path,
    this.query,
    this.contentType,
    this.authorization,
    this.body,
  );
  final String method;
  final String path;
  final String query;
  final String? contentType;
  final String? authorization;
  final String body;
}

void main() {
  late Directory dir;
  late String sockPath;
  late HttpServer server;
  late List<Recorded> recorded;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('plane_test');
    sockPath = '${dir.path}/plane.sock';
    recorded = [];
    server = await HttpServer.bind(
      InternetAddress(sockPath, type: InternetAddressType.unix),
      0,
    );
    server.listen((req) async {
      final body = await utf8.decoder.bind(req).join();
      recorded.add(
        Recorded(
          req.method,
          req.uri.path,
          req.uri.query,
          req.headers.value('content-type'),
          req.headers.value('authorization'),
          body,
        ),
      );
      final res = req.response;
      switch (req.uri.path) {
        case '/v1/plane/usage':
          res
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write('{"ok":true}');
        case '/v1/plane/boom':
          res
            ..statusCode = 500
            ..write('broken');
        case '/v1/plane/actions':
          res
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(body);
        default:
          res.statusCode = 404;
      }
      await res.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    dir.deleteSync(recursive: true);
  });

  Handler proxy(String? path) =>
      (Router()..mount('/v1/plane/', planeProxy(path))).call;

  test('forwards GET with its query', () async {
    final response = await proxy(sockPath)(
      Request('GET', Uri.parse('http://localhost/v1/plane/usage?days=7&x=1')),
    );
    expect(response.statusCode, 200);
    expect(await response.readAsString(), '{"ok":true}');
    expect(response.headers['content-type'], contains('application/json'));
    expect(recorded.single.path, '/v1/plane/usage');
    expect(recorded.single.query, 'days=7&x=1');
  });

  test('forwards POST body and content-type, never authorization', () async {
    const sent = '{"token":"p","arg":"5"}';
    final response = await proxy(sockPath)(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/plane/actions'),
        body: sent,
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer secret',
        },
      ),
    );
    expect(response.statusCode, 200);
    await response.readAsString();
    expect(recorded.single.body, sent);
    expect(recorded.single.contentType, contains('application/json'));
    expect(recorded.single.authorization, isNull);
  });

  test('passes an upstream error through', () async {
    final response = await proxy(sockPath)(
      Request('GET', Uri.parse('http://localhost/v1/plane/boom')),
    );
    expect(response.statusCode, 500);
    expect(await response.readAsString(), 'broken');
  });

  test('404 when no plane is configured', () async {
    final response = await proxy(null)(
      Request('GET', Uri.parse('http://localhost/v1/plane/usage')),
    );
    expect(response.statusCode, 404);
    final json = jsonDecode(await response.readAsString()) as Map;
    expect(json['code'], 'plane_not_configured');
  });

  test('503 when the socket is unreachable', () async {
    final response = await proxy('${dir.path}/missing.sock')(
      Request('GET', Uri.parse('http://localhost/v1/plane/usage')),
    );
    expect(response.statusCode, 503);
    final json = jsonDecode(await response.readAsString()) as Map;
    expect(json['code'], 'plane_unavailable');
  });

  test('405 for other methods, nothing forwarded', () async {
    final response = await proxy(sockPath)(
      Request('PUT', Uri.parse('http://localhost/v1/plane/usage')),
    );
    expect(response.statusCode, 405);
    final json = jsonDecode(await response.readAsString()) as Map;
    expect(json['code'], 'method_not_allowed');
    expect(recorded, isEmpty);
  });

  test('full pipeline requires the token', () async {
    const token = 'a-token-that-is-long-enough-to-pass-32';
    final handler = const Pipeline()
        .addMiddleware(requireToken(token))
        .addHandler(
          buildRouter(
            GatewayConfig(
              token: token,
              litellmUrl: Uri.parse('http://litellm:4000'),
              litellmKey: 'k',
              planeSocket: sockPath,
            ),
            MockClient((_) async => http.Response('', 500)),
          ).call,
        );

    final denied = await handler(
      Request('GET', Uri.parse('http://localhost/v1/plane/usage')),
    );
    expect(denied.statusCode, 401);
    expect(recorded, isEmpty);

    final allowed = await handler(
      Request(
        'GET',
        Uri.parse('http://localhost/v1/plane/usage'),
        headers: {'authorization': 'Bearer $token'},
      ),
    );
    expect(allowed.statusCode, 200);
    expect(await allowed.readAsString(), '{"ok":true}');
    expect(recorded.single.authorization, isNull);
  });
}
