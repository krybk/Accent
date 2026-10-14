import 'package:accent_protocol/protocol.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/gateway_client.dart';

String formatTokens(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '${(n / 1000000).toStringAsFixed(2)}M';
}

String describeModelError(AppLocalizations l10n, Object error) {
  if (error is GatewayException) {
    if (error.statusCode == 409 && error.code == 'last_model') {
      return l10n.modelErrorLastModel;
    }
    if (error.statusCode == 404 && error.code == 'no_such_tier') {
      return l10n.modelErrorNoSuchTier;
    }
  }
  return describeGatewayError(l10n, error);
}

enum UsageWindow { today, last7d, last30d }

UsageBucket _bucket(
  UsageWindow window,
  UsageBucket today,
  UsageBucket last7d,
  UsageBucket last30d,
) => switch (window) {
  UsageWindow.today => today,
  UsageWindow.last7d => last7d,
  UsageWindow.last30d => last30d,
};

class UsageScreen extends StatefulWidget {
  const UsageScreen({required this.client, super.key});

  final GatewayClient client;

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  late Future<PlaneUsage> _usage;
  UsageWindow _window = UsageWindow.last7d;
  PlaneModelSwitchList? _models;
  Object? _modelsError;
  String? _busyTier;

  @override
  void initState() {
    super.initState();
    _usage = widget.client.planeUsage();
    _loadModels();
  }

  Future<void> _loadModels() async {
    try {
      final list = await widget.client.planeModels();
      if (!mounted) return;
      setState(() {
        _models = list;
        _modelsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _modelsError = e);
    }
  }

  Future<void> _toggle(PlaneModelSwitch m, bool on) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!on) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.modelDisableTitle(m.tier)),
          content: Text(l10n.modelDisableBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.modelDisableConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busyTier = m.tier);
    try {
      final list = await (on
          ? widget.client.enableModel(m.tier)
          : widget.client.disableModel(m.tier));
      if (!mounted) return;
      setState(() => _models = list);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(describeModelError(l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _busyTier = null);
    }
  }

  String _switchSubtitle(
    BuildContext context,
    AppLocalizations l10n,
    PlaneModelSwitch m,
  ) {
    if (m.enabled) return m.model;
    final off = m.standIn == null
        ? l10n.modelOffNoStandIn
        : l10n.modelOff(m.standIn!, m.standInModel ?? m.standIn!);
    var text = '${m.model}\n$off';
    final until = m.until;
    if (until != null) {
      final ml = MaterialLocalizations.of(context);
      final local = until.toLocal();
      final localTime =
          '${ml.formatShortDate(local)} ${ml.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}';
      text += ' · ${l10n.modelOffUntil(localTime)}';
    }
    return text;
  }

  Future<void> _reload() {
    final next = widget.client.planeUsage();
    setState(() => _usage = next);
    _loadModels();
    return next.then<void>((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._modelsSection(context, l10n),
          FutureBuilder<PlaneUsage>(
            future: _usage,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(describeGatewayError(l10n, snapshot.error!)),
                    TextButton(onPressed: _reload, child: Text(l10n.tryAgain)),
                  ],
                );
              }
              final usage = snapshot.data;
              if (usage == null) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _content(context, l10n, usage),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _modelsSection(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return [
      Text(l10n.modelsTitle, style: theme.textTheme.titleMedium),
      if (_modelsError != null)
        Text(describeModelError(l10n, _modelsError!))
      else if (_models == null)
        const LinearProgressIndicator()
      else
        for (final m in _models!.models)
          SwitchListTile(
            key: Key('model-switch-${m.tier}'),
            title: Text(m.tier),
            subtitle: Text(_switchSubtitle(context, l10n, m)),
            value: m.enabled,
            onChanged: _busyTier != null ? null : (on) => _toggle(m, on),
            secondary: _busyTier == m.tier
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
    ];
  }

  List<Widget> _content(
    BuildContext context,
    AppLocalizations l10n,
    PlaneUsage usage,
  ) {
    final theme = Theme.of(context);
    final m = MaterialLocalizations.of(context);
    final local = usage.generatedAt.toLocal();
    final localTime =
        '${m.formatShortDate(local)} ${m.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}';
    return [
      SegmentedButton<UsageWindow>(
        segments: [
          ButtonSegment(value: UsageWindow.today, label: Text(l10n.usageToday)),
          ButtonSegment(value: UsageWindow.last7d, label: Text(l10n.usage7d)),
          ButtonSegment(value: UsageWindow.last30d, label: Text(l10n.usage30d)),
        ],
        selected: {_window},
        onSelectionChanged: (s) => setState(() => _window = s.first),
      ),
      for (final model in usage.models) _modelCard(theme, l10n, model),
      Text(l10n.usageRoles, style: theme.textTheme.titleMedium),
      for (final role in usage.roles) ..._roleTile(l10n, role),
      Text(l10n.usageGeneratedAt(localTime)),
    ];
  }

  Widget _modelCard(ThemeData theme, AppLocalizations l10n, ModelUsage model) {
    final b = _bucket(_window, model.today, model.last7d, model.last30d);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(model.model, style: theme.textTheme.titleMedium),
          Text('${l10n.usageSteps}: ${b.steps}'),
          Text('${l10n.usageCost}: \$${b.costUsd.toStringAsFixed(2)}'),
          Text('${l10n.usageInput}: ${formatTokens(b.inputTokens)}'),
          Text('${l10n.usageOutput}: ${formatTokens(b.outputTokens)}'),
          Text('${l10n.usageCacheRead}: ${formatTokens(b.cacheReadTokens)}'),
          Text('${l10n.usageCacheWrite}: ${formatTokens(b.cacheWriteTokens)}'),
          if (b.untrackedSteps > 0)
            Text(
              l10n.usageUntracked(b.untrackedSteps),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _roleTile(AppLocalizations l10n, RoleUsage role) {
    final b = _bucket(_window, role.today, role.last7d, role.last30d);
    if (b.steps <= 0) return const [];
    final tokens = formatTokens(
      b.inputTokens + b.outputTokens + b.cacheReadTokens + b.cacheWriteTokens,
    );
    return [
      ListTile(
        title: Text(role.role == 'chat' ? l10n.usageRoleChat : role.role),
        subtitle: Text(
          '${role.model} · ${l10n.usageSteps} ${b.steps} · \$${b.costUsd.toStringAsFixed(2)} · $tokens',
        ),
      ),
    ];
  }
}
