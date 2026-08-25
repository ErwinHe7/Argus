import 'package:flutter/material.dart';

import '../../../core/api/state_status.dart';
import '../../../core/api/view_state.dart';
import '../../../core/presentation/demo_disclosure.dart';
import '../application/controller.dart';
import '../domain/model.dart';

class PrivateCirclesScreen extends StatelessWidget {
  const PrivateCirclesScreen({
    super.key,
    required this.controller,
    required this.onOpenCircle,
  });

  final CircleListController controller;
  final ValueChanged<String> onOpenCircle;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your private Circles')),
    floatingActionButton: SizedBox(
      height: 56,
      child: FloatingActionButton.extended(
        key: const Key('private-circle-create'),
        onPressed: controller.mutationPhase == CircleMutationPhase.committing
            ? null
            : () => _create(context),
        icon: const Icon(Icons.add),
        label: const Text('New Circle'),
      ),
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final collection = controller.state.value;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              const Row(
                children: [
                  DemoBadge(),
                  SizedBox(width: 8),
                  Expanded(child: Text('Private · editable only by you')),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Fictional provider-free research; no live banking or market provider.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              StateStatus(
                phase: controller.state.phase,
                onRetry: controller.load,
              ),
              if (controller.validationMessage case final message?)
                _Notice(message: message),
              if (controller.mutationPhase ==
                  CircleMutationPhase.retryableFailure)
                _Notice(
                  message: 'The result is uncertain. Retry the same private command.',
                  actionLabel: 'Retry',
                  onAction: controller.retryPending,
                ),
              if (controller.mutationPhase == CircleMutationPhase.committed &&
                  controller.lastCreated != null)
                _Notice(
                  message: 'Private Circle created.',
                  actionLabel: 'Open',
                  onAction: () => onOpenCircle(controller.lastCreated!.id),
                ),
              if (controller.state.phase == LoadPhase.empty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    'No private Circles yet. Start from a blank Circle or copy a fictional seeded example.',
                  ),
                ),
              if (collection != null) ...[
                ...collection.items.where((circle) => !circle.isArchived).map(
                  (circle) => _CircleTile(
                    circle: circle,
                    onTap: () => onOpenCircle(circle.id),
                  ),
                ),
                if (collection.items.any((circle) => circle.isArchived)) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Archived',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  ...collection.items.where((circle) => circle.isArchived).map(
                    (circle) => _CircleTile(
                      circle: circle,
                      onTap: () => onOpenCircle(circle.id),
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    ),
  );

  Future<void> _create(BuildContext context) async {
    final title = TextEditingController();
    final description = TextEditingController();
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New private Circle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('private-circle-title'),
              controller: title,
              maxLength: 80,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              key: const Key('private-circle-description'),
              controller: description,
              maxLength: 10000,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Private notes'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          SizedBox(
            height: 48,
            child: FilledButton(
              key: const Key('private-circle-create-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create privately'),
            ),
          ),
        ],
      ),
    );
    if (create == true) {
      await controller.create(
        title: title.text,
        description: description.text,
      );
    }
    title.dispose();
    description.dispose();
  }
}

class _CircleTile extends StatelessWidget {
  const _CircleTile({required this.circle, required this.onTap});

  final PrivateCircle circle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      key: Key('private-circle-${circle.id}'),
      minTileHeight: 72,
      onTap: onTap,
      leading: CircleAvatar(
        child: Icon(circle.isArchived ? Icons.archive_outlined : Icons.lock_outline),
      ),
      title: Text(
        circle.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        circle.isArchived
            ? 'Archived · read-only · v${circle.version}'
            : 'Editable only by you · ${circle.assets.length} assets · v${circle.version}',
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(message)),
        if (actionLabel != null && onAction != null)
          SizedBox(
            height: 48,
            child: TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ),
      ],
    ),
  );
}
