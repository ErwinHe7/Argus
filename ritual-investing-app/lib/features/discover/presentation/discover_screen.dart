import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/api/state_status.dart';
import '../../../core/bootstrap/member_bootstrap.dart';
import '../../../core/presentation/demo_disclosure.dart';
import '../application/controller.dart';
import '../domain/model.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({
    super.key,
    required this.controller,
    this.onOpenSearch,
    this.onOpenItem,
    this.onOpenCreator,
    this.onOpenPrivateCircles,
  });

  final DiscoverController controller;
  final VoidCallback? onOpenSearch;
  final ValueChanged<DiscoverItemView>? onOpenItem;
  final ValueChanged<SeededCreatorView>? onOpenCreator;
  final VoidCallback? onOpenPrivateCircles;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => _content(context),
  );

  Widget _content(BuildContext context) {
    final value = controller.state.value;
    final items = value?.items ?? const <DiscoverItemView>[];
    final lead = items.isEmpty ? null : items.first;
    final secondary = items.skip(1);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _lensTitle(controller.personalization.riskFraming),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const DemoBadge(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _intro(controller.personalization.ritualVoice),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          StateStatus(phase: controller.state.phase, onRetry: controller.load),
          if (value != null) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                key: const Key('discover-search'),
                onPressed: onOpenSearch,
                icon: const Icon(Icons.search),
                label: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Search the Asset Codex'),
                ),
              ),
            ),
            if (lead != null) ...[
              const SizedBox(height: 26),
              Text(
                'FOR YOUR RITUAL',
                style: TextStyle(
                  color: context.ritualColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 10),
              _EditorialLead(
                item: lead,
                showReason:
                    controller.personalization.explanationDepth !=
                    MemberExplanationDepth.advanced,
                onTap: onOpenItem == null ? null : () => onOpenItem!(lead),
              ),
            ],
            if (secondary.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text(
                'Explore the mix',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Research, seeded examples, and dated qualification evidence—kept distinct.',
                style: TextStyle(color: context.ritualColors.muted),
              ),
              const SizedBox(height: 8),
              for (final item in secondary)
                _ResearchRow(
                  item: item,
                  onTap: onOpenItem == null ? null : () => onOpenItem!(item),
                ),
            ],
            if (value.creators.isNotEmpty) ...[
              const SizedBox(height: 26),
              Text(
                'Seeded creators',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Fictional, read-only Demo voices with transparent authorship.',
              ),
              const SizedBox(height: 8),
              for (final creator in value.creators)
                _CreatorRow(
                  creator: creator,
                  onTap: onOpenCreator == null
                      ? null
                      : () => onOpenCreator!(creator),
                ),
            ],
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.ritualColors.screenSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.ritualColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your private Circles',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Organize Demo research privately. Only you can edit these collections.',
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      key: const Key('discover-open-private-circles'),
                      onPressed: onOpenPrivateCircles,
                      icon: const Icon(Icons.folder_copy_outlined),
                      label: const Text('Open private Circles'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditorialLead extends StatelessWidget {
  const _EditorialLead({
    required this.item,
    required this.showReason,
    required this.onTap,
  });

  final DiscoverItemView item;
  final bool showReason;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ritualColors;
    return Semantics(
      button: onTap != null,
      label: '${item.title}, personalized Demo research',
      child: Material(
        color: colors.coven,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: const Key('discover-lead'),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _KindPill(kind: item.kind),
                    const Spacer(),
                    const DemoBadge(horizontalPadding: 9),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: Colors.white, fontSize: 27),
                ),
                const SizedBox(height: 8),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    color: Color(0xFFE8DDE9),
                    height: 1.45,
                  ),
                ),
                if (showReason && item.appearanceReason != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Why this appeared',
                    style: TextStyle(
                      color: Color(0xFFD8B45B),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.appearanceReason!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Observed ${_date(item.demo.observedAt)} · ${item.demo.sourceLabel}',
                  style: const TextStyle(
                    color: Color(0xFFD8C7DA),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResearchRow extends StatelessWidget {
  const _ResearchRow({required this.item, required this.onTap});

  final DiscoverItemView item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: '${item.title}, ${_kindLabel(item.kind)}, read-only Demo research',
    child: ListTile(
      key: const Key('discover-secondary'),
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      minTileHeight: 64,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: context.ritualColors.primarySoft,
        child: Icon(_kindIcon(item.kind)),
      ),
      title: Text(
        item.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${_kindLabel(item.kind)} · ${item.subtitle}'),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class _CreatorRow extends StatelessWidget {
  const _CreatorRow({required this.creator, required this.onTap});

  final SeededCreatorView creator;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: '${creator.displayName}, fictional read-only Demo creator',
    child: ListTile(
      key: Key('discover-creator-${creator.id}'),
      contentPadding: const EdgeInsets.symmetric(vertical: 5),
      minTileHeight: 64,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: context.ritualColors.screenSoft,
        child: const Icon(Icons.auto_stories_outlined),
      ),
      title: Text(
        creator.displayName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${creator.bio} · Fictional Demo creator'),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class _KindPill extends StatelessWidget {
  const _KindPill({required this.kind});

  final DiscoverItemKind kind;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      _kindLabel(kind).toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    ),
  );
}

String _lensTitle(MemberRiskFraming value) => switch (value) {
  MemberRiskFraming.low => 'A steadier research lens',
  MemberRiskFraming.moderate => 'A balanced research lens',
  MemberRiskFraming.high => 'A wider research lens',
  MemberRiskFraming.unavailable => 'A considered research lens',
};

String _intro(MemberRitualVoice value) => switch (value) {
  MemberRitualVoice.practical => 'Server-prioritized research with evidence, risks, and limitations close at hand.',
  MemberRitualVoice.mystical => 'Trace today’s research constellation, then ground every signal in dated evidence.',
  MemberRitualVoice.balanced || MemberRitualVoice.unavailable => 'A ritual-shaped research path, grounded in dated evidence and clear uncertainty.',
};

String _kindLabel(DiscoverItemKind kind) => switch (kind) {
  DiscoverItemKind.asset => 'Asset Codex',
  DiscoverItemKind.grimoire => 'Grimoire',
  DiscoverItemKind.circleTemplate => 'Seeded Circle',
  DiscoverItemKind.coven => 'Founders’ Coven',
};

IconData _kindIcon(DiscoverItemKind kind) => switch (kind) {
  DiscoverItemKind.asset => Icons.candlestick_chart_outlined,
  DiscoverItemKind.grimoire => Icons.menu_book_outlined,
  DiscoverItemKind.circleTemplate => Icons.blur_circular_outlined,
  DiscoverItemKind.coven => Icons.nightlight_outlined,
};

String _date(DateTime value) {
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
