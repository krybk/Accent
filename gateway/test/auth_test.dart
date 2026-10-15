import 'dart:convert';
import 'dart:io';

import 'package:accent_gateway/src/auth.dart';
import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const envToken = 'an-environment-token-long-enough-32-chars';

String hashLine(String t) => 'sha256:${sha256.convert(utf8.encode(t))}';

Request get(String path, {String? bearer, String? header}) => Request(
  'GET',
  Uri.parse('http://localhost/$path'),
  headers: header != null
      ? {'authorization': header}
      : bearer == null
      ? null
      : {'authorization': 'Bearer $bearer'},
);

void main() {
  late Directory dir;
  late Handler handler;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('auth_test');
    handler = const Pipeline()
        .addMiddleware(requireToken(envToken, tokensDir: dir.path))
        .addHandler((_) => Response.ok('in'));
  });

  tearDown(() => dir.delete(recursive: true));

  Future<int> status(Handler h, String bearer) async =>
      (await h(get('x', bearer: bearer))).statusCode;

  test('the environment token passes', () async {
    expect(await status(handler, envToken), 200);
  });

  test('a token whose hash is in a file passes', () async {
    File('${dir.path}/phone-a').writeAsStringSync('${hashLine('token-a')}\n');
    expect(await status(handler, 'token-a'), 200);
  });

  test('deleting a file revokes that token only', () async {
    File('${dir.path}/phone-a').writeAsStringSync('${hashLine('token-a')}\n');
    File('${dir.path}/phone-b').writeAsStringSync('${hashLine('token-b')}\n');
    expect(await status(handler, 'token-a'), 200);
    File('${dir.path}/phone-a').deleteSync();
    expect(await status(handler, 'token-a'), 401);
    expect(await status(handler, 'token-b'), 200);
    expect(await status(handler, envToken), 200);
  });

  test('a .tmp file is not a credential', () async {
    File(
      '${dir.path}/phone-c.tmp',
    ).writeAsStringSync('${hashLine('token-c')}\n');
    expect(await status(handler, 'token-c'), 401);
  });

  test('a malformed file is ignored and does not break the others', () async {
    File('${dir.path}/junk').writeAsStringSync('not a hash\n');
    File(
      '${dir.path}/upper',
    ).writeAsStringSync('${hashLine('token-u').toUpperCase()}\n');
    File('${dir.path}/phone-b').writeAsStringSync('${hashLine('token-b')}\n');
    expect(await status(handler, 'token-u'), 401);
    expect(await status(handler, 'token-b'), 200);
    expect(await status(handler, envToken), 200);
  });

  test('a missing directory leaves only the environment token', () async {
    final absent = const Pipeline()
        .addMiddleware(requireToken(envToken, tokensDir: '${dir.path}/absent'))
        .addHandler((_) => Response.ok('in'));
    expect(await status(absent, envToken), 200);
    expect(await status(absent, 'token-a'), 401);

    final none = const Pipeline()
        .addMiddleware(requireToken(envToken))
        .addHandler((_) => Response.ok('in'));
    expect(await status(none, envToken), 200);
    expect(await status(none, 'token-a'), 401);
  });

  test('an empty bearer is rejected', () async {
    File('${dir.path}/empty').writeAsStringSync('${hashLine('')}\n');
    final response = await handler(get('x', header: 'Bearer '));
    expect(response.statusCode, 401);
  });

  test('/live needs no credential', () async {
    expect((await handler(get('live'))).statusCode, 200);
  });

  test('the 401 body is unchanged', () async {
    final response = await handler(get('x', bearer: 'wrong'));
    expect(response.statusCode, 401);
    expect(
      await response.readAsString(),
      jsonEncode({'code': 'unauthorized', 'message': 'invalid token'}),
    );
  });
}
