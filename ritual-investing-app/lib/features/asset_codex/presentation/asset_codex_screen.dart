import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/api/state_status.dart';
import '../../../core/api/view_state.dart';
import '../../../core/bootstrap/member_bootstrap.dart';
import '../../../core/presentation/demo_disclosure.dart';
import '../../../core/presentation/minor_money.dart';
import '../../../core/presentation/server_time.dart';
import '../../rowan/application/controller.dart';
import '../../rowan/domain/model.dart';
import '../../rowan/presentation/rowan_counsel_panel.dart';
import '../../search/application/controller.dart' as search;
import '../../search/presentation/search_screen.dart';
import '../application/controller.dart';
import '../domain/model.dart';

class AssetCodexScreen extends StatelessWidget {
  const AssetCodexScreen({
    super.key,
    required this.controller,
    required this.rowanController,
    required this.personalization,
    this.searchController,
  });

  final AssetCodexController controller;
  final RowanController? rowanController;
  final MemberPersonalization personalization;
  final search.SearchController? searchController;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final value = controller.state.value;
      return Scaffold(
        key: const Key('asset-codex-screen'),
        appBar: AppBar(
          title: Text(value?.symbol ?? 'Asset Codex'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: DemoBadge(horizontalPadding: 9)),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              StateStatus(
                phase: controller.state.phase,
                onRetry: controller.load,
              ),
              if (value != null) ..._content(context, value),
            ],
          ),
        ),
      );
    },
  );

  List<Widget> _content(BuildContext context, AssetCodex value) => [
    Text(value.name, style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 4),
    Text(
      '${value.kind.name} · ${value.currency} · revision ${value.revisionId}',
    ),
    const SizedBox(height: 14),
    Text(
      _interpretationLabel(personalization),
      style: Theme.of(context).textTheme.labelLarge,
    ),
    const SizedBox(height: 6),
    Text(value.thesis, style: Theme.of(context).textTheme.bodyLarge),
    const SizedBox(height: 8),
    Text(
      'Why it appeared: ${value.appearanceReason}',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    const SizedBox(height: 14),
    Material(
      color: context.ritualColors.screenSoft,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.ritualColors.line),
      ),
      child: ExpansionTile(
        key: const Key('asset-evidence'),
        title: const Text('Observed evidence'),
        subtitle: Text(
          'Facts and sources · ${ServerTime.timestamp(value.demo.observedAt)}',
        ),
        children: [
          for (final evidence in value.detailedEvidence)
            ListTile(
              title: Text(evidence.factorLabel),
              subtitle: Text(
                '${evidence.summary}\nUncertainty: ${evidence.uncertainty}\n${evidence.publisher} · ${evidence.sourceTitle} · observed ${ServerTime.timestamp(evidence.observedAt)}',
              ),
            ),
          if (value.detailedEvidence.isEmpty)
            const ListTile(title: Text('No detailed evidence is published.')),
        ],
      ),
    ),
    const SizedBox(height: 18),
    Text('Demo metrics', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 6),
    for (final metric in value.metrics)
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(MinorMoney.usd(metric.priceMinor)),
        subtitle: Text(
          '${metric.sourceLabel} · observed ${ServerTime.timestamp(metric.observedAt)} · fictional price',
        ),
      ),
    const SizedBox(height: 10),
    Text(
      _riskLabel(personalization),
      style: Theme.of(context).textTheme.titleLarge,
    ),
    for (final risk in value.risks)
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.warning_amber_rounded),
        title: Text('${risk.title} · ${risk.severity.name}'),
        subtitle: Text(risk.detail),
      ),
    Text('Limitations: ${value.limitations}'),
    for (final limitation in value.demo.limitations) Text('• $limitation'),
    const SizedBox(height: 16),
    Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const Key('asset-save'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: controller.savePhase == AssetSavePhase.saving
                ? null
                : controller.toggleSaved,
            icon: Icon(value.saved ? Icons.bookmark : Icons.bookmark_border),
            label: Text(value.saved ? 'Saved' : 'Save research'),
          ),
        ),
        if (searchController != null) ...[
          const SizedBox(width: 10),
          OutlinedButton(
            key: const Key('asset-compare'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => unawaited(_selectComparisonPeer(context)),
            child: const Text('Compare'),
          ),
        ],
      ],
    ),
    if (controller.savePhase == AssetSavePhase.reconciled)
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('Save state was confirmed from the server.'),
      ),
    if (controller.comparisonState.phase != LoadPhase.idle) ...[
      const SizedBox(height: 18),
      StateStatus(phase: controller.comparisonState.phase, onRetry: () {}),
      if (controller.comparisonState.value case final comparison?)
        _ComparisonResults(comparison: comparison),
    ],
    const SizedBox(height: 12),
    if (rowanController != null)
      RowanCounselPanel(
        controller: rowanController!,
        request: RowanRequest.assetCodex(value.id),
        personalization: personalization,
      ),
    const SizedBox(height: 14),
    Text(
      DemoDisclosureCopy.marketScenario,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  ];

  Future<void> _selectComparisonPeer(BuildContext context) async {
    final activeSearch = searchController;
    if (activeSearch == null) return;
    final peerId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (routeContext) => SearchScreen(
          controller: activeSearch,
          onOpenAsset: (id) => Navigator.of(routeContext).pop(id),
        ),
      ),
    );
    if (peerId == null || !context.mounted) return;
    await controller.compareWith([peerId]);
  }
}

class _ComparisonResults extends StatelessWidget {
  const _ComparisonResults({required this.comparison});

  final AssetComparison comparison;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: 'Compared Demo research',
    child: Column(
      key: const Key('asset-comparison-results'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compared Demo research',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          'Server comparison · ${ServerTime.timestamp(comparison.comparedAt)}',
        ),
        for (final item in comparison.items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${item.asset.symbol} · ${item.asset.name}'),
            subtitle: Text(
              '${MinorMoney.usd(item.metric.priceMinor)} fictional price · ${item.riskCount} published risks\nRevision ${item.asset.revisionId} · observed ${ServerTime.timestamp(item.metric.observedAt)}',
            ),
          ),
      ],
    ),
  );
}

String _interpretationLabel(MemberPersonalization value) =>
    switch (value.ritualVoice) {
      MemberRitualVoice.practical => 'PRACTICAL INTERPRETATION',
      MemberRitualVoice.mystical => 'MYSTICAL INTERPRETATION',
      MemberRitualVoice.balanced ||
      MemberRitualVoice.unavailable => 'INTERPRETATION',
    };

String _riskLabel(MemberPersonalization value) => switch (value.riskFraming) {
  MemberRiskFraming.low => 'Risks · cautious framing',
  MemberRiskFraming.moderate => 'Risks · balanced framing',
  MemberRiskFraming.high => 'Risks · direct framing',
  MemberRiskFraming.unavailable => 'Material risks',
};
