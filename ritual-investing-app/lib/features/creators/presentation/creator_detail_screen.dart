import 'package:flutter/material.dart';

import '../../../core/api/state_status.dart';
import '../../../core/presentation/demo_disclosure.dart';
import '../application/controller.dart';

class CreatorDetailScreen extends StatelessWidget {
  const CreatorDetailScreen({super.key, required this.controller});

  final CreatorController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Seeded creator')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final value = controller.state.value;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            children: [
              StateStatus(phase: controller.state.phase, onRetry: controller.load),
              if (value != null) ...[
                const Center(
                  child: CircleAvatar(
                    radius: 38,
                    child: Icon(Icons.auto_stories_outlined, size: 34),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  value.displayName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                const Center(child: DemoBadge()),
                const SizedBox(height: 10),
                const Text(
                  'Fictional Demo creator',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Text(value.bio, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 20),
                const Text(
                  'This is a read-only fictional research identity. It is not a public social profile.',
                ),
                const SizedBox(height: 22),
                for (final limitation in value.demo.limitations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $limitation'),
                  ),
                Text(
                  '${value.demo.sourceLabel} · observed ${_date(value.demo.observedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
