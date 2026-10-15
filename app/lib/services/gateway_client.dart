import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:accent_protocol/protocol.dart';

import '../l10n/app_localizations.dart';
import '../models/server_profile.dart';
import './profile_repository.dart';

/// A failed gateway call. [statusCode] 0 means the server was not reached.
class GatewayException implements Exception {
  const GatewayException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'GatewayException($statusCode, $code): $message';
}

typedef GatewayClientFactory =
    Future<GatewayClient> Function(ServerProfile profile);

/// HTTP client for the gateway's `/v1/plane` contract.
class GatewayClient {
  GatewayClient({
    required Uri baseUri,
    required String token,
    required http.Client httpClient,
    this.chatHeaderTimeout = const Duration(seconds: 20),
    this.chatTotalTimeout = const Duration(seconds: 660),
  }) : _baseUri = baseUri,
       _token = token,
       _http = httpClient;

  final Uri _baseUri;
  final String _token;
  final http.Client _http;
  final Duration chatHeaderTimeout;
  final Duration chatTotalTimeout;

  Future<PlaneUsage> planeUsage() async => PlaneUsage.fromJson(
    await _send('GET', '/v1/plane/usage', const Duration(seconds: 20)),
  );

  Future<PlanList> planePlans() async => PlanList.fromJson(
    await _send('GET', '/v1/plane/plans', const Duration(seconds: 20)),
  );

  Future<PlaneStatus> planeStatus() async => PlaneStatus.fromJson(
    await _send('GET', '/v1/plane/status', const Duration(seconds: 20)),
  );

  Future<PlaneActionList> planeActions() async => PlaneActionList.fromJson(
    await _send('GET', '/v1/plane/actions', const Duration(seconds: 20)),
  );

  /// The server caps an action at 150 s, hence the longer timeout.
  Future<PlaneActionResult> runPlaneAction(PlaneActionRequest request) async =>
      PlaneActionResult.fromJson(
        await _send(
          'POST',
          '/v1/plane/actions',
          const Duration(seconds: 170),
          body: jsonEncode(request.toJson()),
        ),
      );

  Future<PlaneGuidanceResult> postGuidance(String planId, String text) async =>
      PlaneGuidanceResult.fromJson(
        await _send(
          'POST',
          '/v1/plane/plans/${Uri.encodeComponent(planId)}/guidance',
          const Duration(seconds: 30),
          body: jsonEncode(PlaneGuidanceRequest(text: text).toJson()),
        ),
      );

  Future<PlaneModelSwitchList> planeModels() async =>
      PlaneModelSwitchList.fromJson(
        await _send('GET', '/v1/plane/models', const Duration(seconds: 20)),
      );

  Future<PlaneModelSwitchList> disableModel(String tier) async =>
      PlaneModelSwitchList.fromJson(
        await _send(
          'POST',
          '/v1/plane/models/${Uri.encodeComponent(tier)}/disable',
          const Duration(seconds: 60),
        ),
      );

  Future<PlaneModelSwitchList> enableModel(String tier) async =>
      PlaneModelSwitchList.fromJson(
        await _send(
          'POST',
          '/v1/plane/models/${Uri.encodeComponent(tier)}/enable',
          const Duration(seconds: 60),
        ),
      );

  Future<PlaneQueue> planeQueue() async => PlaneQueue.fromJson(
    await _send('GET', '/v1/plane/queue', const Duration(seconds: 20)),
  );

  Future<PlaneQueue> moveInQueue(String planId, PlaneQueueVerb verb) async =>
      PlaneQueue.fromJson(
        await _send(
          'POST',
          '/v1/plane/queue/${Uri.encodeComponent(planId)}/${verb.name}',
          const Duration(seconds: 60),
        ),
      );

  /// Sets the plan's priority; null restores the server default.
  Future<PlaneQueue> setPlanPriority(String planId, int? priority) async =>
      PlaneQueue.fromJson(
        await _send(
          'POST',
          '/v1/plane/queue/${Uri.encodeComponent(planId)}/priority',
          const Duration(seconds: 60),
          body: jsonEncode({'priority': priority}),
        ),
      );

  /// Sets the plan's step budget; null restores the server default.
  Future<PlaneQueue> setPlanBudget(String planId, int? steps) async =>
      PlaneQueue.fromJson(
        await _send(
          'POST',
          '/v1/plane/plans/${Uri.encodeComponent(planId)}/budget',
          const Duration(seconds: 60),
          body: jsonEncode({'steps': steps}),
        ),
      );

  Future<PlaneCapacity> planeCapacity() async => PlaneCapacity.fromJson(
    await _send('GET', '/v1/plane/capacity', const Duration(seconds: 20)),
  );

  Future<PlaneStats> planeStats() async => PlaneStats.fromJson(
    await _send('GET', '/v1/plane/stats', const Duration(seconds: 30)),
  );

  /// Streams the answer to a chat message as server-sent events. Ends after
  /// the first `done` or `error` event.
  Stream<PlaneChatEvent> chat(PlaneChatRequest r) async* {
    final request =
        http.Request('POST', _baseUri.replace(path: '/v1/plane/chat'))
          ..headers['authorization'] = 'Bearer $_token'
          ..headers['content-type'] = 'application/json'
          ..headers['accept'] = 'text/event-stream'
          ..body = jsonEncode(r.toJson());
    final stopwatch = Stopwatch()..start();
    final http.StreamedResponse streamed;
    try {
      streamed = await _http.send(request).timeout(chatHeaderTimeout);
    } on TimeoutException catch (error) {
      throw GatewayException(0, 'unreachable', '$error');
    } on SocketException catch (error) {
      throw GatewayException(0, 'unreachable', '$error');
    } on HandshakeException catch (error) {
      throw GatewayException(0, 'unreachable', '$error');
    } on TlsException catch (error) {
      throw GatewayException(0, 'unreachable', '$error');
    } on http.ClientException catch (error) {
      throw GatewayException(0, 'unreachable', '$error');
    }
    if (streamed.statusCode != 200) {
      final http.Response response;
      try {
        response = await http.Response.fromStream(
          streamed,
        ).timeout(chatHeaderTimeout);
      } on TimeoutException catch (error) {
        throw GatewayException(0, 'unreachable', '$error');
      } on SocketException catch (error) {
        throw GatewayException(0, 'unreachable', '$error');
      } on HandshakeException catch (error) {
        throw GatewayException(0, 'unreachable', '$error');
      } on TlsException catch (error) {
        throw GatewayException(0, 'unreachable', '$error');
      } on http.ClientException catch (error) {
        throw GatewayException(0, 'unreachable', '$error');
      }
      throw _failure(streamed.statusCode, utf8.decode(response.bodyBytes));
    }
    final lines = StreamIterator(
      streamed.stream.transform(utf8.decoder).transform(const LineSplitter()),
    );
    try {
      String? name;
      final data = <String>[];
      while (true) {
        final remaining = chatTotalTimeout - stopwatch.elapsed;
        if (remaining <= Duration.zero) {
          throw GatewayException(
            0,
            'timeout',
            'chat exceeded $chatTotalTimeout',
          );
        }
        final bool has;
        try {
          has = await lines.moveNext().timeout(remaining);
        } on TimeoutException catch (error) {
          throw GatewayException(0, 'timeout', '$error');
        } on SocketException catch (error) {
          throw GatewayException(0, 'unreachable', '$error');
        } on http.ClientException catch (error) {
          throw GatewayException(0, 'unreachable', '$error');
        } on HandshakeException catch (error) {
          throw GatewayException(0, 'unreachable', '$error');
        } on TlsException catch (error) {
          throw GatewayException(0, 'unreachable', '$error');
        }
        if (!has) {
          throw const GatewayException(
            0,
            'unreachable',
            'the answer stream ended before done',
          );
        }
        final line = lines.current;
        if (line.isEmpty) {
          final eventName = name;
          final payload = data.join('\n');
          final hasData = data.isNotEmpty;
          name = null;
          data.clear();
          if (eventName == null || !hasData) continue;
          if (!const {
            'session',
            'delta',
            'done',
            'error',
          }.contains(eventName)) {
            continue;
          }
          final Object? decoded;
          try {
            decoded = jsonDecode(payload);
          } on FormatException catch (error) {
            throw GatewayException(200, 'bad_stream', '$error');
          }
          if (decoded is! Map<String, dynamic>) {
            throw const GatewayException(
              200,
              'bad_stream',
              'an event carried no JSON object',
            );
          }
          final PlaneChatEvent event;
          try {
            event = PlaneChatEvent.parse(eventName, decoded);
          } on TypeError catch (error) {
            throw GatewayException(200, 'bad_stream', '$error');
          }
          yield event;
          if (event is PlaneChatDone || event is PlaneChatError) return;
        } else if (line.startsWith(':')) {
          continue;
        } else if (line.startsWith('event:')) {
          name = _sseValue(line, 'event:');
        } else if (line.startsWith('data:')) {
          data.add(_sseValue(line, 'data:'));
        }
      }
    } finally {
      await lines.cancel();
    }
  }

  static String _sseValue(String line, String field) {
    final value = line.substring(field.length);
    return value.startsWith(' ') ? value.substring(1) : value;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Duration timeout, {
    String? body,
  }) async {
    final http.Response response;
    try {
      final request = http.Request(method, _baseUri.replace(path: path))
        ..headers['authorization'] = 'Bearer $_token';
      if (body != null) {
        request.headers['content-type'] = 'application/json';
        request.body = body;
      }
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException catch (error) {
      throw GatewayException(0, 'unreachable', '$error');
    } on SocketException catch (error) {
      throw GatewayException(0, 'unreachable', '$error');
    } on HandshakeException catch (error) {
      throw GatewayException(0, 'unreachable', '$error');
    } on TlsException catch (error) {
      throw GatewayException(0, 'unreachable', '$error');
    } on http.ClientException catch (error) {
      throw GatewayException(0, 'unreachable', '$error');
    }
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(text) as Map<String, dynamic>;
    }
    throw _failure(response.statusCode, text);
  }

  GatewayException _failure(int statusCode, String text) {
    final ApiError apiError;
    try {
      apiError = ApiError.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      return GatewayException(
        statusCode,
        'http_$statusCode',
        text.length > 200 ? text.substring(0, 200) : text,
      );
    }
    return GatewayException(statusCode, apiError.code, apiError.message);
  }

  void close() => _http.close();

  /// A client that trusts only [certificatePem], the stack's CA root stored at
  /// bootstrap. Hostname verification stays on.
  static http.Client pinnedHttpClient(String certificatePem) => IOClient(
    HttpClient(
      context: SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificatesBytes(utf8.encode(certificatePem)),
    )..connectionTimeout = const Duration(seconds: 10),
  );

  static Future<GatewayClient> forProfile(
    ProfileRepository profiles,
    ServerProfile profile,
  ) async {
    final token = await profiles.gatewayToken(profile.id);
    final cert = await profiles.gatewayCertificate(profile.id);
    if (token == null || cert == null) {
      throw StateError('no gateway credentials for ${profile.id}');
    }
    return GatewayClient(
      baseUri: profile.gatewayUri,
      token: token,
      httpClient: pinnedHttpClient(cert),
    );
  }
}

String describeGatewayError(AppLocalizations l10n, Object error) {
  if (error is GatewayException) {
    if (error.statusCode == 402) return l10n.gatewayErrorTopUp;
    if (error.statusCode == 401) return l10n.gatewayErrorUnauthorized;
    if (error.statusCode == 404 && error.code == 'plane_not_configured') {
      return l10n.gatewayErrorNoPlane;
    }
    if (error.statusCode == 503 && error.code == 'plane_unavailable') {
      return l10n.gatewayErrorPlaneDown;
    }
    if (error.statusCode == 0) return l10n.gatewayErrorUnreachable;
    return l10n.gatewayErrorOther(error.code, error.message);
  }
  return l10n.gatewayErrorOther('error', '$error');
}
