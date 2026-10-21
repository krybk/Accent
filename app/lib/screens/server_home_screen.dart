import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/server_profile.dart';
import '../services/gateway_client.dart';
import '../services/stalls_controller.dart';
import 'capacity_screen.dart';
import 'chat_screen.dart';
import 'plane_screen.dart';
import 'queue_screen.dart';
import 'situation_screen.dart';
import 'stats_screen.dart';
import 'usage_screen.dart';

/// The home of one bootstrapped server: the situation, the plane, the token
/// usage, the chat and the plan queue, each a destination of the bottom bar.
///
/// The gateway client is obtained once, from the factory, and closed when the
/// screen goes away. Plane, Usage and Queue are built only while selected, so a
/// hidden tab does not poll the gateway. The chat is kept alive, so its
/// conversation and a running answer survive a switch to another tab. The
/// Situation screen is likewise built only while selected, but its controller
/// keeps polling `/v1/plane/stalls` (every 45 s) while the server home is open,
/// so the badge on its destination stays current.
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
  StallsController? _stalls;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _client = widget.clients(widget.profile).then((c) {
      // A client that arrives after the screen has gone is closed at once.
      if (!mounted) c.close();
      if (mounted) setState(() => _stalls = StallsController(c)..start());
      return _obtained = c;
    });
  }

  @override
  void dispose() {
    _stalls?.dispose();
    _obtained?.close();
    super.dispose();
  }

  // Situation, Plane, Usage, Chat, Queue, Load, Stats -- the order of the IndexedStack below.
  List<(IconData, String)> _destinations(AppLocalizations l10n) => [
    (Icons.notifications_active_outlined, l10n.navSituation),
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
              _index == 0 && _stalls != null
                  ? SituationScreen(
                      client: c,
                      controller: _stalls!,
                      onOpenModels: () => setState(() => _index = 2),
                    )
                  : const SizedBox.shrink(),
              _index == 1 ? PlaneScreen(client: c) : const SizedBox.shrink(),
              _index == 2 ? UsageScreen(client: c) : const SizedBox.shrink(),
              ChatScreen(client: c),
              _index == 4 ? QueueScreen(client: c) : const SizedBox.shrink(),
              _index == 5 ? CapacityScreen(client: c) : const SizedBox.shrink(),
              _index == 6 ? StatsScreen(client: c) : const SizedBox.shrink(),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final (i, (icon, label)) in _destinations(l10n).indexed)
            NavigationDestination(
              icon: i != 0 || _stalls == null
                  ? Icon(icon)
                  : ListenableBuilder(
                      listenable: _stalls!,
                      builder: (_, _) {
                        final n = _stalls!.stalls?.actCount ?? 0;
                        return Badge.count(
                          key: const Key('situation-act-badge'),
                          count: n,
                          isLabelVisible: n > 0,
                          child: Icon(icon),
                        );
                      },
                    ),
              label: label,
            ),
        ],
      ),
    );
  }
}
