import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.ritualColors;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your chamber',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: colors.goldSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'DEMO',
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'A locally simulated portfolio. No money or account is connected.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.coven,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SIMULATED BALANCE',
                  style: TextStyle(
                    color: Color(0xFFDCCBDE),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  r'$12,480.36',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'LibreBaskerville',
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '+1.8% this moon cycle',
                  style: TextStyle(
                    color: colors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text('Intentions', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          _ProgressRow(colors: colors),
          const SizedBox(height: 26),
          Text(
            'Future Mirror',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Explore how fictional contributions and modeled returns could change the path. Projections are not guarantees.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'steady', label: Text('Steady')),
              ButtonSegment(value: 'bright', label: Text('Bright')),
              ButtonSegment(value: 'storm', label: Text('Storm')),
            ],
            selected: const {'steady'},
            onSelectionChanged: (_) {},
          ),
          const SizedBox(height: 26),
          Text(
            'Demo actions',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          const _ActionRow(
            icon: Icons.account_balance_outlined,
            title: 'Link a fictional bank',
            subtitle: 'No credentials collected',
          ),
          const _ActionRow(
            icon: Icons.autorenew,
            title: 'Recurring ritual',
            subtitle: r'Preview a $25 weekly demo plan',
          ),
          const _ActionRow(
            icon: Icons.balance_outlined,
            title: 'Rebalance a Circle',
            subtitle: 'Simulate allocation changes',
          ),
          const _ActionRow(
            icon: Icons.workspace_premium_outlined,
            title: 'Premium chamber',
            subtitle: 'Preview simulated upgrade and restore',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.screenSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: colors.gold,
                  foregroundImage: const AssetImage(
                    'assets/images/persona-triptych.png',
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    'Rowan can explain the model. He never decides for you.',
                    style: TextStyle(
                      color: colors.ink,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.colors});

  final RitualColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                'Build a six-month calm fund',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text('42%'),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: 0.42,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: colors.screenSoft,
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 64,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: context.ritualColors.gold),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}
