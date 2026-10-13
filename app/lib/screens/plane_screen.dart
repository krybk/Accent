import 'dart:async';

import 'package:accent_protocol/protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/gateway_client.dart';

typedef _PlaneData = (PlanList, PlaneStatus, PlaneActionList);

class PlaneScreen extends StatefulWidget {
  const PlaneScreen({required this.client, super.key});

  static const argField = Key('plane-action-arg');
  static const runButton = Key('plane-action-run');

  final GatewayClient client;

  @override
  State<PlaneScreen> createState() => _PlaneScreenState();
}

class _PlaneScreenState extends State<PlaneScreen> {
  late Future<_PlaneData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PlaneData> _load() async {
    try {
      return await (
        widget.client.planePlans(),
        widget.client.planeStatus(),
        widget.client.planeActions(),
      ).wait;
    } on ParallelWaitError catch (e) {
      final errors = e.errors as (AsyncError?, AsyncError?, AsyncError?);
      final first = errors.$1 ?? errors.$2 ?? errors.$3;
      throw first?.error ?? e;
    }
  }

  Future<void> _reload() {
    final future = _load();
    setState(() => _future = future);
    return future.then<void>((_) {}, onError: (_) {});
  }

  String _localTime(BuildContext context, DateTime t) {
    final local = t.toLocal();
    final m = MaterialLocalizations.of(context);
    return '${m.formatShortDate(local)} ${m.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}';
  }

  Future<void> _run(PlaneAction a) async {
    final l10n = AppLocalizations.of(context);
    String? arg;
    if (a.args == 'int' || a.args == 'opt-int') {
      final required = a.args == 'int';
      final controller = TextEditingController();
      final text = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('!${a.token}'),
          content: TextField(
            key: PlaneScreen.argField,
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l10n.actionArgPrompt),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              key: PlaneScreen.runButton,
              onPressed: () {
                final value = controller.text.trim();
                if (required && value.isEmpty) return;
                Navigator.of(context).pop(value);
              },
              child: Text(l10n.actionRun),
            ),
          ],
        ),
      );
      if (text == null) return;
      arg = text.isEmpty ? null : text;
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    String title;
    Widget content;
    try {
      final result = await widget.client.runPlaneAction(
        PlaneActionRequest(token: a.token, arg: arg),
      );
      title = l10n.actionExitCode(result.exitCode);
      content = SingleChildScrollView(
        child: SelectableText(
          result.output,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      );
    } catch (error) {
      title = '!${a.token}';
      content = SingleChildScrollView(
        child: Text(describeGatewayError(l10n, error)),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: content,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<_PlaneData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(describeGatewayError(l10n, snapshot.error!)),
                TextButton(onPressed: _reload, child: Text(l10n.tryAgain)),
              ],
            ),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final (plans, status, actions) = data;
        final heading = Theme.of(context).textTheme.titleMedium;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            children: [
              Text(l10n.planeSectionPlans, style: heading),
              if (plans.plans.isEmpty)
                Text(l10n.planeNoPlans)
              else
                for (final plan in plans.plans)
                  ExpansionTile(
                    title: Text(plan.title),
                    subtitle: Text(plan.status),
                    initiallyExpanded: true,
                    children: [
                      for (final task in plan.tasks)
                        ListTile(
                          leading: Icon(
                            task.status == 'done'
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                          ),
                          title: Text(task.title),
                          subtitle: Text(
                            task.subtasksTotal > 0
                                ? '${task.target} · ${task.subtasksDone}/${task.subtasksTotal}'
                                : task.target,
                          ),
                        ),
                    ],
                  ),
              Text(l10n.planeSectionProviders, style: heading),
              for (final p in status.providers)
                ListTile(
                  title: Text(p.name),
                  subtitle: Wrap(
                    spacing: 8,
                    children: [
                      if (p.current) Chip(label: Text(l10n.providerCurrent)),
                      if (!p.hasKey) Text(l10n.providerNoKey),
                      if (p.coolingUntil != null)
                        Text(
                          l10n.providerCooling(
                            _localTime(context, p.coolingUntil!),
                            p.reason ?? '',
                          ),
                        ),
                    ],
                  ),
                ),
              Text(l10n.planeSectionServices, style: heading),
              for (final s in status.services)
                ListTile(
                  leading: s.healthy
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : Icon(
                          Icons.error,
                          color: Theme.of(context).colorScheme.error,
                        ),
                  title: Text(s.name),
                  subtitle: s.detail == null ? null : Text(s.detail!),
                ),
              if (status.paused.isNotEmpty) ...[
                Text(l10n.planeSectionPaused, style: heading),
                for (final p in status.paused)
                  ListTile(
                    title: Text('${p.tier} · ${p.model}'),
                    subtitle: Text(
                      '${p.use} · ${p.until == null ? l10n.pausedIndefinitely : _localTime(context, p.until!)} · ${p.reason}',
                    ),
                  ),
              ],
              Text(l10n.planeSectionActions, style: heading),
              Wrap(
                spacing: 8,
                children: [
                  for (final a in actions.actions)
                    Tooltip(
                      message: a.summary,
                      child: ActionChip(
                        label: Text('!${a.token}'),
                        onPressed: () => _run(a),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
