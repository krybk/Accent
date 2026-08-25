import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where secrets live.
///
/// An interface rather than a direct dependency on `flutter_secure_storage` for
/// one reason that matters: that package talks to the Android Keystore over a
/// platform channel, so anything using it directly can only be tested on a
/// device. Everything above this line is testable on the host.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  /// Removes every key under a prefix. Used when a server is forgotten: leaving
  /// a stale private key behind means a key that still grants root somewhere and
  /// that nothing will ever rotate.
  Future<void> deletePrefix(String prefix);
}

/// Android Keystore-backed implementation.
class KeystoreSecretStore implements SecretStore {
  KeystoreSecretStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          // The default AndroidOptions in v11 is already the strong path:
          // AES-GCM for the data, an RSA-wrapped key held in the Android
          // Keystore. Earlier versions needed encryptedSharedPreferences: true
          // to get there; that flag no longer exists, and passing it fails to
          // compile rather than silently doing nothing — which is the better of
          // the two ways for an API to change.
          //
          // One default worth knowing: resetOnError is true, so a decryption
          // failure clears the store rather than leaving it unreadable forever.
          // For us that costs a re-bootstrap with the root password, which is
          // recoverable; being permanently locked out of our own keys would not
          // be.
          const FlutterSecureStorage(aOptions: AndroidOptions());

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deletePrefix(String prefix) async {
    final all = await _storage.readAll();
    for (final key in all.keys.where((k) => k.startsWith(prefix))) {
      await _storage.delete(key: key);
    }
  }
}

/// In-memory implementation for tests. Not for use in the app: it is exactly the
/// guarantee-free storage that [KeystoreSecretStore] exists to avoid.
class InMemorySecretStore implements SecretStore {
  final Map<String,String> _values =   {};

      Iterable<String> get keys => _values.keys;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> deletePrefix(String prefix) async =>
      _values.removeWhere((key, _) => key.startsWith(prefix));
}
