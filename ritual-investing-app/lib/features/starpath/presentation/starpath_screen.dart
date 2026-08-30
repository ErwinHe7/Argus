import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../application/starpath_controller.dart';
import '../domain/starpath.dart';
import 'starpath_lesson_screen.dart';
import 'starpath_path.dart';
import 'starpath_recall.dart';

class StarpathScreen extends StatefulWidget {
  const StarpathScreen({super.key, required this.controller});

  final StarpathController controller;

  @override
  State<StarpathScreen> createState() => _StarpathScreenState();
}

class _StarpathScreenState extends State<StarpathScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.state.phase == StarpathViewPhase.idle) {
      widget.controller.load();
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.dark,
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final snapshot = state.snapshot;
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
                readOnly: state.isReadOnly,
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
    required this.readOnly,
    required this.stale,
  });

  final StarpathSnapshot snapshot;
  final StarpathController controller;
  final bool readOnly;
  final bool stale;

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  final GlobalKey _currentNodeKey = GlobalKey(
    debugLabel: 'starpath-current-node',
  );

  @override
  Widget build(BuildContext context) {
    if (widget.snapshot.availability == StarpathAvailability.notStarted) {
      return _StartPath(
        controller: widget.controller,
        readOnly: widget.readOnly,
      );
    }
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: widget.controller.load,
          child: CustomScrollView(
            key: const PageStorageKey('starpath-scroll'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 40),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Container(
                        key: const Key('starpath-stage'),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: const Color(0xFF09020D),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Column(
                          children: [
                            _PathHeader(
                              theme: widget.snapshot.theme,
                              nodes: widget.snapshot.nodes,
                              currentNode:
                                  widget.snapshot.currentNode ??
                                  (widget.snapshot.nodes.isEmpty
                                      ? null
                                      : widget.snapshot.nodes.last),
                              stale: widget.stale,
                            ),
                            if (widget.snapshot.recall case final recall?)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  0,
                                ),
                                child: StarpathRecallCard(
                                  recall: recall,
                                  controller: widget.controller,
                                  readOnly: widget.readOnly,
                                ),
                              ),
                            StarpathPath(
                              nodes: widget.snapshot.nodes,
                              readOnly: widget.readOnly,
                              currentNodeKey: _currentNodeKey,
                              onOpenNode: (node) => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (context) => StarpathLessonScreen(
                                    controller: widget.controller,
                                    node: node,
                                    readOnly: widget.readOnly,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.snapshot.currentNode != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
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
}

class _PathHeader extends StatelessWidget {
  const _PathHeader({
    required this.theme,
    required this.nodes,
    required this.currentNode,
    required this.stale,
  });

  final StarpathTheme? theme;
  final List<StarpathNode> nodes;
  final StarpathNode? currentNode;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final completed = nodes
        .where((node) => node.state == StarpathNodeState.completed)
        .length;
    final pathway = (currentNode?.pathwayOrdinal ?? 1).clamp(1, 4).toInt();
    const pathNames = [
      'Foundations',
      'Risk & resilience',
      'Evidence',
      'Verification',
    ];
    const roman = ['I', 'II', 'III', 'IV'];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF100414).withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Celestial Curriculum',
                      style: TextStyle(color: Color(0xFFCFBED2), fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Path ${roman[pathway - 1]} · ${pathNames[pathway - 1]}',
                      style: const TextStyle(
                        color: Color(0xFFFFF7FF),
                        fontFamily: 'LibreBaskerville',
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$completed / 8',
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
                value: completed / 8,
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
                    Text(
                      theme?.horoscopeFrame ?? 'Celestial imagery is used only to remember reviewed facts.',
                      style: const TextStyle(
                        color: Color(0xFFEADDEC),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Memory frame only · no prediction · no investment recommendation',
                      style: TextStyle(
                        color: Color(0xFFEDBC70),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (stale) ...[const SizedBox(height: 14), const _OfflineBanner()],
        ],
      ),
    );
  }
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

class _StartPath extends StatelessWidget {
  const _StartPath({required this.controller, required this.readOnly});
  final StarpathController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 42),
      Icon(Icons.stars, size: 74, color: context.ritualColors.gold),
      const SizedBox(height: 22),
      Text(
        'Walk the Stars',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.displaySmall,
      ),
      const SizedBox(height: 14),
      Text(
        'Eight short lessons use tarot and horoscope imagery to help you remember factual investment definitions.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 12),
      Text(
        'The imagery never predicts markets or tells you what to invest in.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 28),
      FilledButton(
        onPressed: readOnly ? null : controller.start,
        child: const Text('Begin Starpath'),
      ),
    ],
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
