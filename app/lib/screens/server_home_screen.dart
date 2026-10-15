import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/server_profile.dart';
import '../services/gateway_client.dart';
import 'capacity_screen.dart';
import 'chat_screen.dart';
import 'plane_screen.dart';
import 'queue_screen.dart';
import 'stats_screen.dart';
import 'usage_screen.dart';

/// The home of one bootstrapped server: the plane, the token usage, the chat
/// and the plan queue, each a destination of the bottom bar.
///
/// The gateway client is obtained once, from the factory, and closed when the
/// screen goes away. Plane, Usage and Queue are built only while selected, so a
/// hidden tab does not poll the gateway. The chat is kept alive, so its
/// conversation and a running answer survive a switch to another tab.
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
    _client = widget.clients(widget.profile).then((c) {
      // A client that arrives after the screen has gone is closed at once.
      if (!mounted) c.close();
      return _obtained = c;
    });
  }

  @override
  void dispose() {
    _obtained?.close();
    super.dispose();
  }

  // Plane, Usage, Chat, Queue, Load, Stats -- the order of the IndexedStack below.
  List<(IconData, String)> _destinations(AppLocalizations l10n) => [
    (Icons.dashboard_outlined, l10n.navPlane),
    (Icons.bar_chart, l10n.navUsage),
    (Icons.chat_bubble_outline, l10n.navChat),
    (Icons.format_list_numbered, l10n.navQueue),
    (Icons.memory, l10n.navCapacity),
    (Icons.insights, l10n.navStats),
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
          return IndexedStack(
            index: _index,
            children: [
              _index == 0 ? PlaneScreen(client: c) : const SizedBox.shrink(),
              _index == 1 ? UsageScreen(client: c) : const SizedBox.shrink(),
              ChatScreen(client: c),
              _index == 3 ? QueueScreen(client: c) : const SizedBox.shrink(),
              _index == 4 ? CapacityScreen(client: c) : const SizedBox.shrink(),
              _index == 5 ? StatsScreen(client: c) : const SizedBox.shrink(),
            ],
          );
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
