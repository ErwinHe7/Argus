import 'package:flutter/material.dart';

import '../../../core/api/state_status.dart';
import '../../../core/presentation/demo_disclosure.dart';
import '../application/controller.dart';
import '../domain/model.dart';

class PrivateCircleDetailScreen extends StatelessWidget {
  const PrivateCircleDetailScreen({
    super.key,
    required this.controller,
    required this.onOpenAsset,
  });

  final CircleDetailController controller;
  final ValueChanged<String> onOpenAsset;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Private Circle')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => _content(context),
      ),
    ),
  );

  Widget _content(BuildContext context) {
    final circle = controller.state.value;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
      children: [
        StateStatus(
          phase: controller.state.phase,
          onRetry: controller.retryLoad,
        ),
        if (circle != null) ...[
          Row(
            children: [
              const DemoBadge(),
              const SizedBox(width: 8),
              Icon(
                circle.isArchived ? Icons.archive_outlined : Icons.lock_outline,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  circle.isArchived
                      ? 'Archived · read-only'
                      : 'Private · editable',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('Version ${circle.version}'),
            ],
          ),
          if (circle.sourceTemplateId != null) ...[
            const SizedBox(height: 6),
            Text(
              'Private copy · source revision ${circle.sourceRevisionId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            'Fictional provider-free research; no live balances, prices, or banking connection.',
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: ValueKey('private-title-${circle.id}'),
            initialValue: controller.draft.title,
            readOnly: circle.isArchived || controller.isMutating,
            maxLength: 80,
            onChanged: (value) => controller.updateDraft(title: value),
            decoration: const InputDecoration(labelText: 'Circle title'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('private-description-${circle.id}'),
            initialValue: controller.draft.description,
            readOnly: circle.isArchived || controller.isMutating,
            maxLength: 10000,
            minLines: 2,
            maxLines: 4,
            onChanged: (value) => controller.updateDraft(description: value),
            decoration: const InputDecoration(labelText: 'Private notes'),
          ),
          if (controller.validationMessage case final message?)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (controller.requiresConflictReview)
            _ConflictReview(controller: controller),
          if (!circle.isArchived)
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                key: const Key('private-circle-save'),
                onPressed: controller.isMutating ? null : controller.saveDraft,
                icon: const Icon(Icons.check),
                label: const Text('Save private notes'),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Research assets',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (!circle.isArchived && controller.draft.assets.length < 50)
                SizedBox(
                  height: 48,
                  child: TextButton.icon(
                    key: const Key('private-asset-add'),
                    onPressed: controller.isMutating
                        ? null
                        : () => _addAsset(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ),
            ],
          ),
          if (controller.draft.assets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No assets yet. Add a stable Asset Codex ID to organize private research.',
              ),
            ),
          for (final (index, asset) in controller.draft.assets.indexed)
            _AssetTile(
              asset: asset,
              archived: circle.isArchived || controller.isMutating,
              canMoveUp: index > 0,
              canMoveDown: index < controller.draft.assets.length - 1,
              onOpen: () => onOpenAsset(asset.assetId),
              onEdit: () => _editAsset(context, asset),
              onRemove: () => _removeAsset(context, asset),
              onMoveUp: () => _move(index, index - 1),
              onMoveDown: () => _move(index, index + 1),
            ),
          if (!circle.isArchived && controller.draft.assets.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                key: const Key('private-assets-save-order'),
                onPressed: controller.isMutating
                    ? null
                    : controller.saveAssetOrder,
                child: const Text('Save asset order'),
              ),
            ),
          ],
          const SizedBox(height: 28),
          if (!circle.isArchived)
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                key: const Key('private-circle-archive'),
                onPressed: controller.isMutating
                    ? null
                    : () => _archive(context),
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archive private Circle'),
              ),
            ),
        ],
      ],
    );
  }

  void _move(int from, int to) {
    final ids = controller.draft.assets.map((asset) => asset.assetId).toList();
    final id = ids.removeAt(from);
    ids.insert(to, id);
    controller.reorderDraft(ids);
  }

  Future<void> _addAsset(BuildContext context) async {
    final id = TextEditingController();
    final result = await _assetDialog(
      context,
      title: 'Add research asset',
      assetId: id,
      ordinal: controller.draft.assets.length + 1,
    );
    if (result != null) await controller.putAsset(result);
    id.dispose();
  }

  Future<void> _editAsset(BuildContext context, CircleAsset asset) async {
    final id = TextEditingController(text: asset.assetId);
    final result = await _assetDialog(
      context,
      title: 'Edit private asset note',
      assetId: id,
      ordinal: asset.ordinal,
      initial: asset,
      lockAssetId: true,
    );
    if (result != null) await controller.putAsset(result);
    id.dispose();
  }

  Future<CircleAsset?> _assetDialog(
    BuildContext context, {
    required String title,
    required TextEditingController assetId,
    required int ordinal,
    CircleAsset? initial,
    bool lockAssetId = false,
  }) async {
    final note = TextEditingController(text: initial?.note);
    final weight = TextEditingController(
      text: initial?.weightBps == null
          ? ''
          : (initial!.weightBps! / 100).toStringAsFixed(2),
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('private-asset-id'),
              controller: assetId,
              readOnly: lockAssetId,
              decoration: const InputDecoration(labelText: 'Asset Codex ID'),
            ),
            TextField(
              key: const Key('private-asset-note'),
              controller: note,
              maxLength: 2000,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Private note'),
            ),
            TextField(
              key: const Key('private-asset-weight'),
              controller: weight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Optional weight %'),
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
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save asset'),
            ),
          ),
        ],
      ),
    );
    final parsedWeight = double.tryParse(weight.text.trim());
    final result = accepted == true
        ? CircleAsset(
            assetId: assetId.text.trim(),
            ordinal: ordinal,
            note: note.text.isEmpty ? null : note.text,
            weightBps: parsedWeight == null
                ? null
                : (parsedWeight * 100).round(),
          )
        : null;
    note.dispose();
    weight.dispose();
    return result;
  }

  Future<void> _removeAsset(BuildContext context, CircleAsset asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove research asset?'),
        content: const Text('This only changes your private Circle.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.removeAsset(asset.assetId);
  }

  Future<void> _archive(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive private Circle?'),
        content: const Text(
          'It remains visible under Archived and becomes read-only.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Archive'),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.archive();
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({
    required this.asset,
    required this.archived,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onOpen,
    required this.onEdit,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final CircleAsset asset;
  final bool archived;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        children: [
          ListTile(
            key: Key('private-asset-open-${asset.assetId}'),
            minTileHeight: 64,
            onTap: onOpen,
            leading: CircleAvatar(child: Text('${asset.ordinal}')),
            title: Text('Asset ${asset.assetId}'),
            subtitle: Text(
              [
                if (asset.note != null) asset.note!,
                if (asset.weightBps != null)
                  '${(asset.weightBps! / 100).toStringAsFixed(2)}%',
              ].join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
          if (!archived)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                IconButton(
                  key: Key('private-asset-up-${asset.assetId}'),
                  tooltip: 'Move earlier',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: canMoveUp ? onMoveUp : null,
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  key: Key('private-asset-down-${asset.assetId}'),
                  tooltip: 'Move later',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: canMoveDown ? onMoveDown : null,
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  key: Key('private-asset-edit-${asset.assetId}'),
                  tooltip: 'Edit private asset note',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  key: Key('private-asset-remove-${asset.assetId}'),
                  tooltip: 'Remove from private Circle',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _ConflictReview extends StatelessWidget {
  const _ConflictReview({required this.controller});

  final CircleDetailController controller;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Review changes from another device'),
          const SizedBox(height: 6),
          const Text(
            'Your pending edit is preserved. Choose which version to keep.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              SizedBox(
                height: 48,
                child: FilledButton(
                  key: const Key('private-conflict-retry'),
                  onPressed: controller.isMutating
                      ? null
                      : controller.reviewAndRetry,
                  child: const Text('Apply my edit'),
                ),
              ),
              SizedBox(
                height: 48,
                child: TextButton(
                  key: const Key('private-conflict-authority'),
                  onPressed: controller.isMutating
                      ? null
                      : controller.useAuthoritativeVersion,
                  child: const Text('Use server version'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
