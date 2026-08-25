import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/presentation/demo_disclosure.dart';
import '../../../core/presentation/minor_money.dart';
import '../../intentions/application/intention_controller.dart';
import '../../portfolio/application/controller.dart';
import '../application/future_mirror_controller.dart';
import '../domain/model.dart';

class FutureMirrorScreen extends StatefulWidget {
  const FutureMirrorScreen({
    super.key,
    required this.portfolioId,
    required this.intentionId,
    required this.controller,
    required this.intentionController,
    required this.portfolioController,
    this.initialRunId,
    this.onOpenRun,
  });

  final String portfolioId;
  final String intentionId;
  final String? initialRunId;
  final ValueChanged<String>? onOpenRun;
  final FutureMirrorController controller;
  final IntentionController intentionController;
  final PortfolioController portfolioController;

  @override
  State<FutureMirrorScreen> createState() => _FutureMirrorScreenState();
}

class _FutureMirrorScreenState extends State<FutureMirrorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _contribution;
  late final TextEditingController _low;
  late final TextEditingController _mid;
  late final TextEditingController _high;
  bool _seeded = false;
  String? _gateMessage;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _contribution = TextEditingController();
    _low = TextEditingController();
    _mid = TextEditingController();
    _high = TextEditingController();
    _seedDefaults();
    unawaited(_hydrate());
  }

  Future<void> _hydrate() async {
    final portfolioFresh = await widget.portfolioController.refreshPortfolio(
      widget.portfolioId,
    );
    await widget.intentionController.openPortfolio(widget.portfolioId);
    await widget.intentionController.openIntention(widget.intentionId);
    final portfolio = widget.portfolioController.detailState.value?.portfolio;
    final intention = widget.intentionController.selected;
    if (!portfolioFresh ||
        portfolio == null ||
        portfolio.id != widget.portfolioId ||
        portfolio.ledgerWatermark < 1 ||
        intention == null ||
        intention.id != widget.intentionId ||
        intention.portfolioId != widget.portfolioId) {
      if (!mounted) return;
      setState(() {
        _gateMessage = 'Refresh authoritative Demo portfolio and goal data before opening Future Mirror.';
      });
      return;
    }
    await widget.controller.openIntention(
      intentionId: widget.intentionId,
      portfolioId: widget.portfolioId,
      ledgerWatermark: portfolio.ledgerWatermark,
    );
    final runId = widget.initialRunId;
    if (runId != null) await widget.controller.compareWith(runId);
  }

  void _seedDefaults() {
    if (_seeded) return;
    final draft = widget.controller.newDraft();
    _name.text = draft.name;
    _contribution.text = (draft.monthlyContributionMinor / 100).toStringAsFixed(
      2,
    );
    _low.text = (draft.lowReturnBps / 100).toString();
    _mid.text = (draft.midReturnBps / 100).toString();
    _high.text = (draft.highReturnBps / 100).toString();
    _seeded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _contribution.dispose();
    _low.dispose();
    _mid.dispose();
    _high.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      widget.intentionController,
      widget.portfolioController,
    ]),
    builder: (context, _) {
      final controller = widget.controller;
      final lockedReview =
          controller.phase == FutureMirrorPhase.review &&
          controller.fieldErrors.isEmpty;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Future Mirror'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: DemoBadge(horizontalPadding: 9)),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 44),
            children: [
              const _MirrorDisclosure(),
              if (_gateMessage case final gate?) ...[
                const SizedBox(height: 12),
                _MirrorNotice(text: gate),
              ],
              if (controller.message case final message?) ...[
                const SizedBox(height: 12),
                _MirrorNotice(text: message),
              ],
              if (controller.phase == FutureMirrorPhase.loading ||
                  controller.phase == FutureMirrorPhase.generating)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (controller.isStale && controller.current != null) ...[
                const SizedBox(height: 12),
                const _MirrorNotice(
                  text: 'New Demo activity exists. This saved scenario remains visible but is stale; review assumptions before regenerating.',
                ),
              ],
              if (controller.current case final result?) ...[
                const SizedBox(height: 20),
                _MirrorResult(title: 'Latest scenario', result: result),
                OutlinedButton(
                  key: const Key('future-mirror-refresh'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => unawaited(controller.refreshLatest()),
                  child: const Text('Refresh authoritative result'),
                ),
              ],
              if (controller.comparison case final comparison?) ...[
                const SizedBox(height: 16),
                _MirrorResult(title: 'Compared scenario', result: comparison),
              ],
              if (_gateMessage == null) ...[
                const SizedBox(height: 24),
                Text(
                  controller.current == null
                      ? 'Create a projection'
                      : 'Create a refreshed projection',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Risk framing and contribution rhythm set these editable defaults. The return range is a starting range, never a predicted return.',
                ),
                Text(
                  controller.defaults.sourceLabel,
                  key: const Key('future-mirror-personalization-source'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('future-mirror-name'),
                  controller: _name,
                  enabled: !lockedReview,
                  maxLength: 80,
                  decoration: _decoration(
                    'Scenario name',
                    controller.fieldErrors[FutureMirrorField.name],
                  ),
                ),
                TextField(
                  key: const Key('future-mirror-contribution'),
                  controller: _contribution,
                  enabled: !lockedReview,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _decoration(
                    'Monthly contribution (Demo USD)',
                    controller.fieldErrors[FutureMirrorField
                        .monthlyContribution],
                  ),
                ),
                Column(
                  children: [
                    TextField(
                      key: const Key('future-mirror-low'),
                      controller: _low,
                      enabled: !lockedReview,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: _decoration(
                        'Low return %',
                        controller.fieldErrors[FutureMirrorField.lowReturn],
                      ),
                    ),
                    TextField(
                      key: const Key('future-mirror-mid'),
                      controller: _mid,
                      enabled: !lockedReview,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: _decoration(
                        'Base return %',
                        controller.fieldErrors[FutureMirrorField.midReturn],
                      ),
                    ),
                    TextField(
                      key: const Key('future-mirror-high'),
                      controller: _high,
                      enabled: !lockedReview,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: _decoration(
                        'High return %',
                        controller.fieldErrors[FutureMirrorField.highReturn],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (lockedReview) ...[
                  const _MirrorNotice(
                    text: 'Review these illustrative assumptions. Generation is synchronous and only starts when you confirm.',
                  ),
                  FilledButton(
                    key: const Key('future-mirror-confirm'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => unawaited(controller.confirm()),
                    child: const Text('Generate Demo projection'),
                  ),
                ] else
                  FilledButton(
                    key: const Key('future-mirror-review'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _review,
                    child: const Text('Review assumptions'),
                  ),
              ],
              if (controller.phase == FutureMirrorPhase.reconciliationRequired)
                OutlinedButton(
                  key: const Key('future-mirror-retry-reconciliation'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => unawaited(controller.retryReconciliation()),
                  child: const Text('Refresh projection authority'),
                ),
              if (controller.phase == FutureMirrorPhase.restoredReview ||
                  controller.phase == FutureMirrorPhase.retryableFailure ||
                  controller.phase == FutureMirrorPhase.throttled) ...[
                OutlinedButton(
                  key: const Key('future-mirror-review-recovery'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: controller.reviewRestoredGeneration,
                  child: const Text('Review saved assumptions'),
                ),
                TextButton(
                  key: const Key('future-mirror-discard-recovery'),
                  onPressed: () =>
                      unawaited(controller.discardPendingGeneration()),
                  child: const Text('Discard saved recovery'),
                ),
              ],
              if (controller.history.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text(
                  'Recently seen',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(controller.historyLabel),
                for (final result in controller.history)
                  ListTile(
                    minTileHeight: 56,
                    contentPadding: EdgeInsets.zero,
                    title: Text(result.assumptions.name),
                    subtitle: Text(_timestamp(result.generatedAt)),
                    trailing: const Text('Compare'),
                    onTap: widget.onOpenRun == null
                        ? () => unawaited(controller.compareWith(result.id))
                        : () => widget.onOpenRun!(result.id),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );

  void _review() {
    final contribution = _usdMinorAllowZero(_contribution.text);
    final low = _percentBps(_low.text);
    final mid = _percentBps(_mid.text);
    final high = _percentBps(_high.text);
    if (contribution == null || low == null || mid == null || high == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter valid USD and percentage assumptions.'),
        ),
      );
      return;
    }
    widget.controller.prepare(
      FutureMirrorDraft(
        name: _name.text,
        monthlyContributionMinor: contribution,
        lowReturnBps: low,
        midReturnBps: mid,
        highReturnBps: high,
      ),
    );
  }
}

class _MirrorResult extends StatelessWidget {
  const _MirrorResult({required this.title, required this.result});
  final String title;
  final FutureMirror result;

  @override
  Widget build(BuildContext context) {
    final point = result.finalPoint;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            Text(result.assumptions.name),
            const SizedBox(height: 8),
            Text(
              '${_dateOnly(point.date)} illustrative range: '
              '${MinorMoney.usd(point.lowMinor)} – '
              '${MinorMoney.usd(point.highMinor)} USD',
            ),
            Text('Middle path ${MinorMoney.usd(point.midMinor)} USD'),
            const SizedBox(height: 8),
            Text(
              'Assumptions: ${MinorMoney.usd(result.assumptions.monthlyContributionMinor)} USD/month · '
              '${result.assumptions.lowReturnBps / 100}% / '
              '${result.assumptions.midReturnBps / 100}% / '
              '${result.assumptions.highReturnBps / 100}%',
            ),
            Text(
              'Generated ${_timestamp(result.generatedAt)} · model ${result.modelVersion} · '
              'Demo ledger watermark ${result.ledgerWatermark}',
            ),
            const SizedBox(height: 8),
            Text(result.uncertainty),
            Text(
              'Source: ${result.demo.sourceLabel} · observed '
              '${_timestamp(result.demo.observedAt)}',
            ),
            for (final limitation in result.demo.limitations)
              Text('Limitation: $limitation'),
            const Text(
              'Illustrative only. This is not advice, a forecast, or a promise of investment results.',
            ),
          ],
        ),
      ),
    );
  }
}

class _MirrorDisclosure extends StatelessWidget {
  const _MirrorDisclosure();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'DEMO · USD · provider-free. Future Mirror uses deterministic fictional ledger activity and editable assumptions. '
        'No banking or finance provider is connected; no real money moves. Results are not investment advice, forecasts, guarantees, or promises.',
      ),
    ),
  );
}

class _MirrorNotice extends StatelessWidget {
  const _MirrorNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      child: Padding(padding: const EdgeInsets.all(12), child: Text(text)),
    ),
  );
}

InputDecoration _decoration(String label, String? error) =>
    InputDecoration(labelText: label, errorText: error);

String _dateOnly(DateTime value) =>
    '${value.toUtc().year.toString().padLeft(4, '0')}-'
    '${value.toUtc().month.toString().padLeft(2, '0')}-'
    '${value.toUtc().day.toString().padLeft(2, '0')}';

String _timestamp(DateTime value) =>
    '${_dateOnly(value)} ${value.toUtc().hour.toString().padLeft(2, '0')}:'
    '${value.toUtc().minute.toString().padLeft(2, '0')} UTC';

int? _usdMinorAllowZero(String raw) {
  final value = raw.trim().replaceAll(',', '');
  final match = RegExp(r'^(\d{1,8})(?:\.(\d{1,2}))?$').firstMatch(value);
  if (match == null) return null;
  final whole = int.tryParse(match.group(1)!);
  final cents = int.tryParse((match.group(2) ?? '').padRight(2, '0')) ?? 0;
  if (whole == null) return null;
  final minor = whole * 100 + cents;
  return minor >= 0 && minor <= 1000000000 ? minor : null;
}

int? _percentBps(String raw) {
  final value = double.tryParse(raw.trim());
  if (value == null || !value.isFinite) return null;
  final scaled = value * 100;
  if (scaled.roundToDouble() != scaled || scaled < -5000 || scaled > 5000) {
    return null;
  }
  return scaled.round();
}
