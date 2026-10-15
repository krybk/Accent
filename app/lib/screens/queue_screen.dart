import 'package:accent_protocol/protocol.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/gateway_client.dart';

/// The order in which the control plane takes open plans, with the owner's
/// controls to move a plan up, down, to either end, or to hold and resume it.
class QueueScreen extends StatefulWidget {
  const QueueScreen({required this.client, super.key});

  final GatewayClient client;

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  PlaneQueue? _queue;
  Object? _loadError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final q = await widget.client.planeQueue();
      if (!mounted) return;
      setState(() {
        _queue = q;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_queue == null) {
        setState(() => _loadError = e);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeGatewayError(AppLocalizations.of(context), e),
            ),
          ),
        );
      }
    }
  }

  Future<void> _move(PlaneQueueEntry e, PlaneQueueVerb verb) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var reload = false;
    setState(() => _busy = true);
    try {
      final q = await widget.client.moveInQueue(e.id, verb);
      if (!mounted) return;
      setState(() => _queue = q);
    } catch (err) {
      if (!mounted) return;
      if (err is GatewayException && err.code == 'no_such_plan') {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.queueErrorNoSuchPlan)),
        );
        reload = true;
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(describeGatewayError(l10n, err))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (reload && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final queue = _queue;
    if (queue == null && _loadError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (queue == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(describeGatewayError(l10n, _loadError!)),
            TextButton(
              onPressed: () {
                setState(() => _loadError = null);
                _load();
              },
              child: Text(l10n.tryAgain),
            ),
          ],
        ),
      );
    }
    final entries = queue.entries;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          if (_busy) const LinearProgressIndicator(key: Key('queue-progress')),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.queueOrderNote,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.queueEmpty),
            )
          else
            for (var i = 0; i < entries.length; i++)
              _row(l10n, entries[i], last: i == entries.length - 1),
        ],
      ),
    );
  }

  Widget _row(AppLocalizations l10n, PlaneQueueEntry e, {required bool last}) {
    PopupMenuItem<PlaneQueueVerb> item(
      PlaneQueueVerb verb,
      String label,
      bool enabled,
    ) => PopupMenuItem<PlaneQueueVerb>(
      key: Key('queue-${verb.name}-${e.id}'),
      value: verb,
      enabled: enabled,
      child: Text(label),
    );
    return ListTile(
      key: Key('queue-row-${e.id}'),
      leading: Text('${e.position}'),
      title: Text('#${e.id} ${e.title}'),
      subtitle: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(e.status),
          if (e.held) Chip(label: Text(l10n.queueHeld)),
        ],
      ),
      trailing: PopupMenuButton<PlaneQueueVerb>(
        key: Key('queue-menu-${e.id}'),
        enabled: !_busy,
        onSelected: (v) => _move(e, v),
        itemBuilder: (_) => [
          item(PlaneQueueVerb.up, l10n.queueMoveUp, e.position > 1),
          item(PlaneQueueVerb.down, l10n.queueMoveDown, !last),
          item(PlaneQueueVerb.top, l10n.queueMoveTop, e.position > 1),
          item(PlaneQueueVerb.bottom, l10n.queueMoveBottom, !last),
          if (!e.held) item(PlaneQueueVerb.hold, l10n.queueHold, true),
          if (e.held) item(PlaneQueueVerb.resume, l10n.queueResume, true),
        ],
      ),
    );
  }
}
