import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../application/starpath_controller.dart';
import '../application/starpath_narration_controller.dart';
import '../domain/investment_constellation.dart';
import '../domain/starpath.dart';
import '../domain/starpath_universe.dart';
import 'starpath_lesson_screen.dart';
import 'starpath_path.dart';
import 'starpath_recall.dart';
import 'starpath_trading_path.dart';

class StarpathScreen extends StatefulWidget {
  const StarpathScreen({
    super.key,
    required this.controller,
    this.narrationEngineFactory = createStarpathNarrationEngine,
  });

  final StarpathController controller;
  final StarpathNarrationEngineFactory narrationEngineFactory;

  @override
  State<StarpathScreen> createState() => _StarpathScreenState();
}

class _StarpathScreenState extends State<StarpathScreen> {
  late final StarpathNarrationPreference _narrationPreference;

  @override
  void initState() {
    super.initState();
    _narrationPreference = StarpathNarrationPreference();
    if (widget.controller.state.phase == StarpathViewPhase.idle) {
      widget.controller.load();
    }
  }

  @override
  void dispose() {
    _narrationPreference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.dark,
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final snapshot = state.snapshot;
        final preview = snapshot?.isDraftPreview ?? false;
        return Scaffold(
          backgroundColor: const Color(0xFF09020D),
          body: SafeArea(
            child: switch (state.phase) {
              StarpathViewPhase.idle || StarpathViewPhase.loading =>
                const Center(child: CircularProgressIndicator()),
              StarpathViewPhase.unavailable => _Status(
                icon: Icons.cloud_off_outlined,
                title: 'The stars are being redrawn',
                body: 'This reviewed curriculum is unavailable until a complete replacement is ready.',
                onRetry: widget.controller.load,
              ),
              StarpathViewPhase.forbidden => const _Status(
                icon: Icons.lock_outline,
                title: 'Starpath is not available',
                body: 'Your current release access does not include this path.',
              ),
              StarpathViewPhase.failure => _Status(
                icon: Icons.error_outline,
                title: 'Starpath could not load',
                body: 'No progress changed. Try the authoritative read again.',
                onRetry: widget.controller.load,
              ),
              _ when snapshot == null => _Status(
                icon: Icons.wifi_off,
                title: 'Connect to open Starpath',
                body: 'A reviewed lesson must load before it can be displayed.',
                onRetry: widget.controller.load,
              ),
              _ => _Content(
                snapshot: snapshot,
                controller: widget.controller,
                narrationEngineFactory: widget.narrationEngineFactory,
                narrationPreference: _narrationPreference,
                readOnly: state.isReadOnly,
                preview: preview,
                stale:
                    state.phase == StarpathViewPhase.cachedStale ||
                    state.phase == StarpathViewPhase.offlineReadOnly,
              ),
            },
          ),
        );
      },
    ),
  );
}

class _Content extends StatefulWidget {
  const _Content({
    required this.snapshot,
    required this.controller,
    required this.narrationEngineFactory,
    required this.narrationPreference,
    required this.readOnly,
    required this.preview,
    required this.stale,
  });

  final StarpathSnapshot snapshot;
  final StarpathController controller;
  final StarpathNarrationEngineFactory narrationEngineFactory;
  final StarpathNarrationPreference narrationPreference;
  final bool readOnly;
  final bool preview;
  final bool stale;

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  final GlobalKey _currentNodeKey = GlobalKey(
    debugLabel: 'starpath-current-node',
  );
  final ScrollController _scrollController = ScrollController();
  StarpathUniverseId _selectedUniverse = StarpathUniverseId.invest;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showingInvest = _selectedUniverse == StarpathUniverseId.invest;
    final investmentConstellations = projectInvestmentConstellations(
      widget.snapshot,
    );
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: widget.controller.load,
          child: CustomScrollView(
            key: const PageStorageKey('starpath-scroll'),
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        key: const Key('starpath-stage'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _UniverseHeader(
                            selected: _selectedUniverse,
                            onSelected: _selectUniverse,
                          ),
                          const SizedBox(height: 28),
                          if (showingInvest) ...[
                            _PathHeader(
                              constellations: investmentConstellations,
                              availability: widget.snapshot.availability,
                              onStart: widget.controller.start,
                              readOnly: widget.readOnly,
                              preview: widget.preview,
                              stale: widget.stale,
                            ),
                            const SizedBox(height: 8),
                            if (widget.preview) const _DraftPreviewBanner(),
                            if (widget.snapshot.recall case final recall?)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: StarpathRecallCard(
                                  recall: recall,
                                  controller: widget.controller,
                                  readOnly: widget.readOnly,
                                ),
                              ),
                            StarpathPath(
                              nodes: widget.snapshot.nodes,
                              readOnly: widget.readOnly,
                              preview: widget.preview,
                              currentNodeKey: _currentNodeKey,
                              onOpenNode: (node) {
                                final constellation =
                                    investmentConstellations[(node.nodeOrdinal -
                                            1) ~/
                                        2];
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (context) => StarpathLessonScreen(
                                      controller: widget.controller,
                                      constellation: constellation,
                                      narrationEngineFactory:
                                          widget.narrationEngineFactory,
                                      narrationPreference:
                                          widget.narrationPreference,
                                      readOnly: widget.readOnly,
                                      preview: widget.preview,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ] else
                            TradingStarpathPath(
                              universe: tradeStarpathUniverse,
                            ),
                          const SizedBox(height: 28),
                          const Text(
                            'Education only. No predictions or personalized recommendations.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF9F899F),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showingInvest && widget.snapshot.currentNode != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: FloatingActionButton(
                        key: const Key('starpath-return-current'),
                        tooltip: 'Return to current lesson',
                        heroTag: 'starpath-return-current',
                        backgroundColor: const Color(0xFFF7DCAE),
                        foregroundColor: const Color(0xFF2B132C),
                        onPressed: _returnToCurrent,
                        child: const Icon(Icons.auto_awesome),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _returnToCurrent() {
    final currentContext = _currentNodeKey.currentContext;
    if (currentContext == null) return;
    Scrollable.ensureVisible(
      currentContext,
      alignment: 0.5,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _selectUniverse(StarpathUniverseId universe) {
    if (universe == _selectedUniverse) return;
    setState(() => _selectedUniverse = universe);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }
}

class _UniverseHeader extends StatelessWidget {
  const _UniverseHeader({required this.selected, required this.onSelected});

  final StarpathUniverseId selected;
  final ValueChanged<StarpathUniverseId> onSelected;

  @override
  Widget build(BuildContext context) {
    final universe = starpathUniverseFor(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Starpath',
          style: TextStyle(
            color: Color(0xFFFFF7FF),
            fontFamily: 'LibreBaskerville',
            fontSize: 34,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<StarpathUniverseId>(
            key: const Key('starpath-universe-selector'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: StarpathUniverseId.invest,
                label: Text('Investment'),
              ),
              ButtonSegment(
                value: StarpathUniverseId.trade,
                label: Text('Trading'),
              ),
            ],
            selected: {selected},
            onSelectionChanged: (selection) => onSelected(selection.first),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          universe.introduction,
          key: Key('starpath-universe-${selected.name}-introduction'),
          style: const TextStyle(
            color: Color(0xFFFFF7FF),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          universe.topicSummary,
          style: const TextStyle(
            color: Color(0xFFBDA4C2),
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _PathHeader extends StatelessWidget {
  const _PathHeader({
    required this.constellations,
    required this.availability,
    required this.onStart,
    required this.readOnly,
    required this.preview,
    required this.stale,
  });

  final List<InvestmentConstellation> constellations;
  final StarpathAvailability availability;
  final Future<void> Function() onStart;
  final bool readOnly;
  final bool preview;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final completed = constellations
        .where(
          (constellation) =>
              constellation.state == InvestmentConstellationState.completed,
        )
        .length;
    final lessonCount = constellations.fold<int>(
      0,
      (total, constellation) => total + constellation.lessons.length,
    );
    final totalParts = constellations.length;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Investment path',
                      style: TextStyle(
                        color: Color(0xFFFFF7FF),
                        fontFamily: 'LibreBaskerville',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$totalParts constellations · $lessonCount short lessons · all open',
                      style: const TextStyle(
                        color: Color(0xFFCFBED2),
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$completed / $totalParts',
                    style: const TextStyle(
                      color: Color(0xFFFFF7FF),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFEDBC70),
                    size: 15,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: totalParts == 0 ? 0 : completed / totalParts,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFEDBC70)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFEDBC70),
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Open any constellation in any order. Progress only shows a suggested route.',
                      style: TextStyle(
                        color: Color(0xFFEADDEC),
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (availability == StarpathAvailability.notStarted) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('starpath-start-progress'),
              onPressed: readOnly ? null : onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start tracking progress'),
            ),
          ],
          if (stale) ...[const SizedBox(height: 14), const _OfflineBanner()],
        ],
      ),
    );
  }
}

class _DraftPreviewBanner extends StatelessWidget {
  const _DraftPreviewBanner();

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('starpath-draft-preview-banner'),
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.science_outlined, color: Color(0xFFF7DCAE), size: 19),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Preview copy · all lessons are open. Progress is paused until publication.',
            style: TextStyle(
              color: Color(0xFFFFF7FF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Offline copy · read only. Checks and progress are paused.',
        style: TextStyle(color: Colors.white),
      ),
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status({
    required this.icon,
    required this.title,
    required this.body,
    this.onRetry,
  });
  final IconData icon;
  final String title;
  final String body;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 58, color: context.ritualColors.gold),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(body, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    ),
  );
}
