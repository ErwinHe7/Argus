import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/api/state_status.dart';
import '../../../core/presentation/demo_disclosure.dart';
import '../application/controller.dart';
import '../domain/model.dart';

class GrimoireDetailScreen extends StatelessWidget {
  const GrimoireDetailScreen({
    super.key,
    required this.controller,
    required this.onOpenAsset,
  });

  final GrimoireController controller;
  final ValueChanged<String> onOpenAsset;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Grimoire')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => _content(context),
      ),
    ),
  );

  Widget _content(BuildContext context) {
    final value = controller.state.value;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
      children: [
        StateStatus(phase: controller.state.phase, onRetry: controller.load),
        if (value != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  value.title,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              const SizedBox(width: 12),
              const DemoBadge(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${value.curatorLabel} · read-only curated research',
            style: TextStyle(color: context.ritualColors.muted),
          ),
          const SizedBox(height: 14),
          Text(value.description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              key: const Key('grimoire-save'),
              onPressed: controller.savePhase == GrimoireSavePhase.saving
                  ? null
                  : controller.toggleSaved,
              icon: Icon(value.saved ? Icons.bookmark : Icons.bookmark_border),
              label: Text(value.saved ? 'Saved' : 'Save Grimoire'),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'Inside this Grimoire',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 5),
          const Text('Each reference opens the shared Asset Codex.'),
          const SizedBox(height: 8),
          for (final asset in value.assets)
            ListTile(
              key: Key('grimoire-asset-${asset.id}'),
              minTileHeight: 64,
              contentPadding: const EdgeInsets.symmetric(vertical: 5),
              onTap: () => onOpenAsset(asset.id),
              leading: CircleAvatar(
                backgroundColor: context.ritualColors.primarySoft,
                child: Text(asset.symbol.characters.first),
              ),
              title: Text(
                '${asset.symbol} · ${asset.name}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(asset.appearanceReason),
              trailing: const Icon(Icons.chevron_right),
            ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.ritualColors.screenSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Simulation boundaries',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                for (final limitation in value.demo.limitations)
                  Text('• $limitation'),
                const SizedBox(height: 6),
                Text(
                  '${value.demo.sourceLabel} · observed ${_date(value.demo.observedAt)}',
                  style: TextStyle(color: context.ritualColors.faint),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
