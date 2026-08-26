import 'package:flutter/material.dart';

import 'view_state.dart';

class StateStatus extends StatelessWidget {
  const StateStatus({super.key, required this.phase, required this.onRetry});

  final LoadPhase phase;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = switch (phase) {
      LoadPhase.idle || LoadPhase.ready => null,
      LoadPhase.loading => 'Loading',
      LoadPhase.stale => 'Showing saved data while offline',
      LoadPhase.empty => 'Nothing to show yet',
      LoadPhase.forbidden => 'This content is unavailable for this account',
      LoadPhase.throttled => 'Too many requests. Try again shortly',
      LoadPhase.conflict => 'This changed elsewhere. Refresh to continue',
      LoadPhase.retryableFailure => 'Could not refresh. Retry',
      LoadPhase.terminalFailure => 'This request could not be completed safely',
    };
    if (message == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      label: message,
      child: Row(
        key: Key('state-${phase.name}'),
        children: [
          if (phase == LoadPhase.loading)
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (phase == LoadPhase.loading) const SizedBox(width: 8),
          Expanded(child: Text(message)),
          if (phase == LoadPhase.retryableFailure ||
              phase == LoadPhase.conflict)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
