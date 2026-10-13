import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/server_profile.dart';
import '../services/gateway_client.dart';
import 'plane_screen.dart';
import 'usage_screen.dart';

/// The home of one bootstrapped server: the plane and the token usage, each a
/// destination of the bottom bar.
///
/// The gateway client is obtained once, from the factory, and closed when the
/// screen goes away. Only the selected destination is built, so a hidden tab
/// does not poll the gateway.
class ServerHomeScreen extends StatefulWidget {
  const ServerHomeScreen({
    required this.profile,
    required this.clients,
    super.key,
  });

  final ServerProfile profile;
  final GatewayClientFactory clients;

  @override
  State<ServerHomeScreen> createState() => _ServerHomeScreenState();
}

class _ServerHomeScreenState extends State<ServerHomeScreen> {
  late final Future<GatewayClient> _client;
  GatewayClient? _obtained;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _client = widget.clients(widget.profile).then((c) => _obtained = c);
  }

  @override
  void dispose() {
    _obtained?.close();
    super.dispose();
  }

  // A list rather than two fields: a later slice adds Chat.
  List<(IconData, String)> _destinations(AppLocalizations l10n) => [
    (Icons.dashboard_outlined, l10n.navPlane),
    (Icons.bar_chart, l10n.navUsage),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.profile.name)),
      body: FutureBuilder<GatewayClient>(
        future: _client,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error!;
            return Center(
              child: Text(
                error is StateError
                    ? l10n.gatewayErrorNoCredentials
                    : describeGatewayError(l10n, error),
              ),
            );
          }
          final c = snapshot.data!;
          return _index == 0 ? PlaneScreen(client: c) : UsageScreen(client: c);
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final (icon, label) in _destinations(l10n))
            NavigationDestination(icon: Icon(icon), label: label),
        ],
      ),
    );
  }
}
