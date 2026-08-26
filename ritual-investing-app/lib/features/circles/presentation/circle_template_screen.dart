import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/api/state_status.dart';
import '../../../core/presentation/demo_disclosure.dart';
import '../../discover/domain/model.dart';
import '../application/controller.dart';
import '../domain/model.dart';

class CircleTemplateScreen extends StatelessWidget {
  const CircleTemplateScreen({
    super.key,
    required this.controller,
    required this.onOpenAsset,
    required this.onCopy,
    this.onOpenCreator,
    this.copyController,
    this.onRetryCopy,
  });

  final CircleTemplateController controller;
  final ValueChanged<String> onOpenAsset;
  final ValueChanged<String> onCopy;
  final ValueChanged<SeededCreatorView>? onOpenCreator;
  final CircleListController? copyController;
  final VoidCallback? onRetryCopy;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Seeded Circle')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([controller, ?copyController]),
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
          const Text('Fictional seeded example · read-only'),
          const SizedBox(height: 14),
          Text(value.description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          Semantics(
            button: onOpenCreator != null,
            label:
                '${value.creator.displayName}, fictional read-only Demo creator',
            child: ListTile(
              key: Key('template-creator-${value.creator.id}'),
              minTileHeight: 64,
              contentPadding: EdgeInsets.zero,
              onTap: onOpenCreator == null
                  ? null
                  : () => onOpenCreator!(value.creator),
              leading: const CircleAvatar(
                child: Icon(Icons.auto_stories_outlined),
              ),
              title: Text(
                value.creator.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value.creator.bio),
                  const Text('Fictional Demo creator'),
                ],
              ),
              trailing: onOpenCreator == null
                  ? null
                  : const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const Key('template-save'),
                    onPressed:
                        controller.savePhase == CircleTemplateSavePhase.saving
                        ? null
                        : controller.toggleSaved,
                    icon: Icon(
                      value.saved ? Icons.bookmark : Icons.bookmark_border,
                    ),
                    label: Text(value.saved ? 'Saved' : 'Save'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    key: const Key('template-copy'),
                    onPressed:
                        copyController?.mutationPhase ==
                            CircleMutationPhase.committing
                        ? null
                        : () => onCopy(value.id),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Make private copy'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (copyController?.mutationPhase ==
              CircleMutationPhase.retryableFailure)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The private copy result is uncertain. Retry the same command so it cannot create a duplicate.',
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        key: const Key('template-copy-retry'),
                        onPressed: onRetryCopy,
                        child: const Text('Retry private copy'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Text(
            'The seeded example stays unchanged; only the private copy is editable.',
          ),
          const SizedBox(height: 26),
          Text(
            'Research references',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          for (final asset in value.assets)
            ListTile(
              key: Key('template-asset-${asset.id}'),
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
              subtitle: Text(asset.note ?? asset.appearanceReason),
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
                  'Demo boundaries',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final limitation in value.demo.limitations)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• $limitation'),
                  ),
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
