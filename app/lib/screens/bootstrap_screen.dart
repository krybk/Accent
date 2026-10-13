import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/ssh_bootstrap.dart';
import 'add_server_screen.dart';

typedef BootstrapRunner = Stream<BootstrapEvent> Function(NewServer server);

enum _StageState { pending, running, succeeded, failed }

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({required this.server, required this.run, super.key});

  static const closeButton = Key('bootstrap-close');
  static const finishButton = Key('bootstrap-finish');

  static Key stageKey(BootstrapStage s) => Key('bootstrap-stage-${s.name}');

  final NewServer server;
  final BootstrapRunner run;

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  final Map<BootstrapStage, _StageState> _states = {
    for (final s in BootstrapStage.values) s: _StageState.pending,
  };
  final Map<BootstrapStage, String> _details = {};
  final Map<BootstrapStage, String> _reasons = {};
  final Map<BootstrapStage, String> _stderrs = {};

  StreamSubscription<BootstrapEvent>? _subscription;
  BootstrapStage? _current;
  BootstrapEvent? _last;
  bool _running = true;
  bool _succeeded = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget
        .run(widget.server)
        .listen(_onEvent, onError: _onError, onDone: _onDone);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onEvent(BootstrapEvent event) {
    setState(() {
      _last = event;
      switch (event) {
        case BootstrapStageStarted():
          _current = event.stage;
          _states[event.stage] = _StageState.running;
        case BootstrapStageSucceeded():
          _states[event.stage] = _StageState.succeeded;
          final detail = event.detail;
          if (detail != null) _details[event.stage] = detail;
        case BootstrapStageFailed():
          _states[event.stage] = _StageState.failed;
          _reasons[event.stage] = event.reason;
          _stderrs[event.stage] = event.stderr;
      }
    });
  }

  void _onError(Object error) {
    setState(() {
      final stage = _current ?? BootstrapStage.connect;
      _states[stage] = _StageState.failed;
      _reasons[stage] = '$error';
      _last = BootstrapStageFailed(stage, '$error');
      _running = false;
      _succeeded = false;
    });
  }

  void _onDone() {
    if (!_running) return;
    final last = _last;
    setState(() {
      _running = false;
      _succeeded =
          last is BootstrapStageSucceeded &&
          last.stage == BootstrapStage.storeCredentials;
    });
  }

  String _stageName(AppLocalizations l10n, BootstrapStage s) => switch (s) {
    BootstrapStage.connect => l10n.bootstrapStageConnect,
    BootstrapStage.installKey => l10n.bootstrapStageInstallKey,
    BootstrapStage.keyOnlyConnect => l10n.bootstrapStageKeyOnlyConnect,
    BootstrapStage.installDocker => l10n.bootstrapStageInstallDocker,
    BootstrapStage.checkout => l10n.bootstrapStageCheckout,
    BootstrapStage.writeEnvironment => l10n.bootstrapStageWriteEnvironment,
    BootstrapStage.startStack => l10n.bootstrapStageStartStack,
    BootstrapStage.awaitHealth => l10n.bootstrapStageAwaitHealth,
    BootstrapStage.readCertificate => l10n.bootstrapStageReadCertificate,
    BootstrapStage.storeCredentials => l10n.bootstrapStageStoreCredentials,
  };

  Widget _entry(AppLocalizations l10n, ColorScheme colors, BootstrapStage s) {
    final key = BootstrapScreen.stageKey(s);
    final title = Text(_stageName(l10n, s));
    switch (_states[s]!) {
      case _StageState.pending:
        return ListTile(
          key: key,
          leading: const Icon(Icons.radio_button_unchecked),
          title: title,
        );
      case _StageState.running:
        return ListTile(
          key: key,
          leading: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: title,
        );
      case _StageState.succeeded:
        final detail = _details[s];
        return ListTile(
          key: key,
          leading: const Icon(Icons.check_circle),
          title: title,
          subtitle: detail == null ? null : Text(detail),
        );
      case _StageState.failed:
        final leading = Icon(Icons.error, color: colors.error);
        final subtitle = Text(_reasons[s] ?? '');
        final stderr = _stderrs[s] ?? '';
        if (stderr.isEmpty) {
          return ListTile(
            key: key,
            leading: leading,
            title: title,
            subtitle: subtitle,
          );
        }
        return ExpansionTile(
          key: key,
          leading: leading,
          title: title,
          subtitle: subtitle,
          children: [
            SelectableText(
              stderr,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_running,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.bootstrapTitle),
          automaticallyImplyLeading: !_running,
        ),
        body: ListView(
          children: [
            for (final s in BootstrapStage.values) _entry(l10n, colors, s),
            if (!_running && _succeeded) ...[
              Text(l10n.bootstrapDone),
              FilledButton(
                key: BootstrapScreen.finishButton,
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.bootstrapFinish),
              ),
            ],
            if (!_running && !_succeeded) ...[
              Text(l10n.bootstrapFailed),
              FilledButton(
                key: BootstrapScreen.closeButton,
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.bootstrapClose),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
