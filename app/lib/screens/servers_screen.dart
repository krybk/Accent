import 'package:flutter/material.dart';

/// The first screen: the list of servers this phone can reach.
///
/// Only the shell for now — the empty state and the entry point for adding a
/// server. Profile storage and the SSH bootstrap land next; keeping this screen
/// free of that logic is what lets it be tested without a server.
class ServersScreen extends StatelessWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Servers')),
      body: const _EmptyState(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Deliberately inert until the add-server flow exists. A button that
          // opens a half-built form is worse than one that says so.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Adding a server is not ready yet')),
          );
        },
        tooltip: 'Add a server',
        child: const Icon(Icons.add),
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
