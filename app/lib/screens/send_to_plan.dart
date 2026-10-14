import 'package:accent_protocol/protocol.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/gateway_client.dart';

const _maxGuidanceLength = 8000;

String describeGuidanceError(AppLocalizations l10n, Object error) {
  if (error is GatewayException) {
    if (error.statusCode == 400 && error.code == 'looks_like_credential') {
      return l10n.sendToPlanCredential;
    }
    if (error.statusCode == 404 && error.code == 'no_such_plan') {
      return l10n.sendToPlanNoSuchPlan;
    }
    if (error.statusCode == 502 && error.code == 'comment_failed') {
      return l10n.sendToPlanCommentFailed;
    }
  }
  return describeGatewayError(l10n, error);
}

Future<void> sendToPlan(
  BuildContext context,
  GatewayClient client,
  String text,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  PlanList plans;
  try {
    plans = await client.planePlans();
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(describeGatewayError(l10n, e))),
    );
    return;
  }
  if (plans.plans.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.sendToPlanNoPlan)));
    return;
  }
  if (!context.mounted) return;

  final choice = await showDialog<(String, String)>(
    context: context,
    builder: (_) => _SendToPlanDialog(plans: plans.plans, text: text),
  );
  if (choice == null) return;

  try {
    final result = await client.postGuidance(choice.$1, choice.$2);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.sendToPlanSent(result.commentUrl))),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(describeGuidanceError(l10n, e))),
    );
  }
}

class _SendToPlanDialog extends StatefulWidget {
  const _SendToPlanDialog({required this.plans, required this.text});

  final List<PlanSummary> plans;
  final String text;

  @override
  State<_SendToPlanDialog> createState() => _SendToPlanDialogState();
}

class _SendToPlanDialogState extends State<_SendToPlanDialog> {
  late final TextEditingController _controller;
  late String _planId;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text)
      ..addListener(() => setState(() {}));
    _planId = widget.plans.first.id;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trimmed = _controller.text.trim();
    final canSend = trimmed.isNotEmpty && trimmed.length <= _maxGuidanceLength;
    return AlertDialog(
      title: Text(l10n.sendToPlanTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            key: const Key('guidance-plan'),
            initialValue: _planId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.sendToPlanPlan),
            items: [
              for (final plan in widget.plans)
                DropdownMenuItem(
                  value: plan.id,
                  child: Text(plan.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _planId = v);
            },
          ),
          TextField(
            key: const Key('guidance-text'),
            controller: _controller,
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(labelText: l10n.sendToPlanText),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('guidance-send'),
          onPressed: canSend
              ? () => Navigator.of(context).pop((_planId, trimmed))
              : null,
          child: Text(l10n.sendToPlanSend),
        ),
      ],
    );
  }
}
