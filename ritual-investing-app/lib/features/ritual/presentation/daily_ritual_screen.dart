import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/api/state_status.dart';
import '../../../core/bootstrap/member_bootstrap.dart';
import '../../../core/presentation/demo_disclosure.dart';
import '../../../core/presentation/server_time.dart';
import '../application/daily_ritual_controller.dart';
import '../domain/daily_ritual.dart';
import '../../rowan/application/controller.dart';
import '../../rowan/domain/model.dart';
import '../../rowan/presentation/rowan_counsel_panel.dart';

class DailyRitualScreen extends StatelessWidget {
  const DailyRitualScreen({
    super.key,
    required this.onOpenCoven,
    this.onToggleTheme,
    required this.controller,
    this.onOpenAsset,
    this.onOpenSearch,
    this.onOpenBriefings,
    this.rowanController,
    this.personalization = const MemberPersonalization(),
    this.useBundledArtwork = true,
  });

  final VoidCallback onOpenCoven;
  final VoidCallback? onToggleTheme;
  final DailyRitualController controller;
  final ValueChanged<String>? onOpenAsset;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenBriefings;
  final RowanController? rowanController;
  final MemberPersonalization personalization;
  final bool useBundledArtwork;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = context.ritualColors;
    return ColoredBox(
      color: colors.page,
      child: CustomScrollView(
        key: const PageStorageKey('daily-ritual-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    _Sigil(colors: colors),
                    Expanded(
                      child: Text(
                        _formatDate(controller.state.value?.date),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (onOpenSearch != null)
                      IconButton(
                        key: const Key('ritual-search'),
                        onPressed: onOpenSearch,
                        tooltip: 'Search the Asset Codex',
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        icon: const Icon(Icons.search),
                      ),
                    if (onOpenBriefings != null)
                      IconButton(
                        key: const Key('ritual-briefings'),
                        onPressed: onOpenBriefings,
                        tooltip: 'Open Ritual briefings',
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        icon: const Icon(Icons.auto_stories_outlined),
                      ),
                    if (onToggleTheme != null)
                      IconButton(
                        key: const Key('theme-toggle'),
                        onPressed: onToggleTheme,
                        tooltip: 'Switch theme',
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        icon: Icon(
                          Theme.of(context).brightness == Brightness.dark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            sliver: SliverList.list(
              children: [
                StateStatus(
                  phase: controller.state.phase,
                  onRetry: controller.load,
                ),
                if (controller.state.value != null) ...[
                  Text(
                    'YOUR DAILY SIGNAL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CardStage(
                    colors: colors,
                    art: controller.state.value!.art,
                    useBundledArtwork: useBundledArtwork,
                  ),
                  const SizedBox(height: 18),
                  if (controller.state.value!.state ==
                      DailyRitualState.assigned) ...[
                    Text(
                      'Your ritual is ready. Reveal it when you have a quiet moment.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('ritual-reveal'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed:
                          controller.mutationPhase ==
                              RitualMutationPhase.committing
                          ? null
                          : controller.reveal,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Reveal today’s ritual'),
                    ),
                  ] else ...[
                    Text(
                      controller.state.value!.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Text(
                          controller.state.value!.interpretation,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontSize: 14, height: 1.4),
                        ),
                      ),
                    ),
                    if (_personalizationLabel(personalization)
                        case final label?) ...[
                      const SizedBox(height: 4),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                    ],
                    Center(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _showEvidence(context),
                        icon: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.positive,
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox(width: 8, height: 8),
                        ),
                        label: Text(controller.state.value!.marketLabel),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(color: colors.line),
                    const SizedBox(height: 8),
                    _Constellation(
                      colors: colors,
                      ideas: controller.state.value!.ideas,
                      onOpenAsset: onOpenAsset,
                    ),
                    const SizedBox(height: 16),
                    _CovenStrip(colors: colors, onTap: onOpenCoven),
                    const SizedBox(height: 14),
                    if (rowanController != null)
                      RowanCounselPanel(
                        controller: rowanController!,
                        request: RowanRequest.dailyRitual(
                          controller.state.value!.assignmentId,
                        ),
                        personalization: personalization,
                      )
                    else
                      _RowanCounsel(
                        colors: colors,
                        counsel: controller.state.value!.rowan,
                        useBundledArtwork: useBundledArtwork,
                      ),
                    if (controller.state.value!.state ==
                        DailyRitualState.revealed) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('ritual-complete'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed:
                            controller.mutationPhase ==
                                RitualMutationPhase.committing
                            ? null
                            : controller.complete,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Complete today’s ritual'),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      DemoDisclosureCopy.marketScenario,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.faint, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextButton.icon(
                    key: const Key('ritual-history'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => _showHistory(context),
                    icon: const Icon(Icons.history),
                    label: const Text('Ritual history'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEvidence(BuildContext context) async {
    final sheet = showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final ritual = controller.state.value;
          if (ritual == null) return const SizedBox.shrink();
          final colors = context.ritualColors;
          return FractionallySizedBox(
            heightFactor: 0.9,
            child: SafeArea(
              child: Padding(
                key: const Key('ritual-evidence-sheet'),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What moved beneath the reading',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Observed ${ServerTime.timestamp(ritual.demo.observedAt)} by ${ritual.demo.sourceLabel}. These are research cues, not predictions or instructions to buy.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      StateStatus(
                        phase: controller.evidenceState.phase,
                        onRetry: controller.loadEvidence,
                      ),
                      for (final evidence
                          in controller.evidenceState.value ??
                              const <RitualEvidenceDetail>[])
                        _EvidenceRow(
                          symbol: evidence.factorLabel,
                          factor:
                              '${evidence.summary}\nUncertainty: ${evidence.uncertainty}\n${evidence.source.publisher} · ${evidence.source.title} · observed ${ServerTime.timestamp(evidence.observedAt)}',
                        ),
                      if (rowanController != null) ...[
                        const SizedBox(height: 8),
                        RowanCounselPanel(
                          controller: rowanController!,
                          request: RowanRequest.evidence(ritual.assignmentId),
                          personalization: personalization,
                        ),
                      ],
                      const SizedBox(height: 16),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.goldSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text.rich(
                            TextSpan(
                              style: TextStyle(color: colors.ink, height: 1.4),
                              children: [
                                TextSpan(text: ritual.guidance),
                                TextSpan(text: '\n${ritual.rowan.riskFooter}'),
                                for (final limitation
                                    in ritual.demo.limitations)
                                  TextSpan(text: '\n$limitation'),
                                if (ritual.evidence.isNotEmpty)
                                  TextSpan(
                                    text:
                                        '\n${ritual.evidence.first.uncertainty}',
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (ritual.ideas.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          'Ideas shown in this reading',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        for (final idea in ritual.ideas)
                          _EvidenceRow(
                            symbol: idea.symbol,
                            factor:
                                '${idea.appearanceReason}. ${idea.riskSummary}',
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    unawaited(controller.loadEvidence());
    await sheet;
  }

  Future<void> _showHistory(BuildContext context) async {
    final sheet = showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final state = controller.historyState;
          return FractionallySizedBox(
            heightFactor: 0.9,
            child: SafeArea(
              child: Padding(
                key: const Key('ritual-history-sheet'),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ritual history',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Lifecycle states come from the server. Demo readings never imply market completion.',
                      ),
                      const SizedBox(height: 14),
                      StateStatus(
                        phase: state.phase,
                        onRetry: controller.loadHistory,
                      ),
                      for (final item
                          in state.value?.items ?? const <RitualHistoryEntry>[])
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          minTileHeight: 56,
                          leading: const DemoBadge(horizontalPadding: 7),
                          title: Text(item.title),
                          subtitle: Text(
                            '${_historyDate(item.date)} · ${_modeLabel(item.mode)} · ${_stateLabel(item.state)}\n${item.demo.sourceLabel} · observed ${ServerTime.timestamp(item.demo.observedAt)}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    unawaited(controller.loadHistory());
    await sheet;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Daily ritual';
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[value.month - 1]} ${value.day}';
  }
}

String _historyDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

String _modeLabel(DailyRitualMode value) => switch (value) {
  DailyRitualMode.tarot => 'Tarot',
  DailyRitualMode.astrology => 'Astrology',
  DailyRitualMode.unknown => 'Mode unavailable',
};

String _stateLabel(DailyRitualState value) => switch (value) {
  DailyRitualState.assigned => 'Assigned',
  DailyRitualState.revealed => 'Revealed',
  DailyRitualState.completed => 'Completed',
  DailyRitualState.unknown => 'State unavailable',
};

class _Sigil extends StatelessWidget {
  const _Sigil({required this.colors});

  final RitualColors colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ritual sigil',
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.gold),
        ),
        child: Icon(Icons.auto_awesome, color: colors.gold, size: 21),
      ),
    );
  }
}

class _CardStage extends StatelessWidget {
  const _CardStage({
    required this.colors,
    required this.art,
    required this.useBundledArtwork,
  });

  final RitualColors colors;
  final RitualArt art;
  final bool useBundledArtwork;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: 296,
      child: OverflowBox(
        minWidth: viewportWidth,
        maxWidth: viewportWidth,
        minHeight: 296,
        maxHeight: 296,
        child: Container(
          height: 296,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.page,
                Color.lerp(colors.primarySoft, colors.screenSoft, 0.55)!,
                colors.screenSoft,
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 22,
                right: 22,
                child: Divider(color: colors.gold.withValues(alpha: 0.62)),
              ),
              Semantics(
                image: true,
                label: art.alt,
                child: Container(
                  width: 170,
                  height: 255,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.gold.withValues(alpha: 0.78),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 8,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: art.key == 'the_compass' && useBundledArtwork
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.asset(
                            'assets/images/the-compass.png',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          Icons.image_not_supported_outlined,
                          color: colors.gold,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Constellation extends StatelessWidget {
  const _Constellation({
    required this.colors,
    required this.ideas,
    required this.onOpenAsset,
  });

  final RitualColors colors;
  final List<RitualIdea> ideas;
  final ValueChanged<String>? onOpenAsset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'THE CARD’S CONSTELLATION',
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            Text(
              '${ideas.length} of 5 aligned',
              style: TextStyle(color: colors.faint, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 14,
              left: 42,
              right: 42,
              child: Divider(color: colors.gold.withValues(alpha: 0.6)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final (index, idea) in ideas.take(5).indexed)
                  _AssetStar(
                    symbol: idea.symbol,
                    change: idea.changeLabel,
                    note: idea.appearanceReason,
                    selected: index == 1,
                    onTap: onOpenAsset == null
                        ? null
                        : () => onOpenAsset!(idea.assetId),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _AssetStar extends StatelessWidget {
  const _AssetStar({
    required this.symbol,
    this.change,
    required this.note,
    this.selected = false,
    this.onTap,
  });

  final String symbol;
  final String? change;
  final String note;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ritualColors;
    return Expanded(
      child: Semantics(
        button: true,
        label: [symbol, ?change, note, 'demo asset idea'].join(', '),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : colors.screen,
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : colors.gold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  symbol,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontSize: 18),
                ),
                if (change != null)
                  Text(
                    change!,
                    style: TextStyle(
                      color: colors.positive,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  note,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.faint, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _personalizationLabel(MemberPersonalization value) {
  if (value.ritualVoice == MemberRitualVoice.unavailable &&
      value.explanationDepth == MemberExplanationDepth.unavailable) {
    return null;
  }
  final voice = switch (value.ritualVoice) {
    MemberRitualVoice.practical => 'Practical reading',
    MemberRitualVoice.mystical => 'Mystical reading',
    MemberRitualVoice.balanced => 'Balanced reading',
    MemberRitualVoice.unavailable => 'Interpretation',
  };
  final depth = switch (value.explanationDepth) {
    MemberExplanationDepth.beginner => 'more context',
    MemberExplanationDepth.guided => 'guided context',
    MemberExplanationDepth.advanced => 'concise context',
    MemberExplanationDepth.unavailable => 'standard context',
  };
  return '$voice · $depth · server-personalized';
}

class _CovenStrip extends StatelessWidget {
  const _CovenStrip({required this.colors, required this.onTap});

  final RitualColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open Founders’ Coven, demo companies with women at the helm',
      child: Material(
        color: colors.coven,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.gold),
                  ),
                  child: Icon(Icons.nightlight_round, color: colors.gold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Founders’ Coven',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'LibreBaskerville',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Explore demo companies with women at the helm',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.76),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, color: colors.gold),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RowanCounsel extends StatelessWidget {
  const _RowanCounsel({
    required this.colors,
    required this.counsel,
    required this.useBundledArtwork,
  });

  final RitualColors colors;
  final RitualCounsel counsel;
  final bool useBundledArtwork;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.gold),
          ),
          child: useBundledArtwork
              ? ClipOval(
                  child: Image.asset(
                    'assets/images/persona-triptych.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                )
              : Icon(Icons.auto_awesome, color: colors.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontSize: 13),
              children: [
                TextSpan(
                  text: 'Rowan, your counsel: ',
                  style: TextStyle(
                    color: colors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: '“${counsel.body}”'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.symbol, required this.factor});

  final String symbol;
  final String factor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Text(
              symbol,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(factor, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
