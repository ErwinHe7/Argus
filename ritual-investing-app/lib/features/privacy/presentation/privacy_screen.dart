import 'package:flutter/material.dart';

import '../application/privacy_controller.dart';
import '../domain/model.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({
    super.key,
    required this.controller,
    this.onOpenDemoReset,
  });

  final PrivacyController controller;
  final VoidCallback? onOpenDemoReset;

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.controller.phase == PrivacyPhase.idle) {
        widget.controller.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy and data')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const Chip(label: Text('Private account controls')),
            const SizedBox(height: 12),
            Text(
              'Your data export',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ritual Investing prepares one coherent ZIP. Only the latest one-time download is used, then the private local file is removed after sharing.',
            ),
            const SizedBox(height: 8),
            Text(widget.controller.framingLabel),
            _PrivacyStatus(controller: widget.controller),
            const SizedBox(height: 12),
            if ({
                  PrivacyPhase.empty,
                  PrivacyPhase.shared,
                  PrivacyPhase.exportFailed,
                }.contains(widget.controller.phase) &&
                !widget.controller.hasProtectedCommand)
              FilledButton.icon(
                key: const Key('privacy-export-request'),
                onPressed: widget.controller.isBusy
                    ? null
                    : widget.controller.requestExport,
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Request private ZIP'),
              ),
            if (widget.controller.canRefreshExport)
              OutlinedButton.icon(
                key: const Key('privacy-export-refresh'),
                onPressed: widget.controller.isBusy
                    ? null
                    : widget.controller.refreshExport,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh export status'),
              ),
            if (widget.controller.phase == PrivacyPhase.downloadReady)
              FilledButton.icon(
                key: const Key('privacy-export-share'),
                onPressed: widget.controller.isBusy
                    ? null
                    : widget.controller.downloadAndShare,
                icon: const Icon(Icons.ios_share),
                label: const Text('Download and share privately'),
              ),
            if (widget.controller.hasProtectedReset) ...[
              const Text(
                'A Demo reset is saved for review. Continue it from Reset Demo.',
              ),
              if (widget.onOpenDemoReset != null)
                OutlinedButton(
                  key: const Key('privacy-open-demo-reset'),
                  onPressed: widget.onOpenDemoReset,
                  child: const Text('Open saved Demo reset'),
                ),
            ],
            if (widget.controller.hasProtectedCommand &&
                !widget.controller.hasProtectedReset)
              OutlinedButton(
                key: const Key('privacy-restored-review'),
                onPressed: widget.controller.isBusy
                    ? null
                    : widget.controller.reviewRestoredAction,
                child: Text(
                  widget.controller.protectedActionLabel ??
                      'Review saved privacy action',
                ),
              ),
            const Divider(height: 40),
            Text(
              'Delete account',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Acceptance immediately disables the account and schedules permanent deletion. Recent sign-in is required.',
            ),
            const SizedBox(height: 12),
            if (widget.controller.phase != PrivacyPhase.deletionReview &&
                widget.controller.phase != PrivacyPhase.deletionAccepted &&
                !widget.controller.hasProtectedCommand)
              OutlinedButton.icon(
                key: const Key('privacy-deletion-review'),
                onPressed: widget.controller.isBusy
                    ? null
                    : widget.controller.prepareDeletion,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Review account deletion'),
              ),
            if (widget.controller.phase == PrivacyPhase.deletionReview)
              FilledButton.icon(
                key: const Key('privacy-deletion-confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: widget.controller.isBusy
                    ? null
                    : widget.controller.confirmDeletion,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Confirm irreversible deletion'),
              ),
          ],
        ),
      ),
    ),
  );
}

class DemoResetScreen extends StatefulWidget {
  const DemoResetScreen({
    super.key,
    required this.controller,
    this.onOpenPrivacy,
  });

  final PrivacyController controller;
  final VoidCallback? onOpenPrivacy;

  @override
  State<DemoResetScreen> createState() => _DemoResetScreenState();
}

class _DemoResetScreenState extends State<DemoResetScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.controller.phase == PrivacyPhase.idle) {
        widget.controller.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset Demo')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const Chip(label: Text('Demo · no real money moves')),
            const SizedBox(height: 12),
            Text(
              'Begin again with the seeded experience',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'This replaces fictional portfolios, holdings, plans, goals, recaps, notices, and Demo membership. It cannot be undone. Your identity and onboarding preferences stay with your account.',
            ),
            const SizedBox(height: 8),
            Text(widget.controller.framingLabel),
            _PrivacyStatus(controller: widget.controller),
            const SizedBox(height: 16),
            if (widget.controller.hasProtectedCommand &&
                !widget.controller.hasProtectedReset) ...[
              const Text(
                'A different privacy action is saved. Continue it from Privacy and data before resetting Demo.',
              ),
              if (widget.onOpenPrivacy != null)
                OutlinedButton(
                  key: const Key('demo-reset-open-privacy'),
                  onPressed: widget.onOpenPrivacy,
                  child: const Text('Open Privacy and data'),
                ),
            ],
            if (widget.controller.hasProtectedReset)
              OutlinedButton(
                key: const Key('demo-reset-restored-review'),
                onPressed: widget.controller.isBusy
                    ? null
                    : widget.controller.reviewRestoredAction,
                child: const Text('Review saved Demo reset'),
              ),
            if (widget.controller.phase != PrivacyPhase.resetReview &&
                !widget.controller.hasProtectedCommand)
              OutlinedButton.icon(
                key: const Key('demo-reset-review'),
                onPressed: widget.controller.isBusy
                    ? null
                    : widget.controller.prepareDemoReset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Review Demo reset'),
              ),
            if (widget.controller.phase == PrivacyPhase.resetReview &&
                (!widget.controller.hasProtectedCommand ||
                    widget.controller.hasProtectedReset))
              FilledButton.icon(
                key: const Key('demo-reset-confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: widget.controller.isBusy
                    ? null
                    : () => widget.controller.confirmDemoReset(seedVersion: 1),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Confirm seeded Demo reset'),
              ),
          ],
        ),
      ),
    ),
  );
}

class _PrivacyStatus extends StatelessWidget {
  const _PrivacyStatus({required this.controller});

  final PrivacyController controller;

  @override
  Widget build(BuildContext context) {
    final export = controller.export;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (controller.isBusy) const LinearProgressIndicator(),
            if (controller.message case final message?) ...[
              const SizedBox(height: 8),
              Text(message),
            ],
            if (export != null) ...[
              const SizedBox(height: 8),
              Text('Export status: ${_statusLabel(export)}'),
              if (export.expiresAt case final expiry?)
                Text('Archive expires: ${expiry.toLocal()}'),
            ],
          ],
        ),
      ),
    );
  }
}

String _statusLabel(PrivacyExport export) => switch (export.status) {
  PrivacyExportStatus.requested => 'requested',
  PrivacyExportStatus.verified => 'verified',
  PrivacyExportStatus.queued => 'queued',
  PrivacyExportStatus.processing => 'processing',
  PrivacyExportStatus.completed when export.hasDownloadGrant => 'ready',
  PrivacyExportStatus.completed => 'completed · download unavailable',
  PrivacyExportStatus.failed => 'failed',
  PrivacyExportStatus.cancelled => 'cancelled',
};
