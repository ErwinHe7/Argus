import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/presentation/demo_disclosure.dart';
import '../../../core/presentation/server_time.dart';
import '../application/briefing_controller.dart';
import '../domain/model.dart';

class BriefingsScreen extends StatefulWidget {
  const BriefingsScreen({
    super.key,
    required this.controller,
    required this.onOpenBriefing,
  });

  final BriefingController controller;
  final ValueChanged<String> onOpenBriefing;

  @override
  State<BriefingsScreen> createState() => _BriefingsScreenState();
}

class _BriefingsScreenState extends State<BriefingsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.phase == BriefingPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.phase == BriefingPhase.idle) {
          unawaited(widget.controller.load());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Gospel briefings')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: widget.controller.load,
          child: ListView(
            key: const PageStorageKey('briefings-scroll'),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const Row(
                children: [
                  DemoBadge(),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Recorded simulated recaps · no real money moves',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(widget.controller.framingLabel),
              const SizedBox(height: 8),
              const Text(
                'Display framing is a saved style preference. It never changes the server recap or its source authority.',
              ),
              if (widget.controller.message case final message?) ...[
                const SizedBox(height: 12),
                _StatusCard(message: message),
              ],
              if (widget.controller.phase == BriefingPhase.loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (widget.controller.items.isEmpty &&
                  widget.controller.phase != BriefingPhase.loading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    widget.controller.phase == BriefingPhase.empty
                        ? 'No daily, weekly, or moon-cycle recaps are available yet.'
                        : 'Pull to retry the authoritative recap list.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final item in widget.controller.items)
                Card(
                  child: ListTile(
                    minTileHeight: 64,
                    leading: Icon(
                      item.isRead
                          ? Icons.auto_stories_outlined
                          : Icons.auto_stories,
                    ),
                    title: Text(item.cadenceLabel),
                    subtitle: Text(
                      '${_period(item)}\n'
                      'Source sequence ${item.sourceSequence} · '
                      '${item.isRead ? 'Read' : 'Unread'}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onOpenBriefing(item.id),
                  ),
                ),
              if (widget.controller.hasMore)
                OutlinedButton(
                  key: const Key('briefings-load-more'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: widget.controller.loadMore,
                  child: const Text('Load more'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class BriefingDetailScreen extends StatefulWidget {
  const BriefingDetailScreen({
    super.key,
    required this.briefingId,
    required this.controller,
    this.onOpenRitual,
    this.onOpenBriefings,
  });

  final String briefingId;
  final BriefingController controller;
  final VoidCallback? onOpenRitual;
  final VoidCallback? onOpenBriefings;

  @override
  State<BriefingDetailScreen> createState() => _BriefingDetailScreenState();
}

class _BriefingDetailScreenState extends State<BriefingDetailScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.selected?.id != widget.briefingId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.selected?.id != widget.briefingId) {
          unawaited(widget.controller.open(widget.briefingId));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final detail = widget.controller.selected;
      return Scaffold(
        appBar: AppBar(title: const Text('Gospel briefing')),
        body: SafeArea(
          child: ListView(
            key: const PageStorageKey('briefing-detail-scroll'),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const Align(alignment: Alignment.centerLeft, child: DemoBadge()),
              const SizedBox(height: 12),
              Text(widget.controller.framingLabel),
              const Text(
                'Reviewed local voice only · server content remains unchanged.',
              ),
              if (widget.controller.message case final message?) ...[
                const SizedBox(height: 12),
                _StatusCard(message: message),
              ],
              if (detail == null &&
                  widget.controller.phase == BriefingPhase.loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (detail == null) ...[
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('briefing-detail-retry'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => widget.controller.open(widget.briefingId),
                  child: const Text('Retry briefing'),
                ),
                if (widget.onOpenBriefings != null)
                  OutlinedButton(
                    key: const Key('briefing-detail-list'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: widget.onOpenBriefings,
                    child: const Text('Back to briefings'),
                  ),
              ] else ...[
                const SizedBox(height: 20),
                Text(
                  detail.summary.cadenceLabel,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text('Recorded at ${ServerTime.timestamp(detail.generatedAt)}'),
                Text('Source sequence ${detail.sourceSequence}'),
                Text('Format: ${detail.formatLabel}'),
                const SizedBox(height: 20),
                for (final section in detail.sections)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recorded simulated summary',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(section.disclosure),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('briefing-read-toggle'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: widget.controller.phase == BriefingPhase.mutating
                      ? null
                      : () => widget.controller.setSelectedRead(!detail.isRead),
                  icon: Icon(
                    detail.isRead ? Icons.mark_email_unread : Icons.done_all,
                  ),
                  label: Text(detail.isRead ? 'Mark unread' : 'Mark read'),
                ),
                if (widget.onOpenRitual != null)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: widget.onOpenRitual,
                    child: const Text('Open today’s Gospel'),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Simulation limitation: this recap reflects recorded fictional activity and saved research. It is not financial advice, a prediction, or evidence of supernatural market causation.',
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
  );
}

String _period(BriefingSummary item) {
  String date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
  final start = date(item.periodStart);
  final end = date(item.periodEnd);
  return start == end ? start : '$start to $end';
}
