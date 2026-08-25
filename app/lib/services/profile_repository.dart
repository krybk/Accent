import '../models/server_profile.dart';
import 'secret_store.dart';

/// Stores server profiles and their key material.
///
/// Both go into the secret store rather than only the secrets. A profile is not
/// itself confidential, but the list of servers someone administers is worth
/// keeping out of an unencrypted backup, and splitting the two across separate
/// stores would mean two things that can drift out of step.
class ProfileRepository {
  ProfileRepository(this._store);

  final SecretStore _store;

  static const _profilesKey = 'profiles';

  // Secrets are namespaced by profile id so that forgetting a server can delete
  // everything it owns with one prefix sweep, with no list to keep in sync.
  static String _privateKeyKey(String id) => 'server.$id.ssh_private_key';
  static String _gatewayTokenKey(String id) => 'server.$id.gateway_token';
  static String _certKey(String id) => 'server.$id.gateway_cert';

  Future<List<ServerProfile>> list() async {
    final raw = await _store.read(_profilesKey);
    if (raw == null || raw.isEmpty) return const [];
    return ServerProfile.decodeList(raw);
  }

  Future<void> _saveAll(List<ServerProfile> profiles) =>
      _store.write(_profilesKey, ServerProfile.encodeList(profiles));

  /// Adds a profile, or replaces the one with the same id.
  Future<void> save(ServerProfile profile) async {
    final profiles = [...await list()];
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index == -1) {
      profiles.add(profile);
    } else {
      profiles[index] = profile;
    }
    await _saveAll(profiles);
  }

  /// Removes a profile and everything it owns.
  ///
  /// The prefix sweep is the point: a private key left behind is a key that
  /// still grants access somewhere and that nothing will ever rotate.
  Future<void> forget(String id) async {
    final profiles = (await list()).where((p) => p.id != id).toList();
    await _saveAll(profiles);
    await _store.deletePrefix('server.$id.');
  }

  Future<void> storeSshPrivateKey(String id, String pem) =>
      _store.write(_privateKeyKey(id), pem);

  Future<String?> sshPrivateKey(String id) => _store.read(_privateKeyKey(id));

  Future<void> storeGatewayCredentials(
    String id, {
    required String token,
    required String certificatePem,
  }) async {
    await _store.write(_gatewayTokenKey(id), token);
    await _store.write(_certKey(id), certificatePem);
  }

  Future<String?> gatewayToken(String id) => _store.read(_gatewayTokenKey(id));

  Future<String?> gatewayCertificate(String id) => _store.read(_certKey(id));
}
