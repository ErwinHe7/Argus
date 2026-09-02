import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/api/state_status.dart';
import '../../../core/bootstrap/member_bootstrap.dart';
import '../../../core/cache/read_cache.dart';
import '../../../core/presentation/server_time.dart';
import '../../rowan/application/controller.dart';
import '../application/daily_ritual_controller.dart';
import '../data/daily_ritual_repository.dart';
import '../data/leonidas_voice_preference_store.dart';
import '../domain/daily_ritual.dart';
import 'daily_ritual_stage_controller.dart';
import 'daily_ritual_stage_spec.dart';
import 'leonidas_ritual_sequence.dart';

class DailyRitualScreen extends StatefulWidget {
  const DailyRitualScreen({
    super.key,
    required this.onOpenCoven,
    this.onOpenStarpath,
    this.onToggleTheme,
    required this.controller,
    this.onOpenAsset,
    this.onOpenSearch,
    this.onOpenBriefings,
    this.rowanController,
    this.personalization = const MemberPersonalization(),
    this.useBundledArtwork = true,
    this.assetPackage,
    this.leonidasVoice = const PlatformLeonidasVoice(),
    this.cacheScope,
    this.voicePreferenceStore,
    this.monotonicNow,
    this.prepareExactMedia,
  });

  /// Retained for source compatibility; Daily Ritual no longer promotes Coven.
  final VoidCallback onOpenCoven;
  final VoidCallback? onOpenStarpath;
  final VoidCallback? onToggleTheme;
  final DailyRitualController controller;

  /// Retained for source compatibility; ideas are available inside Evidence.
  final ValueChanged<String>? onOpenAsset;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenBriefings;

  /// Retained for composition compatibility; the rebuilt ritual has one
  /// deterministic Leonidas close rather than a second counsel surface.
  final RowanController? rowanController;
  final MemberPersonalization personalization;
  final bool useBundledArtwork;
  final String? assetPackage;
  final LeonidasVoice leonidasVoice;
  final CacheScope? cacheScope;
  final LeonidasVoicePreferencePersistence? voicePreferenceStore;
  final DailyRitualMonotonicNow? monotonicNow;
  final DailyRitualMediaPreparer? prepareExactMedia;

  @override
  State<DailyRitualScreen> createState() => _DailyRitualScreenState();
}

class _DailyRitualScreenState extends State<DailyRitualScreen> {
  bool _immersiveOpen = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    final colors = context.ritualColors;
    final ritual = widget.controller.state.value;
    return ColoredBox(
      color: colors.page,
      child: CustomScrollView(
        key: const PageStorageKey('daily-ritual-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  children: [
                    Padding(
                      padding: DailyRitualStageSpec.pageInsets,
                      child: SizedBox(
                        height: 48,
                        child: _RitualHeader(
                          date: ritual?.date,
                          colors: colors,
                          onOpenSearch: widget.onOpenSearch,
                          onOpenBriefings: widget.onOpenBriefings,
                          onToggleTheme: widget.onToggleTheme,
                        ),
                      ),
                    ),
                    if (ritual != null) ...[
                      const SizedBox(height: 13),
                      const SizedBox(
                        height: 13,
                        child: Center(child: _DailySignalLabel()),
                      ),
                      const SizedBox(height: 3),
                    ] else
                      const SizedBox(height: 13),
                    Padding(
                      padding: DailyRitualStageSpec.pageInsets,
                      child: ritual == null
                          ? _RitualAuthorityStage(
                              phase: widget.controller.state.phase,
                              onRetry: widget.controller.load,
                            )
                          : ritual.state == DailyRitualState.assigned
                          ? _buildSequence(context, ritual, immersive: false)
                          : _RitualReturnInvitation(
                              ritual: ritual,
                              onPressed: () => _openImmersive(ritual),
                            ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSequence(
    BuildContext sequenceContext,
    DailyRitual ritual, {
    required bool immersive,
  }) => LeonidasRitualSequence(
    key: ValueKey(
      'leonidas-${ritual.assignmentId}-${immersive ? 'immersive' : 'entry'}',
    ),
    ritual: ritual,
    authorityController: immersive ? null : widget.controller,
    cacheScope: widget.cacheScope,
    voicePreferenceStore: widget.voicePreferenceStore,
    startImmediately: immersive,
    onStartRequested: immersive ? null : () => _openImmersive(ritual),
    onRevalidate: immersive ? widget.controller.revalidate : null,
    onReveal: () async {
      final result = await widget.controller.reveal(refreshHistory: false);
      return result?.disposition == RitualOperationDisposition.committed ||
          result?.disposition == RitualOperationDisposition.reconciledToTarget;
    },
    onComplete: immersive
        ? () async {
            final result = await widget.controller.complete(
              refreshHistory: false,
            );
            return result?.disposition ==
                    RitualOperationDisposition.committed ||
                result?.disposition ==
                    RitualOperationDisposition.reconciledToTarget;
          }
        : null,
    onShowEvidence: () {
      final snapshot = widget.controller.state.value;
      if (snapshot != null && snapshot.state == DailyRitualState.completed) {
        unawaited(_showEvidence(sequenceContext, snapshot));
      }
    },
    onOpenStarpath: widget.onOpenStarpath == null
        ? null
        : immersive
        ? _leaveForStarpath
        : widget.onOpenStarpath,
    voice: widget.leonidasVoice,
    monotonicNow: widget.monotonicNow,
    prepareExactMedia: widget.prepareExactMedia,
    useBundledArtwork: widget.useBundledArtwork,
    assetPackage: widget.assetPackage,
  );

  Future<void> _openImmersive(DailyRitual ritual) async {
    if (_immersiveOpen || !mounted) return;
    setState(() => _immersiveOpen = true);
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'daily-ritual-immersive'),
        builder: (routeContext) => ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final current = widget.controller.state.value ?? ritual;
            return _DailyRitualImmersivePage(
              onDismiss: () => Navigator.of(routeContext).maybePop(),
              child: _buildSequence(routeContext, current, immersive: true),
            );
          },
        ),
      ),
    );
    if (mounted) setState(() => _immersiveOpen = false);
  }

  void _leaveForStarpath() {
    if (!_immersiveOpen || !mounted) {
      widget.onOpenStarpath?.call();
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onOpenStarpath?.call();
    });
  }

  Future<void> _showEvidence(
    BuildContext context,
    DailyRitual completedSnapshot,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RitualEvidenceSheet(
      controller: widget.controller,
      snapshot: completedSnapshot,
    ),
  );
}

class _DailyRitualImmersivePage extends StatelessWidget {
  const _DailyRitualImmersivePage({
    required this.child,
    required this.onDismiss,
  });

  final Widget child;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(16) >= 24;
    final stage = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: DailyRitualStageSpec.baseStageSize.width,
        ),
        child: child,
      ),
    );
    return Material(
      key: const Key('daily-ritual-immersive'),
      color: context.ritualColors.page,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: 'Daily Ritual',
        onDismiss: onDismiss,
        child: SafeArea(
          child: largeText
              ? SingleChildScrollView(
                  key: const Key('daily-ritual-immersive-accessibility-scroll'),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: stage,
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: stage,
                ),
        ),
      ),
    );
  }
}

class _RitualReturnInvitation extends StatelessWidget {
  const _RitualReturnInvitation({
    required this.ritual,
    required this.onPressed,
  });

  final DailyRitual ritual;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final completed = ritual.state == DailyRitualState.completed;
    final colors = context.ritualColors;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: completed ? 'Today’s completed ritual' : 'Today’s revealed ritual',
      child: Container(
        key: const Key('daily-ritual-return-invitation'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: colors.screen,
          border: Border.all(color: colors.gold.withValues(alpha: 0.42)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              completed ? Icons.auto_awesome : Icons.brightness_5_outlined,
              color: colors.gold,
              size: 32,
            ),
            const SizedBox(height: 14),
            Text(
              completed
                  ? 'Today’s ritual is complete.'
                  : 'Your reading is ready.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              completed
                  ? 'Return to Leonidas to review your card and evidence.'
                  : 'Return to Leonidas when you are ready to finish.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                key: const Key('daily-ritual-return-action'),
                onPressed: onPressed,
                child: Text(
                  completed
                      ? 'Review today’s ritual'
                      : 'Continue your daily ritual',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RitualHeader extends StatelessWidget {
  const _RitualHeader({
    required this.date,
    required this.colors,
    required this.onOpenSearch,
    required this.onOpenBriefings,
    required this.onToggleTheme,
  });

  final DateTime? date;
  final RitualColors colors;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenBriefings;
  final VoidCallback? onToggleTheme;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Semantics(
        label: 'Ritual sigil',
        image: true,
        child: ExcludeSemantics(
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.gold),
            ),
            child: Icon(Icons.auto_awesome, color: colors.gold, size: 21),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          _formatDate(date),
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      if (onOpenSearch != null)
        _HeaderAction(
          key: const Key('ritual-search'),
          onPressed: onOpenSearch!,
          tooltip: 'Search the Asset Codex',
          icon: Icons.search,
        ),
      if (onOpenBriefings != null)
        _HeaderAction(
          key: const Key('ritual-briefings'),
          onPressed: onOpenBriefings!,
          tooltip: 'Open Ritual briefings',
          icon: Icons.auto_stories_outlined,
        ),
      if (onToggleTheme != null)
        _HeaderAction(
          key: const Key('theme-toggle'),
          onPressed: onToggleTheme!,
          tooltip: 'Switch theme',
          icon: Theme.of(context).brightness == Brightness.dark
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
        ),
    ],
  );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    super.key,
    required this.onPressed,
    required this.tooltip,
    required this.icon,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    padding: EdgeInsets.zero,
    icon: Icon(icon),
  );
}

class _DailySignalLabel extends StatelessWidget {
  const _DailySignalLabel();

  @override
  Widget build(BuildContext context) => Text(
    'YOUR DAILY SIGNAL',
    textAlign: TextAlign.center,
    style: TextStyle(
      color: context.ritualColors.gold,
      fontSize: 11,
      height: 1,
      fontWeight: FontWeight.w800,
      letterSpacing: 2,
    ),
  );
}

class _RitualAuthorityStage extends StatelessWidget {
  const _RitualAuthorityStage({required this.phase, required this.onRetry});

  final LoadPhase phase;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    key: DailyRitualStageSpec.stageKey,
    width: double.infinity,
    height: DailyRitualStageSpec.baseStageSize.height,
    decoration: BoxDecoration(
      color: const Color(0xFF120B17),
      borderRadius: BorderRadius.circular(DailyRitualStageSpec.radius),
      border: Border.all(
        color: context.ritualColors.gold.withValues(alpha: 0.36),
      ),
    ),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: StateStatus(phase: phase, onRetry: onRetry),
      ),
    ),
  );
}

class _RitualEvidenceSheet extends StatefulWidget {
  const _RitualEvidenceSheet({
    required this.controller,
    required this.snapshot,
  });

  final DailyRitualController controller;
  final DailyRitual snapshot;

  @override
  State<_RitualEvidenceSheet> createState() => _RitualEvidenceSheetState();
}

class _RitualEvidenceSheetState extends State<_RitualEvidenceSheet> {
  LoadPhase _phase = LoadPhase.loading;
  List<RitualEvidenceDetail> _details = const [];
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (mounted) setState(() => _phase = LoadPhase.loading);
    final result = await widget.controller.loadEvidenceSnapshot(
      widget.snapshot,
    );
    if (!mounted || generation != _generation) return;
    setState(() {
      _phase = result.phase;
      if (result.phase == LoadPhase.ready || result.phase == LoadPhase.empty) {
        _details = result.details;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Evidence for today’s reading',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                TextButton(
                  key: const Key('ritual-evidence-done'),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const Key('ritual-evidence-sheet'),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TrustSection(
                    title: 'Observation',
                    body:
                        'Observed ${ServerTime.timestamp(snapshot.demo.observedAt)} by ${snapshot.demo.sourceLabel}.',
                  ),
                  if (snapshot.serverEvaluatedAt case final evaluated?)
                    _TrustSection(
                      title: 'Freshness',
                      body:
                          'Server checked ${ServerTime.timestamp(evaluated)}${snapshot.validUntil == null ? '' : ' · valid through ${ServerTime.timestamp(snapshot.validUntil!)}'}.',
                    ),
                  _TrustSection(
                    title: 'Summary',
                    body: snapshot.evidence.isEmpty
                        ? snapshot.interpretation
                        : snapshot.evidence
                              .map((item) => item.summary)
                              .join('\n'),
                  ),
                  _TrustSection(
                    title: 'Uncertainty',
                    body: snapshot.evidence.isEmpty
                        ? 'No additional research claim is attached to this reading.'
                        : snapshot.evidence
                              .map((item) => item.uncertainty)
                              .join('\n'),
                  ),
                  _TrustSection(
                    title: 'Limitations',
                    body: snapshot.demo.limitations.isEmpty
                        ? 'Educational context only.'
                        : snapshot.demo.limitations.join('\n'),
                  ),
                  _TrustSection(
                    title: 'Risk context',
                    body: snapshot.rowan.riskFooter,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Supporting detail',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailState(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailState() {
    if (_phase == LoadPhase.loading) {
      return Semantics(
        label: 'Loading supporting evidence detail',
        child: const LinearProgressIndicator(),
      );
    }
    if (_phase == LoadPhase.ready) {
      return Column(
        children: [
          for (final detail in _details) _EvidenceDetailCard(detail: detail),
        ],
      );
    }
    if (_phase == LoadPhase.empty) {
      return const Text(
        'No additional detail is attached. The validated summary above remains available.',
      );
    }
    return Semantics(
      liveRegion: true,
      label: 'Supporting evidence detail unavailable',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Supporting detail is unavailable. The validated summary above remains available.',
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('ritual-evidence-retry'),
            onPressed: _load,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _TrustSection extends StatelessWidget {
  const _TrustSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(body),
      ],
    ),
  );
}

class _EvidenceDetailCard extends StatelessWidget {
  const _EvidenceDetailCard({required this.detail});

  final RitualEvidenceDetail detail;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.factorLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(detail.summary),
          const SizedBox(height: 4),
          Text('Uncertainty: ${detail.uncertainty}'),
          const SizedBox(height: 4),
          Text(
            '${detail.source.publisher} · ${detail.source.title} · observed ${ServerTime.timestamp(detail.observedAt)}',
          ),
        ],
      ),
    ),
  );
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
