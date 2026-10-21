import 'dart:math' as math;

import 'package:accent_protocol/protocol.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/gateway_client.dart';
import '../services/stalls_controller.dart';
import 'plan_dialogs.dart';
import 'send_to_plan.dart';

String stallStateLabel(
  AppLocalizations l10n,
  String code,
  Map<String, String> serverStates,
) {
  switch (code) {
    case 'working':
      return l10n.situationStateWorking;
    case 'short_of_slots':
      return l10n.situationStateShortOfSlots;
    case 'build_wait':
      return l10n.situationStateBuildWait;
    case 'draining':
      return l10n.situationStateDraining;
    case 'planning':
      return l10n.situationStatePlanning;
    case 'planning_wait':
      return l10n.situationStatePlanningWait;
    case 'queued':
      return l10n.situationStateQueued;
    case 'cooldown':
      return l10n.situationStateCooldown;
    case 'waiting_merge':
      return l10n.situationStateWaitingMerge;
    case 'waiting_owner':
      return l10n.situationStateWaitingOwner;
    case 'blocked':
      return l10n.situationStateBlocked;
    case 'budget':
      return l10n.situationStateBudget;
    case 'held':
      return l10n.situationStateHeld;
    case 'frozen':
      return l10n.situationStateFrozen;
    case 'idle':
      return l10n.situationStateIdle;
    case 'scheduler':
      return l10n.situationStateScheduler;
    case 'no_work':
      return l10n.situationStateNoWork;
    default:
      return serverStates[code] ?? code;
  }
}

String attentionKindLabel(AppLocalizations l10n, String kind) {
  switch (kind) {
    case 'question':
      return l10n.situationKindQuestion;
    case 'blocked':
      return l10n.situationKindBlocked;
    case 'budget':
      return l10n.situationKindBudget;
    case 'held':
      return l10n.situationKindHeld;
    case 'build_wait':
      return l10n.situationKindBuildWait;
    case 'disk':
      return l10n.situationKindDisk;
    case 'host_busy':
      return l10n.situationKindHostBusy;
    case 'service':
      return l10n.situationKindService;
    case 'provider':
      return l10n.situationKindProvider;
    default:
      return kind;
  }
}

MaterialColor stallStateColor(String code) {
  switch (code) {
    case 'working':
      return Colors.green;
    case 'short_of_slots':
    case 'build_wait':
    case 'draining':
    case 'planning':
    case 'planning_wait':
    case 'queued':
    case 'cooldown':
    case 'waiting_merge':
      return Colors.amber;
    case 'blocked':
    case 'budget':
    case 'waiting_owner':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

class SituationScreen extends StatefulWidget {
  const SituationScreen({
    required this.client,
    required this.controller,
    this.onOpenModels,
    super.key,
  });

  final GatewayClient client;
  final StallsController controller;
  final VoidCallback? onOpenModels;

  @override
  State<SituationScreen> createState() => _SituationScreenState();
}

class _SituationScreenState extends State<SituationScreen> {
  Future<void> _run(Future<Object?> Function() call) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await call();
    } catch (e) {
      if (!mounted) return;
      final text = e is GatewayException && e.code == 'no_such_plan'
          ? l10n.queueErrorNoSuchPlan
          : describeGatewayError(l10n, e);
      messenger.showSnackBar(SnackBar(content: Text(text)));
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.situationDone)));
    widget.controller.refresh();
  }

  Future<void> _reply(int issue, String title) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final text = await showPlanReplyDialog(context, title);
    if (text == null || !mounted) return;
    try {
      final result = await widget.client.postGuidance('$issue', text);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.sendToPlanSent(result.commentUrl))),
      );
      widget.controller.refresh();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(describeGuidanceError(l10n, e))),
      );
    }
  }

  Future<void> _addSteps(int issue) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final PlaneQueue q;
    try {
      q = await widget.client.planeQueue();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(describeGatewayError(l10n, e))),
      );
      return;
    }
    if (!mounted) return;
    PlaneQueueEntry? entry;
    for (final e in q.entries) {
      if (e.id == '$issue') {
        entry = e;
        break;
      }
    }
    if (entry == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.queueErrorNoSuchPlan)),
      );
      return;
    }
    final r = await showPlanBudgetDialog(context, entry);
    if (r == null || !mounted) return;
    await _run(() => widget.client.setPlanBudget('$issue', r.steps));
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _planMenu(PlaneStallPlan p) {
    final l10n = AppLocalizations.of(context);
    final issue = p.issue;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('situation-plan-priority'),
            title: Text(l10n.situationMenuPriority),
            onTap: () async {
              Navigator.pop(sheetContext);
              final r = await showPlanPriorityDialog(context);
              if (r == null || !mounted) return;
              await _run(
                () => widget.client.setPlanPriority('$issue', r.priority),
              );
            },
          ),
          if (p.state != 'held')
            ListTile(
              key: const Key('situation-plan-hold'),
              title: Text(l10n.situationMenuHold),
              onTap: () {
                Navigator.pop(sheetContext);
                _run(
                  () =>
                      widget.client.moveInQueue('$issue', PlaneQueueVerb.hold),
                );
              },
            )
          else
            ListTile(
              key: const Key('situation-plan-resume'),
              title: Text(l10n.situationMenuResume),
              onTap: () {
                Navigator.pop(sheetContext);
                _run(
                  () => widget.client.moveInQueue(
                    '$issue',
                    PlaneQueueVerb.resume,
                  ),
                );
              },
            ),
          ListTile(
            key: const Key('situation-plan-budget'),
            title: Text(l10n.situationMenuBudget),
            onTap: () {
              Navigator.pop(sheetContext);
              _addSteps(issue);
            },
          ),
          ListTile(
            key: const Key('situation-plan-write'),
            title: Text(l10n.situationMenuWrite),
            onTap: () {
              Navigator.pop(sheetContext);
              _reply(issue, '#$issue ${p.title}');
            },
          ),
        ],
      ),
    );
  }

  Widget? _attentionButton(AppLocalizations l10n, PlaneAttention a, int index) {
    final issue = a.issue;
    String? label;
    VoidCallback? onPressed;
    if ((a.kind == 'question' || a.kind == 'blocked') && issue != null) {
      label = l10n.situationActionReply;
      onPressed = () => _reply(issue, '#$issue ${a.title}');
    } else if (a.kind == 'budget' && issue != null) {
      label = l10n.situationActionAddSteps;
      onPressed = () => _addSteps(issue);
    } else if (a.kind == 'held' && issue != null) {
      label = l10n.situationActionResume;
      onPressed = () => _run(
        () => widget.client.moveInQueue('$issue', PlaneQueueVerb.resume),
      );
    } else if (a.kind == 'provider') {
      final open = widget.onOpenModels;
      if (open == null) return null;
      label = l10n.situationActionModels;
      onPressed = () => open();
    } else if (a.url != null) {
      final url = a.url!;
      label = l10n.situationActionOpen;
      onPressed = () => _open(url);
    }
    if (label == null) return null;
    return TextButton(
      key: Key('situation-attention-action-$index'),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  Widget _attentionCard(AppLocalizations l10n, PlaneAttention a, int index) {
    final button = _attentionButton(l10n, a, index);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              attentionKindLabel(l10n, a.kind),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (a.issue != null) Text('#${a.issue} ${a.title}'),
            if (a.detail.isNotEmpty) Text(a.detail),
            if (a.action.isNotEmpty) Text(a.action),
            if (button != null)
              Align(alignment: Alignment.centerRight, child: button),
          ],
        ),
      ),
    );
  }

  String _time(String? start) {
    final t = DateTime.tryParse(start ?? '')?.toLocal();
    if (t == null) return '?';
    final now = DateTime.now();
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    return DateFormat(sameDay ? 'HH:mm' : 'dd.MM HH:mm').format(t);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final s = widget.controller.stalls;
        final error = widget.controller.error;
        if (s == null) {
          if (error == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(describeGatewayError(l10n, error)),
                TextButton(
                  onPressed: widget.controller.refresh,
                  child: Text(l10n.tryAgain),
                ),
              ],
            ),
          );
        }
        final colorScheme = Theme.of(context).colorScheme;
        final header = Theme.of(context).textTheme.titleMedium;
        final sub = Theme.of(context).textTheme.titleSmall;
        return RefreshIndicator(
          onRefresh: widget.controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (error != null)
                Container(
                  key: const Key('situation-error-banner'),
                  color: colorScheme.errorContainer,
                  child: Text(l10n.situationStaleBanner),
                ),
              ..._attentionSection(l10n, s, header),
              ..._slotsSection(l10n, s),
              ..._plansSection(l10n, s, colorScheme, header),
              ..._waitingSection(l10n, s, colorScheme, header),
              ..._historySection(l10n, s, colorScheme, header, sub),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _attentionSection(
    AppLocalizations l10n,
    PlaneStalls s,
    TextStyle? header,
  ) {
    final out = <Widget>[Text(l10n.situationNeedsYou, style: header)];
    if (s.attention.isEmpty) {
      out.add(Text(l10n.situationNothingNeeded));
      return out;
    }
    List<Widget> cards(bool Function(String) test) => [
      for (var i = 0; i < s.attention.length; i++)
        if (test(s.attention[i].severity))
          _attentionCard(l10n, s.attention[i], i),
    ];
    out.addAll(cards((v) => v == 'act'));
    out.addAll(cards((v) => v == 'warn'));
    final other = cards((v) => v != 'act' && v != 'warn');
    if (other.isNotEmpty) {
      out.add(
        ExpansionTile(
          key: const Key('situation-info-toggle'),
          title: Text(l10n.situationInfoCount(other.length)),
          children: other,
        ),
      );
    }
    return out;
  }

  List<Widget> _slotsSection(AppLocalizations l10n, PlaneStalls s) {
    final t = DateTime.tryParse(s.at ?? '');
    return [
      Text(
        s.free > 0 && s.idleReason != null
            ? l10n.situationSlotsWithReason(
                s.running,
                s.slots,
                s.free,
                stallStateLabel(l10n, s.idleReason!, s.states),
              )
            : l10n.situationSlots(s.running, s.slots, s.free),
      ),
      if (t != null)
        Text(l10n.situationUpdated(DateFormat('HH:mm').format(t.toLocal()))),
    ];
  }

  List<Widget> _plansSection(
    AppLocalizations l10n,
    PlaneStalls s,
    ColorScheme colorScheme,
    TextStyle? header,
  ) {
    final out = <Widget>[Text(l10n.situationPlansTitle, style: header)];
    if (s.plans.isEmpty) {
      out.add(Text(l10n.situationNoPlans));
      return out;
    }
    final plans = [...s.plans]
      ..sort((a, b) {
        final pa = a.priority;
        final pb = b.priority;
        if (pa != pb) {
          if (pa == null) return 1;
          if (pb == null) return -1;
          return pa.compareTo(pb);
        }
        return a.issue.compareTo(b.issue);
      });
    for (final p in plans) {
      out.add(
        ListTile(
          key: Key('situation-plan-${p.issue}'),
          leading: p.priority == null
              ? null
              : Text(l10n.situationPriority(p.priority!)),
          title: Text('#${p.issue} ${p.title}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Chip(
                key: Key('situation-state-${p.issue}'),
                label: Text(
                  stallStateLabel(l10n, p.state, s.states),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                backgroundColor: stallStateColor(p.state).shade100,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              Text(
                '${p.detail.isNotEmpty ? '${p.detail}\n' : ''}'
                '${l10n.situationSessions(p.sessions)} · '
                '${l10n.situationForMin(p.forMin)}',
              ),
            ],
          ),
          onTap: () => _planMenu(p),
        ),
      );
    }
    return out;
  }

  List<Widget> _waitingSection(
    AppLocalizations l10n,
    PlaneStalls s,
    ColorScheme colorScheme,
    TextStyle? header,
  ) {
    final out = <Widget>[Text(l10n.situationBuildQueue, style: header)];
    if (s.waiting.isEmpty) {
      out.add(Text(l10n.situationNoBuildWait));
      return out;
    }
    for (var i = 0; i < s.waiting.length; i++) {
      final w = s.waiting[i];
      final long = w.waitedMin > 20;
      out.add(
        ListTile(
          key: long ? Key('situation-wait-long-$i') : Key('situation-wait-$i'),
          tileColor: long ? colorScheme.errorContainer : null,
          title: Text(
            (w.issue != null ? '#${w.issue} ' : '') +
                (w.item ?? w.step ?? w.kind ?? ''),
          ),
          subtitle: w.repo == null ? null : Text(w.repo!),
          trailing: Text(l10n.situationWaited(w.waitedMin)),
        ),
      );
    }
    return out;
  }

  List<Widget> _historySection(
    AppLocalizations l10n,
    PlaneStalls s,
    ColorScheme colorScheme,
    TextStyle? header,
    TextStyle? sub,
  ) {
    final sum = s.summary;
    final out = <Widget>[
      Text(l10n.situationHistory, style: header),
      SegmentedButton<int>(
        segments: [
          ButtonSegment(
            value: 24,
            label: Text(
              l10n.situationHours24,
              key: const Key('situation-hours-24'),
            ),
          ),
          ButtonSegment(
            value: 168,
            label: Text(
              l10n.situationHours168,
              key: const Key('situation-hours-168'),
            ),
          ),
        ],
        selected: {widget.controller.hours},
        onSelectionChanged: (v) => widget.controller.setHours(v.first),
      ),
      Text(
        sum.freeShare == null
            ? l10n.situationNoData
            : l10n.situationFreeShare((sum.freeShare! * 100).round()),
      ),
    ];
    if (sum.idleSlotHours.isNotEmpty) {
      final max = sum.idleSlotHours.values.reduce(math.max);
      out.add(Text(l10n.situationIdleSlotsTitle, style: sub));
      for (final e in sum.idleSlotHours.entries) {
        out.add(
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(stallStateLabel(l10n, e.key, s.states)),
              ),
              Expanded(
                flex: 3,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: max > 0 ? e.value / max : 0,
                  child: Container(height: 8, color: colorScheme.primary),
                ),
              ),
              Text(l10n.situationSlotHours(e.value.toStringAsFixed(1))),
            ],
          ),
        );
      }
    }
    if (sum.byPlan.isNotEmpty) {
      out.add(Text(l10n.situationByPlanTitle, style: sub));
      final issues = sum.byPlan.keys.toList()..sort();
      for (final issue in issues) {
        out.add(Text('#$issue'));
        out.add(
          SizedBox(
            height: 12,
            child: Row(
              children: [
                for (final e in sum.byPlan[issue]!.entries)
                  Expanded(
                    flex: math.max(1, (e.value * 10).round()),
                    child: Tooltip(
                      message: l10n.situationSegment(
                        stallStateLabel(l10n, e.key, s.states),
                        e.value.round(),
                      ),
                      child: Container(color: stallStateColor(e.key).shade400),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    }
    if (sum.longest.isNotEmpty) {
      out.add(Text(l10n.situationLongestTitle, style: sub));
      for (final iv in sum.longest) {
        final label = stallStateLabel(l10n, iv.state, s.states);
        final time = _time(iv.start);
        out.add(
          Text(
            iv.detail == null
                ? l10n.situationLongestNoDetail(
                    iv.issue,
                    label,
                    iv.minutes.round(),
                    time,
                  )
                : l10n.situationLongest(
                    iv.issue,
                    label,
                    iv.minutes.round(),
                    time,
                    iv.detail!,
                  ),
          ),
        );
      }
    }
    return out;
  }
}
