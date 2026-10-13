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
  }) : _baseUri = baseUri,
       _token = token,
       _http = httpClient;

  final Uri _baseUri;
  final String _token;
  final http.Client _http;

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
    final ApiError apiError;
    try {
      apiError = ApiError.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      throw GatewayException(
        response.statusCode,
        'http_${response.statusCode}',
        text.length > 200 ? text.substring(0, 200) : text,
      );
    }
    throw GatewayException(
      response.statusCode,
      apiError.code,
      apiError.message,
    );
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
