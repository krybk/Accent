import 'package:accent_protocol/protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

const _maxReplyLength = 8000;

Future<({int? priority})?> showPlanPriorityDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<({int? priority})>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.queuePriorityTitle),
      children: [
        for (var n = 1; n <= 5; n++)
          SimpleDialogOption(
            key: Key('queue-priority-option-$n'),
            onPressed: () => Navigator.pop(ctx, (priority: n)),
            child: Text('$n'),
          ),
        SimpleDialogOption(
          key: const Key('queue-priority-option-default'),
          onPressed: () => Navigator.pop(ctx, (priority: null)),
          child: Text(l10n.queueDefault),
        ),
      ],
    ),
  );
}

Future<({int? steps})?> showPlanBudgetDialog(
  BuildContext context,
  PlaneQueueEntry entry,
) {
  return showDialog<({int? steps})>(
    context: context,
    builder: (_) => _BudgetDialog(entry: entry),
  );
}

Future<String?> showPlanReplyDialog(BuildContext context, String title) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReplyDialog(title: title),
  );
}

class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({required this.entry});

  final PlaneQueueEntry entry;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.entry.stepLimit}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = int.tryParse(_controller.text);
    final valid = value != null && value >= 1 && value <= 100000;
    return AlertDialog(
      title: Text(l10n.queueBudgetTitle),
      content: TextField(
        key: const Key('queue-budget-field'),
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          helperText: l10n.queueBudgetHelp(widget.entry.stepsSpent ?? 0),
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          key: const Key('queue-budget-default'),
          onPressed: () => Navigator.pop(context, (steps: null)),
          child: Text(l10n.queueDefault),
        ),
        FilledButton(
          key: const Key('queue-budget-save'),
          onPressed: valid
              ? () => Navigator.pop(context, (steps: value))
              : null,
          child: Text(l10n.queueBudgetSave),
        ),
      ],
    );
  }
}

class _ReplyDialog extends StatefulWidget {
  const _ReplyDialog({required this.title});

  final String title;

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = _controller.text;
    final valid = text.trim().isNotEmpty && text.length <= _maxReplyLength;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('situation-reply-field'),
        controller: _controller,
        minLines: 3,
        maxLines: 8,
        keyboardType: TextInputType.multiline,
        decoration: InputDecoration(labelText: l10n.sendToPlanText),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('situation-reply-send'),
          onPressed: valid
              ? () => Navigator.pop(context, _controller.text)
              : null,
          child: Text(l10n.sendToPlanSend),
        ),
      ],
    );
  }
}
