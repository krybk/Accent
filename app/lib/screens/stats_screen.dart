import 'package:accent_protocol/protocol.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/gateway_client.dart';
import 'capacity_screen.dart';

/// How long plans and their steps take, and when the plans in flight are
/// expected to finish.
class StatsScreen extends StatefulWidget {
  const StatsScreen({required this.client, super.key});

  final GatewayClient client;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  PlaneStats? _data;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.client.planeStats();
      if (!mounted) return;
      setState(() {
        _data = d;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_data == null) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = _data;
    if (d == null && _loadError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (d == null) {
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
    String f(num? v) => formatValue(l10n, v);
    String t(int? v) => formatTokenValue(l10n, v);
    Widget header(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
    final days = d.days;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (d.forecast.isNotEmpty) ...[
            header(l10n.statsForecast),
            for (final p in d.forecast)
              ListTile(
                key: Key('stats-forecast-${p.planId}'),
                title: Text('#${p.planId} ${p.title}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.progressPct != null)
                      LinearProgressIndicator(
                        value: (p.progressPct! / 100).clamp(0.0, 1.0),
                      ),
                    Text(l10n.statsProgress(f(p.progressPct))),
                    Text(l10n.statsTasksLeft(f(p.tasksLeft), f(p.tasksTotal))),
                    Text(l10n.statsEta(f(p.etaHours))),
                  ],
                ),
              ),
          ],
          if (d.groups.isNotEmpty) ...[
            header(l10n.statsByKind),
            for (final g in d.groups)
              ListTile(
                title: Text('${g.sphere} · ${g.kind}'),
                subtitle: Text(
                  [
                    l10n.statsGroupRow(
                      f(g.tasks),
                      f(g.taskWallMinP50),
                      f(g.taskWorkMinP50),
                      t(g.opusTokensP50),
                      t(g.sonnetTokensP50),
                    ),
                    l10n.statsGroupResources(
                      f(g.sessionMemMbP90),
                      f(g.sessionCoresP75),
                      f(g.gatesMinP50),
                    ),
                  ].join('\n'),
                ),
              ),
          ],
          if (d.steps.isNotEmpty) ...[
            header(l10n.statsBySteps),
            for (final s in d.steps)
              ListTile(
                title: Text('${s.step} · ${s.model}'),
                subtitle: Text(
                  l10n.statsStepRow(
                    f(s.n),
                    f(s.minP50),
                    f(s.minP90),
                    f(s.shareOfTimePct),
                  ),
                ),
              ),
          ],
          if (days != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.statsWindow('$days')),
            ),
        ],
      ),
    );
  }
}
