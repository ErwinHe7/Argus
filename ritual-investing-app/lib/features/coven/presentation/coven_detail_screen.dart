import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/api/state_status.dart';
import '../../../core/bootstrap/member_bootstrap.dart';
import '../../../core/presentation/demo_disclosure.dart';
import '../../rowan/application/controller.dart';
import '../../rowan/domain/model.dart';
import '../../rowan/presentation/rowan_counsel_panel.dart';
import '../application/controller.dart';
import '../domain/model.dart';

class CovenDetailScreen extends StatelessWidget {
  const CovenDetailScreen({
    super.key,
    required this.controller,
    this.rowanController,
    this.personalization = const MemberPersonalization(),
  });

  final CovenDetailController controller;
  final RowanController? rowanController;
  final MemberPersonalization personalization;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Founders’ Coven')),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.company,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    if (value.symbol != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        value.symbol!,
                        style: TextStyle(color: context.ritualColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const DemoBadge(),
            ],
          ),
          const SizedBox(height: 12),
          Text(value.summary, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              key: const Key('coven-save'),
              onPressed: controller.savePhase == CovenSavePhase.saving
                  ? null
                  : controller.toggleSaved,
              icon: Icon(value.saved ? Icons.bookmark : Icons.bookmark_border),
              label: Text(value.saved ? 'Saved' : 'Save Coven entry'),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'Why it qualifies',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(value.inclusionRationale),
          const SizedBox(height: 12),
          for (final qualification in value.qualifications)
            _QualificationCard(qualification: qualification),
          const SizedBox(height: 26),
          Text(
            'Dated evidence',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Qualification evidence is separate from investment research.',
          ),
          const SizedBox(height: 10),
          for (final evidence in value.evidence)
            _EvidenceCard(evidence: evidence),
          const SizedBox(height: 20),
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
                  'Limitations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(value.limitations),
                for (final limitation in value.demo.limitations)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• $limitation'),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${value.demo.sourceLabel} · observed ${_date(value.demo.observedAt)}',
                  style: TextStyle(
                    color: context.ritualColors.faint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (rowanController != null) ...[
            const SizedBox(height: 22),
            RowanCounselPanel(
              controller: rowanController!,
              request: RowanRequest.coven(value.id),
              personalization: personalization,
            ),
          ],
        ],
      ],
    );
  }
}

class _QualificationCard extends StatelessWidget {
  const _QualificationCard({required this.qualification});

  final CovenQualification qualification;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      border: Border.all(color: context.ritualColors.line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _category(qualification.category),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(qualification.personName),
        const SizedBox(height: 4),
        Text(
          'Effective ${_date(qualification.effectiveDate)} · '
          'Verified ${_date(qualification.verifiedAsOf)}',
          style: TextStyle(color: context.ritualColors.muted),
        ),
      ],
    ),
  );
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.evidence});

  final CovenEvidenceDetail evidence;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: context.ritualColors.screenSoft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          evidence.factorLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 5),
        Text(evidence.summary),
        const SizedBox(height: 6),
        Text(
          'Uncertainty: ${evidence.uncertainty}',
          style: TextStyle(color: context.ritualColors.muted),
        ),
        const SizedBox(height: 8),
        Text(
          '${evidence.publisher} · ${evidence.sourceTitle} · '
          'observed ${_date(evidence.observedAt)}',
          style: TextStyle(color: context.ritualColors.faint, fontSize: 12),
        ),
      ],
    ),
  );
}

String _category(CovenQualificationCategory category) => switch (category) {
  CovenQualificationCategory.founder => 'Woman founder',
  CovenQualificationCategory.owner => 'Women-owned',
  CovenQualificationCategory.chiefExecutive => 'Woman chief executive',
};

String _date(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}
