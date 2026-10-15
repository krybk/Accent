import 'package:accent_protocol/protocol.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/gateway_client.dart';
import 'usage_screen.dart';

/// A number on the Load and Stats screens: '—' when the server did not send it,
/// one decimal for a double, plain digits for an int.
String formatValue(AppLocalizations l10n, num? v) =>
    v == null ? l10n.valueUnknown : (v is int ? '$v' : v.toStringAsFixed(1));

/// A token count, as on the usage screen, or '—' when absent.
String formatTokenValue(AppLocalizations l10n, int? v) =>
    v == null ? l10n.valueUnknown : formatTokens(v);

/// How loaded the server and its hosts are, and what the plans in flight and
/// those waiting to start are expected to add.
class CapacityScreen extends StatefulWidget {
  const CapacityScreen({required this.client, super.key});

  final GatewayClient client;

  @override
  State<CapacityScreen> createState() => _CapacityScreenState();
}

class _CapacityScreenState extends State<CapacityScreen> {
  PlaneCapacity? _data;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.client.planeCapacity();
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
    Widget header(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
    Widget line(String text) => ListTile(dense: true, title: Text(text));
    final reason = d.reason;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ListTile(
            key: const Key('capacity-slots'),
            title: Text(l10n.capacitySlots(f(d.slotsNow), f(d.running))),
            subtitle: reason == null ? null : Text(reason),
          ),
          header(l10n.capacityServer),
          line(l10n.capacityCpu(f(d.cpuPct))),
          line(
            l10n.capacityMemory(
              f(d.memPct),
              f(d.memAvailableMb),
              f(d.memTotalMb),
            ),
          ),
          line(l10n.capacityDisk(f(d.diskPct), f(d.diskFreeGb))),
          line(l10n.capacityCores(f(d.cores))),
          for (final h in d.hosts)
            ListTile(
              key: Key('capacity-host-${h.name}'),
              title: Text(h.name),
              subtitle: Text(
                h.ok == false
                    ? l10n.capacityHostUnreachable
                    : [
                        l10n.capacityCpu(f(h.cpuPct)),
                        l10n.capacityMemory(
                          f(h.memPct),
                          l10n.valueUnknown,
                          l10n.valueUnknown,
                        ),
                        l10n.capacityDisk(f(h.diskPct), f(h.diskFreeGb)),
                      ].join('\n'),
              ),
            ),
          if (d.windows.isNotEmpty || d.subscriptionReason != null) ...[
            header(l10n.capacitySubscription),
            for (final w in d.windows)
              line(
                l10n.capacityWindow(
                  w.name,
                  formatTokenValue(l10n, w.used),
                  f(w.usedPct),
                  formatTokenValue(l10n, w.burnPerHour),
                ),
              ),
            if (d.subscriptionReason != null) line(d.subscriptionReason!),
          ],
          if (d.slotsByPlan.isNotEmpty) ...[
            header(l10n.capacitySlotsByPlan),
            for (final s in d.slotsByPlan)
              line(l10n.capacityPlanSlots(s.planId, f(s.slots))),
          ],
          if (d.planned.isNotEmpty) ...[
            header(l10n.capacityPlanned),
            for (final p in d.planned)
              line(
                l10n.capacityPlannedRow(
                  p.planId,
                  p.repo,
                  '${p.width}',
                  f(p.memMb),
                  f(p.cores),
                ),
              ),
            line(
              l10n.capacityPlannedTotal(
                f(d.plannedSessions),
                f(d.plannedMemMb),
                f(d.plannedCores),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
