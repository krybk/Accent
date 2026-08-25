import 'package:flutter/material.dart';

import 'screens/servers_screen.dart';
import 'services/profile_repository.dart';
import 'services/secret_store.dart';

/// The repository is built here, once, and handed down.
///
/// One instance because it is the only door to the key store, and a second one
/// would be a second view of the same profile list that can fall out of step
/// with the first. It is a parameter rather than a global so that a test can
/// build the app over [InMemorySecretStore], which is the only way these screens
/// can be tested at all: the Keystore lives behind a platform channel.
void main() =>
    runApp(AccentApp(profiles: ProfileRepository(KeystoreSecretStore())));

class AccentApp extends StatelessWidget {
  const AccentApp({required this.profiles, super.key});

  final ProfileRepository profiles;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Accent',
      debugShowCheckedModeBanner: false,
      // Both schemes are built from one seed so light and dark stay consistent
      // without a second palette to keep in sync by hand.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F6EA8)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F6EA8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: ServersScreen(profiles: profiles),
    );
  }
}
