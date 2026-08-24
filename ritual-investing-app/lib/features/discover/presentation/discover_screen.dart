import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/api/state_status.dart';
import '../application/controller.dart';
import '../domain/model.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key, required this.controller});
  final DiscoverController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final colors = context.ritualColors;
    final value = controller.state.value;
    final grimoires = value?.grimoires ?? const <DiscoverCard>[];
    final circles = value?.circles ?? const <DiscoverCard>[];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Discover',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              const _DemoBadge(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Research paths shaped like rituals, not a stock screener.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          StateStatus(phase: controller.state.phase, onRetry: controller.load),
          if (value != null) ...[
            const SizedBox(height: 20),
            const TextField(
              readOnly: true,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search the Asset Codex',
              ),
            ),
            const SizedBox(height: 28),
            const _SectionTitle(
              title: 'Grimoires',
              trailing: 'Curated demo research',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 154,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (index, item) in grimoires.indexed)
                    _GrimoireTile(
                      title: item.title,
                      subtitle: item.subtitle,
                      icon: [
                        Icons.shield_moon_outlined,
                        Icons.dark_mode_outlined,
                        Icons.hourglass_bottom,
                      ][index % 3],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const _SectionTitle(
              title: 'Circles',
              trailing: 'Seeded community examples',
            ),
            const SizedBox(height: 8),
            for (final (index, item) in circles.indexed)
              _DiscoveryRow(
                icon: index.isEven ? Icons.spa_outlined : Icons.public,
                title: item.title,
                subtitle: item.subtitle,
                colors: colors,
              ),
            const SizedBox(height: 28),
            const _SectionTitle(
              title: 'Weekly omen',
              trailing: 'Simulated briefing',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.coven,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Noise is rising. Your plan doesn’t have to.',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'LibreBaskerville',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Rowan separates what changed from what merely got louder.',
                    style: TextStyle(color: Color(0xFFDCCBDE), height: 1.4),
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

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.ritualColors.goldSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          'DEMO',
          style: TextStyle(
            color: context.ritualColors.ink,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
        ),
        Text(
          trailing,
          style: TextStyle(color: context.ritualColors.faint, fontSize: 12),
        ),
      ],
    );
  }
}

class _GrimoireTile extends StatelessWidget {
  const _GrimoireTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.ritualColors;
    return Container(
      width: 176,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.screenSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.gold, size: 28),
          const Spacer(),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 19),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: colors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _DiscoveryRow extends StatelessWidget {
  const _DiscoveryRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final RitualColors colors;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: colors.primarySoft,
        foregroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
