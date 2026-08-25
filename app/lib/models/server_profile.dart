import 'dart:convert';

/// A server this phone can reach.
///
/// Deliberately split into what is safe to describe and what is not. This class
/// holds only the former: address, port, login, a name to show. The SSH private
/// key, the gateway token and the pinned certificate are secrets, kept under
/// separate keys in the secret store and never part of a profile object — so a
/// profile can be logged, compared or serialised for the UI without any chance
/// of a secret riding along.
class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.host,
    required this.username,
    this.port = 22,
    this.gatewayPort = 8443,
    this.bootstrapped = false,
  });

  /// Stable identifier, also the key prefix under which this profile's secrets
  /// live. It must not be derived from the host: renaming or re-addressing a
  /// server would then orphan its key material.
  final String id;

  final String name;
  final String host;
  final String username;
  final int port;
  final int gatewayPort;

  /// True once the stack is deployed and a gateway token has been issued. Until
  /// then the profile is an intention, not a working connection.
  final bool bootstrapped;

  Uri get gatewayUri => Uri(scheme: 'https', host: host, port: gatewayPort);

  ServerProfile copyWith({String? name, bool? bootstrapped}) => ServerProfile(
    id: id,
    name: name ?? this.name,
    host: host,
    username: username,
    port: port,
    gatewayPort: gatewayPort,
    bootstrapped: bootstrapped ?? this.bootstrapped,
  );

  factory ServerProfile.fromJson(Map<String, dynamic> json) => ServerProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    host: json['host'] as String,
    username: json['username'] as String,
    port: json['port'] as int? ?? 22,
    gatewayPort: json['gateway_port'] as int? ?? 8443,
    bootstrapped: json['bootstrapped'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'username': username,
    'port': port,
    'gateway_port': gatewayPort,
    'bootstrapped': bootstrapped,
  };

  static List<ServerProfile> decodeList(String raw) =>
      (jsonDecode(raw) as List<dynamic>)
          .map((item) => ServerProfile.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);

  static String encodeList(List<ServerProfile> profiles) =>
      jsonEncode(profiles.map((p) => p.toJson()).toList());

  /// Never includes the port-forwarded secrets, and never the password — which
  /// is not a field here at all, precisely so it cannot be printed.
  @override
  String toString() => 'ServerProfile($id, $username@$host:$port)';
}
