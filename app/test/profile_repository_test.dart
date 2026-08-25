import 'package:accent/models/server_profile.dart';
import 'package:accent/services/profile_repository.dart';
import 'package:accent/services/secret_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySecretStore store;
  late ProfileRepository repo;

  setUp(() {
    store = InMemorySecretStore();
    repo = ProfileRepository(store);
  });

  const profile = ServerProfile(
    id: 'srv_1',
    name: 'Home server',
    host: '192.0.2.10',
    username: 'root',
  );

  group('profiles', () {
    test('an empty store lists nothing rather than throwing', () async {
      expect(await repo.list(), isEmpty);
    });

    test('a saved profile survives a round trip', () async {
      await repo.save(profile);

      final loaded = (await repo.list()).single;
      expect(loaded.id, 'srv_1');
      expect(loaded.host, '192.0.2.10');
      expect(loaded.port, 22);
      expect(loaded.gatewayPort, 8443);
      expect(loaded.bootstrapped, isFalse);
    });

    test('saving the same id replaces rather than duplicates', () async {
      await repo.save(profile);
      await repo.save(profile.copyWith(name: 'Renamed', bootstrapped: true));

      final all = await repo.list();
      expect(all, hasLength(1));
      expect(all.single.name, 'Renamed');
      expect(all.single.bootstrapped, isTrue);
    });

    test('the gateway URI is built from host and gateway port', () {
      expect(profile.gatewayUri.toString(), 'https://192.0.2.10:8443');
    });
  });

  group('secrets', () {
    test('key material is namespaced by profile', () async {
      await repo.save(profile);
      await repo.storeSshPrivateKey('srv_1', '-----BEGIN OPENSSH KEY-----');
      await repo.storeGatewayCredentials(
        'srv_1',
        token: 'a-gateway-token',
        certificatePem: '-----BEGIN CERTIFICATE-----',
      );

      expect(await repo.sshPrivateKey('srv_1'), startsWith('-----BEGIN'));
      expect(await repo.gatewayToken('srv_1'), 'a-gateway-token');
      expect(
        store.keys.where((k) => k.startsWith('server.srv_1.')),
        hasLength(3),
      );
    });

    test('forgetting a server leaves no key material behind', () async {
      // The point of the test: a private key left behind still grants access
      // somewhere, and nothing will ever rotate it.
      await repo.save(profile);
      await repo.storeSshPrivateKey('srv_1', 'key');
      await repo.storeGatewayCredentials(
        'srv_1',
        token: 'token',
        certificatePem: 'cert',
      );

      await repo.forget('srv_1');

      expect(await repo.list(), isEmpty);
      expect(await repo.sshPrivateKey('srv_1'), isNull);
      expect(await repo.gatewayToken('srv_1'), isNull);
      expect(await repo.gatewayCertificate('srv_1'), isNull);
      expect(store.keys.where((k) => k.startsWith('server.')), isEmpty);
    });

    test('forgetting one server does not touch another', () async {
      const other = ServerProfile(
        id: 'srv_2',
        name: 'Other',
        host: '192.0.2.11',
        username: 'root',
      );
      await repo.save(profile);
      await repo.save(other);
      await repo.storeSshPrivateKey('srv_1', 'first');
      await repo.storeSshPrivateKey('srv_2', 'second');

      await repo.forget('srv_1');

      expect((await repo.list()).single.id, 'srv_2');
      expect(await repo.sshPrivateKey('srv_2'), 'second');
    });
  });

  group('profile hygiene', () {
    test('toString cannot leak key material', () {
      // There is no password or key field on the class at all, which is what
      // makes this guarantee structural rather than a matter of remembering.
      final text = profile.toString();
      expect(text, contains('srv_1'));
      expect(text.toLowerCase(), isNot(contains('password')));
      expect(text.toLowerCase(), isNot(contains('key')));
    });

    test('serialisation carries no secret fields', () {
      expect(profile.toJson().keys, <String>{
        'id',
        'name',
        'host',
        'username',
        'port',
        'gateway_port',
        'bootstrapped',
      });
    });
  });
}
