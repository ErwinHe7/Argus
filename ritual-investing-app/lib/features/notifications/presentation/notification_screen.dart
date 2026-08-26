import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/presentation/demo_disclosure.dart';
import '../../../core/presentation/server_time.dart';
import '../application/notification_controller.dart';
import '../domain/model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.controller,
    required this.onOpenDestination,
    required this.onOpenPreferences,
  });

  final NotificationController controller;
  final ValueChanged<NotificationDestination> onOpenDestination;
  final VoidCallback onOpenPreferences;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.phase == NotificationPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.phase == NotificationPhase.idle) {
          unawaited(widget.controller.load());
        }
      });
    }
  }

  Future<void> _open(NotificationItem item) async {
    if (!item.isRead) await widget.controller.setRead(item.id, true);
    final destination = item.destination;
    if (destination != null) widget.onOpenDestination(destination);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('In-app notices'),
        actions: [
          IconButton(
            key: const Key('notifications-preferences'),
            tooltip: 'In-app notice preferences',
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            onPressed: widget.onOpenPreferences,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: widget.controller.load,
          child: ListView(
            key: const PageStorageKey('notifications-scroll'),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const Row(
                children: [
                  DemoBadge(),
                  SizedBox(width: 10),
                  Expanded(child: Text('In-app only · external delivery off')),
                ],
              ),
              const SizedBox(height: 10),
              Text(widget.controller.framingLabel),
              const Text(
                'This reviewed display style does not alter notification records or automatically save preferences.',
              ),
              if (widget.controller.message case final message?) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(message),
                  ),
                ),
              ],
              if (widget.controller.phase == NotificationPhase.loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              for (final item in widget.controller.items)
                Card(
                  child: ListTile(
                    key: Key('notification-open-${item.id}'),
                    minTileHeight: 64,
                    leading: Icon(
                      item.isRead
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                    ),
                    title: Text(item.title),
                    subtitle: Text(
                      '${item.body}\n'
                      '${item.scheduledAt == null ? 'Server time unavailable' : ServerTime.timestamp(item.scheduledAt!)}',
                    ),
                    isThreeLine: true,
                    trailing: item.destination == null
                        ? null
                        : const Icon(Icons.chevron_right),
                    onTap: item.destination == null ? null : () => _open(item),
                  ),
                ),
              if (widget.controller.items.isEmpty &&
                  widget.controller.phase != NotificationPhase.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'No in-app notices yet. Recaps remain available from Ritual briefings.',
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('notifications-read-all'),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: widget.controller.items.any((item) => !item.isRead)
                    ? widget.controller.prepareReadAll
                    : null,
                icon: const Icon(Icons.done_all),
                label: const Text('Review mark all read'),
              ),
              if (widget.controller.phase == NotificationPhase.readAllReview)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'All notices at or before this reviewed cutoff are included, up to the server’s bounded command limit. Nothing retries automatically.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          key: const Key('notifications-confirm-read-all'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: widget.controller.confirmReadAll,
                          child: const Text('Confirm mark all read'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (widget.controller.canReviewProtectedReadAll) ...[
                OutlinedButton(
                  key: const Key('notifications-review-protected'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: widget.controller.reviewRestoredReadAll,
                  child: const Text('Review saved read-all command'),
                ),
                OutlinedButton(
                  key: const Key('notifications-discard-protected'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: widget.controller.discardPendingReadAll,
                  child: const Text('Refresh before discarding saved command'),
                ),
              ],
              if (widget.controller.phase ==
                  NotificationPhase.reconciliationRequired)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: widget.controller.retryReconciliation,
                  child: const Text('Refresh authoritative state'),
                ),
              if (widget.controller.hasMore)
                OutlinedButton(
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

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key, required this.controller});

  final NotificationController controller;

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.phase == NotificationPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.phase == NotificationPhase.idle) {
          unawaited(widget.controller.load());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final authority = controller.preferences;
      final draft = controller.preferenceDraft ?? authority?.asDraft();
      return Scaffold(
        appBar: AppBar(title: const Text('In-app notice preferences')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const Row(
                children: [
                  DemoBadge(),
                  SizedBox(width: 10),
                  Expanded(child: Text('In-app only · no external delivery')),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'These server-owned choices control which recap notices appear in this feed. They do not register this device or enable push.',
              ),
              if (controller.message case final message?) ...[
                const SizedBox(height: 12),
                Text(message),
              ],
              if (draft == null &&
                  controller.phase == NotificationPhase.loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (draft == null)
                OutlinedButton(
                  key: const Key('notification-preferences-retry'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: controller.load,
                  child: const Text('Retry in-app preferences'),
                )
              else ...[
                const SizedBox(height: 16),
                _PreferenceSwitch(
                  key: const Key('preference-daily'),
                  title: 'Daily Ritual recap',
                  value: draft.dailyRitual,
                  onChanged: (value) => controller.editPreferenceDraft(
                    NotificationPreferencesDraft(
                      dailyRitual: value,
                      weeklyRecap: draft.weeklyRecap,
                      moonCycle: draft.moonCycle,
                      quietHours: draft.quietHours,
                    ),
                  ),
                ),
                _PreferenceSwitch(
                  key: const Key('preference-weekly'),
                  title: 'Weekly recap',
                  value: draft.weeklyRecap,
                  onChanged: (value) => controller.editPreferenceDraft(
                    NotificationPreferencesDraft(
                      dailyRitual: draft.dailyRitual,
                      weeklyRecap: value,
                      moonCycle: draft.moonCycle,
                      quietHours: draft.quietHours,
                    ),
                  ),
                ),
                _PreferenceSwitch(
                  key: const Key('preference-moon'),
                  title: 'Moon-cycle recap',
                  value: draft.moonCycle,
                  onChanged: (value) => controller.editPreferenceDraft(
                    NotificationPreferencesDraft(
                      dailyRitual: draft.dailyRitual,
                      weeklyRecap: draft.weeklyRecap,
                      moonCycle: value,
                      quietHours: draft.quietHours,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quiet hours: ${draft.quietHours.enabled ? '${draft.quietHours.start}–${draft.quietHours.end} ${draft.quietHours.timezone}' : 'Off'}',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('notification-preferences-save'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: controller.phase == NotificationPhase.mutating
                      ? null
                      : controller.savePreferences,
                  child: const Text('Save in-app preferences'),
                ),
                if (controller.phase == NotificationPhase.preferenceConflict)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: controller.reviewPreferenceConflict,
                    child: const Text('Review preserved changes'),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    minTileHeight: 56,
    title: Text(title),
    value: value,
    onChanged: onChanged,
  );
}
