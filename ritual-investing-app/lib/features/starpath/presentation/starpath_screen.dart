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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final state = widget.controller.state;
      final snapshot = state.snapshot;
      return Scaffold(
        body: SafeArea(
          child: switch (state.phase) {
            StarpathViewPhase.idle || StarpathViewPhase.loading => const Center(
              child: CircularProgressIndicator(),
            ),
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
  );
}

class _Content extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (snapshot.availability == StarpathAvailability.notStarted) {
      return _StartPath(controller: controller, readOnly: readOnly);
    }
    final theme = snapshot.theme;
    return RefreshIndicator(
      onRefresh: controller.load,
      child: CustomScrollView(
        key: const PageStorageKey('starpath-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: _PathHeader(theme: theme, stale: stale),
          ),
          if (snapshot.recall case final recall?)
            SliverToBoxAdapter(
              child: StarpathRecallCard(
                recall: recall,
                controller: controller,
                readOnly: readOnly,
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverToBoxAdapter(
              child: StarpathPath(
                nodes: snapshot.nodes,
                readOnly: readOnly,
                onOpenNode: (node) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => StarpathLessonScreen(
                      controller: controller,
                      node: node,
                      readOnly: readOnly,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PathHeader extends StatelessWidget {
  const _PathHeader({required this.theme, required this.stale});
  final StarpathTheme? theme;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final colors = context.ritualColors;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 22),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.coven, const Color(0xFF27134D)],
        ),
        border: Border.all(color: colors.gold.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WALK THE STARS',
            style: TextStyle(
              color: colors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            theme?.title ?? 'Starpath',
            style: Theme.of(context).textTheme.displaySmall
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            theme?.horoscopeFrame ??
                'Celestial imagery is used only to remember reviewed facts.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
          ),
          const SizedBox(height: 10),
          Text(
            'Memory frame only · no prediction · no investment recommendation',
            style: TextStyle(color: colors.gold, fontWeight: FontWeight.w700),
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
