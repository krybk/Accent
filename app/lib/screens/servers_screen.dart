import 'package:flutter/material.dart';

import '../models/server_profile.dart';
import '../services/profile_repository.dart';
import 'add_server_screen.dart';

/// The first screen: the list of servers this phone can reach.
///
/// The repository arrives as a parameter rather than from a global, so a test can
/// hand it one backed by an in-memory secret store and never touch the Android
/// Keystore. Deploying to a server and showing that progress belong to another
/// screen; this one lists what is stored and opens the form.
class ServersScreen extends StatefulWidget {
  const ServersScreen({required this.profiles, super.key});

  final ProfileRepository profiles;

  static const addButton = Key('servers-add');

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  late Future<List<ServerProfile>> _servers;

  @override
  void initState() {
    super.initState();
    _servers = widget.profiles.list();
  }

  void _reload() => setState(() {
    _servers = widget.profiles.list();
  });

  Future<void> _addServer() async {
    final created = await Navigator.of(context).push<NewServer>(
      MaterialPageRoute(
        builder: (_) => AddServerScreen(profiles: widget.profiles),
      ),
    );
    if (!mounted || created == null) return;
    // The form has already saved the profile, so the list only has to be read
    // again. The password and the provider key it also handed back stop here:
    // driving the bootstrap is the next screen's work, and this one deliberately
    // does not know how — which is also why neither value is kept.
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Servers')),
      body: FutureBuilder<List<ServerProfile>>(
        future: _servers,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadFailed(onRetry: _reload);
          }
          final servers = snapshot.data ?? const <ServerProfile>[];
          if (servers.isEmpty) return const _EmptyState();
          return ListView.separated(
            itemCount: servers.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _ServerRow(servers[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: ServersScreen.addButton,
        onPressed: _addServer,
        tooltip: 'Add a server',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// One server in the list.
///
/// Whether it is bootstrapped is on the row, not hidden a tap away: an
/// unfinished profile that looks identical to a working one is how someone ends
/// up debugging a chat screen that was never going to connect.
class _ServerRow extends StatelessWidget {
  const _ServerRow(this.profile);

  final ServerProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = profile.bootstrapped;
    return ListTile(
      leading: Icon(
        ready ? Icons.dns : Icons.dns_outlined,
        color: ready ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
      title: Text(profile.name),
      subtitle: Text('${profile.username}@${profile.host}:${profile.port}'),
      trailing: Text(
        ready ? 'Bootstrapped' : 'Not bootstrapped',
        style: theme.textTheme.labelMedium?.copyWith(
          color: ready
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Reading the store failed. Worth saying rather than showing an empty list,
/// which would look like "no servers" and invite adding a second copy of one
/// that is already there.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Could not read the stored servers',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dns_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No servers yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a server to deploy the stack onto it and start a chat.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
