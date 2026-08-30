import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../application/starpath_controller.dart';
import '../domain/starpath.dart';

class StarpathRecallCard extends StatelessWidget {
  const StarpathRecallCard({
    super.key,
    required this.recall,
    required this.controller,
    required this.readOnly,
  });

  final StarpathRecall recall;
  final StarpathController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.ritualColors;
    return Semantics(
      key: const Key('starpath-recall'),
      container: true,
      label: 'Optional factual recall before the current Starpath lesson',
      child: Card(
        color: colors.goldSoft.withValues(alpha: 0.46),
        margin: const EdgeInsets.fromLTRB(20, 6, 20, 22),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A STAR TO REMEMBER',
                style: TextStyle(
                  color: colors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                recall.prompt,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 14),
              for (final option in recall.knowledgeCheck.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: readOnly
                        ? null
                        : () => controller.answer(option.id),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(option.label),
                    ),
                  ),
                ),
              TextButton(
                onPressed: readOnly ? null : controller.skipRecall,
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
