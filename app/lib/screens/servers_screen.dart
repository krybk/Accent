import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../locale_controller.dart';
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
  const ServersScreen({
    required this.profiles,
    required this.localeController,
    super.key,
  });

  final ProfileRepository profiles;
  final LocaleController localeController;

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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.serversTitle),
        actions: [
          PopupMenuButton<String>(
            key: const Key('language-menu'),
            icon: const Icon(Icons.language),
            tooltip: l10n.languageMenuTooltip,
            onSelected: (value) => widget.localeController.setLocale(
              value == 'system' ? null : Locale(value),
            ),
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'system',
                checked: widget.localeController.locale == null,
                child: Text(l10n.languageSystem),
              ),
              for (final locale in AppLocalizations.supportedLocales)
                CheckedPopupMenuItem(
                  value: locale.languageCode,
                  checked:
                      widget.localeController.locale?.languageCode ==
                      locale.languageCode,
                  child: Text(lookupAppLocalizations(locale).languageName),
                ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<ServerProfile>>(
        future: _servers,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadFailed(onRetry: _reload, l10n: l10n);
          }
          final servers = snapshot.data ?? const <ServerProfile>[];
          if (servers.isEmpty) return _EmptyState(l10n: l10n);
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
        tooltip: l10n.addServerTooltip,
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
    final l10n = AppLocalizations.of(context);
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
        ready ? l10n.serverBootstrapped : l10n.serverNotBootstrapped,
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
  const _LoadFailed({required this.onRetry, required this.l10n});

  final VoidCallback onRetry;
  final AppLocalizations l10n;

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
              l10n.serversLoadFailed,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

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
              l10n.serversEmptyTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.serversEmptyHint,
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
