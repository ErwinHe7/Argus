import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

class DailyRitualScreen extends StatelessWidget {
  const DailyRitualScreen({
    super.key,
    required this.onOpenCoven,
    required this.onToggleTheme,
  });

  final VoidCallback onOpenCoven;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
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
                        'August 20',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
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
                _CardStage(colors: colors),
                const SizedBox(height: 18),
                Text(
                  'Direction, not urgency.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 10),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      'The strongest path today rewards patience. Favor durable momentum; let noisy names pass without you.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontSize: 14, height: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
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
                    label: const Text('Market-informed · reveal the pattern'),
                  ),
                ),
                const SizedBox(height: 8),
                Divider(color: colors.line),
                const SizedBox(height: 8),
                _Constellation(colors: colors),
                const SizedBox(height: 16),
                _CovenStrip(colors: colors, onTap: onOpenCoven),
                const SizedBox(height: 14),
                _RowanCounsel(colors: colors),
                const SizedBox(height: 18),
                Text(
                  'Demo market scenario · educational exploration only',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.faint, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEvidence(BuildContext context) {
    final colors = context.ritualColors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
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
                  'Observed in this deterministic demo at 9:35 AM ET. These are research cues, not predictions or instructions to buy.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                const _EvidenceRow(
                  symbol: 'VIG',
                  factor: 'Lower volatility and durable dividend momentum',
                ),
                const _EvidenceRow(
                  symbol: 'XLV',
                  factor: 'Defensive relative strength in the scenario window',
                ),
                const _EvidenceRow(
                  symbol: 'WOMN',
                  factor: 'Broad leadership exposure with positive breadth',
                ),
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.goldSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Uncertainty remains high: the scenario is simulated, prices are fictional, and short-term conditions can reverse.',
                      style: TextStyle(color: colors.ink, height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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
  const _CardStage({required this.colors});

  final RitualColors colors;

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
                label: 'The Compass tarot card: a woman holding a lantern at a celestial crossroads',
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.asset(
                      'assets/images/the-compass.png',
                      fit: BoxFit.cover,
                    ),
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
  const _Constellation({required this.colors});

  final RitualColors colors;

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
              '3 of 5 aligned',
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
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AssetStar(
                  symbol: 'VIG',
                  change: '+0.42%',
                  note: 'steady wealth',
                ),
                _AssetStar(
                  symbol: 'XLV',
                  change: '+0.31%',
                  note: 'defensive orbit',
                  selected: true,
                ),
                _AssetStar(
                  symbol: 'WOMN',
                  change: '+0.27%',
                  note: 'leadership ETF',
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
    required this.change,
    required this.note,
    this.selected = false,
  });

  final String symbol;
  final String change;
  final String note;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.ritualColors;
    return Expanded(
      child: Semantics(
        button: true,
        label: '$symbol, $change, $note, demo asset idea',
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
            Text(
              change,
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
    );
  }
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
  const _RowanCounsel({required this.colors});

  final RitualColors colors;

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
          child: ClipOval(
            child: Image.asset(
              'assets/images/persona-triptych.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
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
                const TextSpan(
                  text: '“I’ll show you what changed beneath the reading.”',
                ),
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
