import 'package:flutter/material.dart';

import '../../../core/api/view_state.dart';
import '../../../core/bootstrap/member_bootstrap.dart';
import '../application/controller.dart';
import '../domain/model.dart';

class RowanCounselPanel extends StatelessWidget {
  const RowanCounselPanel({
    super.key,
    required this.controller,
    required this.request,
    required this.personalization,
  });

  final RowanController controller;
  final RowanRequest request;
  final MemberPersonalization personalization;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final state = controller.state;
      final matches = controller.request?.cacheKey == request.cacheKey;
      final counsel = matches ? state.value : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            key: const Key('rowan-explain'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: state.phase == LoadPhase.loading
                ? null
                : () => controller.explain(request),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Ask Rowan to explain'),
          ),
          if (matches && state.phase == LoadPhase.loading)
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: LinearProgressIndicator(),
            ),
          if (counsel != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                _voiceLabel(personalization),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Text(counsel.body),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Text(
                counsel.riskFooter,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          if (matches &&
              (state.phase == LoadPhase.empty ||
                  state.phase == LoadPhase.throttled ||
                  state.phase == LoadPhase.retryableFailure))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                state.phase == LoadPhase.throttled
                    ? 'Rowan is resting for a moment. Your research remains available.'
                    : 'Rowan has no counsel for this context right now. Your research remains available.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      );
    },
  );
}

String _voiceLabel(MemberPersonalization personalization) {
  final voice = switch (personalization.ritualVoice) {
    MemberRitualVoice.practical => 'Practical interpretation',
    MemberRitualVoice.mystical => 'Mystical interpretation',
    MemberRitualVoice.balanced => 'Balanced interpretation',
    MemberRitualVoice.unavailable => 'Interpretation',
  };
  final depth = switch (personalization.explanationDepth) {
    MemberExplanationDepth.beginner => ' · more context',
    MemberExplanationDepth.guided => ' · guided context',
    MemberExplanationDepth.advanced => ' · concise context',
    MemberExplanationDepth.unavailable => '',
  };
  return '$voice$depth · script selected by the server';
}
