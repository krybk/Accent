import 'package:accent_protocol/protocol.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/gateway_client.dart';

/// The owner's progress table over `GET /v1/plane/progress`: one row per open
/// plan with what is done, what comes next and the forecast.
///
/// The plane computes the table on every request, so the refresh button (and
/// pulling the table down) is the refresh; the screen does not poll.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({required this.client, super.key});

  final GatewayClient client;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

/// How many of a slice's open tasks the "Next" cell names before an ellipsis.
const _maxTasksShown = 4;

class _ProgressScreenState extends State<ProgressScreen> {
  PlaneProgress? _data;
  Object? _loadError;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final d = await widget.client.planeProgress();
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
    } finally {
      if (mounted) setState(() => _loading = false);
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
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    Widget cell(String text, {TextStyle? style, Key? key}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(text, key: key, style: style),
    );
    final head = theme.textTheme.labelLarge;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _updated(l10n, locale, d.generatedAt),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      key: const Key('progress-refresh'),
                      tooltip: l10n.progressRefresh,
                      icon: const Icon(Icons.refresh),
                      onPressed: _load,
                    ),
            ],
          ),
          if (d.plans.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(l10n.progressEmpty)),
            )
          else
            Table(
              key: const Key('progress-table'),
              columnWidths: const {
                0: FlexColumnWidth(1.1),
                1: FlexColumnWidth(0.9),
                2: FlexColumnWidth(1.7),
                3: FlexColumnWidth(1.4),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.top,
              border: TableBorder(
                horizontalInside: BorderSide(color: theme.dividerColor),
                bottom: BorderSide(color: theme.dividerColor),
              ),
              children: [
                TableRow(
                  children: [
                    cell(l10n.progressColProject, style: head),
                    cell(l10n.progressColDone, style: head),
                    cell(l10n.progressColNext, style: head),
                    cell(l10n.progressColForecast, style: head),
                  ],
                ),
                for (final p in d.plans)
                  TableRow(
                    key: ValueKey('progress-${p.issue}'),
                    children: [
                      cell(
                        '${p.project.isEmpty ? p.title : p.project} #${p.issue}',
                        style: theme.textTheme.titleSmall,
                      ),
                      cell(_done(l10n, locale, p)),
                      cell(_next(l10n, p)),
                      cell(
                        _forecast(l10n, locale, p),
                        key: Key('progress-forecast-${p.issue}'),
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

String _updated(AppLocalizations l10n, String locale, String? at) {
  final t = at == null ? null : DateTime.tryParse(at);
  return t == null
      ? ''
      : l10n.progressUpdated(DateFormat.Hm(locale).format(t.toLocal()));
}

String _number(String locale, double v, int digits) =>
    (NumberFormat.decimalPattern(locale)
          ..minimumFractionDigits = 0
          ..maximumFractionDigits = digits)
        .format(v);

String _done(AppLocalizations l10n, String locale, PlaneProgressPlan p) {
  final pct = p.requirementsPct;
  return pct == null
      ? l10n.valueUnknown
      : l10n.progressDone(_number(locale, pct, 0));
}

String _next(AppLocalizations l10n, PlaneProgressPlan p) {
  if (p.tasksTotal == 0) return l10n.progressNoTasks;
  final lines = <String>[
    p.tasksLeft == 0
        ? l10n.progressAllDone(p.tasksTotal)
        : l10n.progressTasksLeft(p.tasksLeft, p.tasksTotal),
    for (final t in p.left.take(_maxTasksShown))
      t.title.isEmpty ? t.id : '${t.id} ${t.title}',
    if (p.left.length > _maxTasksShown) '…',
    if (p.sessions > 0) l10n.progressAgents(p.sessions),
  ];
  return lines.join('\n');
}

String _forecast(AppLocalizations l10n, String locale, PlaneProgressPlan p) {
  switch (p.phase) {
    case 'paused':
      return l10n.progressPaused;
    case 'blocked':
      return l10n.progressBlocked(p.blocked ?? p.detail ?? '');
    case 'waiting_owner':
      return l10n.progressWaitingOwner(
        p.blocked ??
            (p.questions.isEmpty ? (p.detail ?? '') : p.questions.first.text),
      );
  }
  final parts = <String>[
    if (p.etaSliceHours != null)
      l10n.progressEtaSlice(
        _number(locale, p.etaSliceHours!, p.etaSliceHours! < 1 ? 1 : 0),
      ),
    if (p.etaIssueDays != null)
      l10n.progressEtaIssue(
        _number(locale, p.etaIssueDays!, 1),
        (p.etaIssueDays! * 10).round() / 10,
      ),
  ];
  return parts.isEmpty ? l10n.progressEtaUnknown : parts.join(', ');
}
