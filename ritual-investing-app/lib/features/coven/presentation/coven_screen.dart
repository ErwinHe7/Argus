import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/api/state_status.dart';
import '../application/controller.dart';
import '../domain/model.dart';

class CovenScreen extends StatelessWidget {
  const CovenScreen({super.key, required this.controller, this.onOpenEntry});
  final CovenController controller;
  final ValueChanged<String>? onOpenEntry;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final colors = context.ritualColors;
    final entries = controller.state.value?.entries ?? const <CovenEntry>[];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Text(
            'Founders’ Coven',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'A demo directory that states exactly why each company belongs.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          StateStatus(phase: controller.state.phase, onRetry: controller.load),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.coven,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.nightlight_round, color: colors.gold, size: 34),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Women-led, precisely labeled.',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'LibreBaskerville',
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Founder, owner, and chief executive are separate inclusion categories. Live data will require dated sources.',
                        style: TextStyle(color: Color(0xFFDCCBDE), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'DEMO DIRECTORY',
            style: TextStyle(
              color: colors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.7,
            ),
          ),
          const SizedBox(height: 6),
          for (final entry in entries)
            _CompanyRow(
              id: entry.id,
              name: entry.name,
              symbol: entry.symbol ?? '—',
              category: entry.category,
              focus: entry.focus,
              effectiveDate: entry.effectiveDate,
              verifiedAsOf: entry.verifiedAsOf,
              onTap: onOpenEntry == null ? null : () => onOpenEntry!(entry.id),
            ),
          const SizedBox(height: 22),
          Text(
            'Seeded examples are fictional and are not investment recommendations.',
            style: TextStyle(color: colors.faint, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _CompanyRow extends StatelessWidget {
  const _CompanyRow({
    required this.id,
    required this.name,
    required this.symbol,
    required this.category,
    required this.focus,
    required this.effectiveDate,
    required this.verifiedAsOf,
    required this.onTap,
  });

  final String id;
  final String name;
  final String symbol;
  final CovenQualificationCategory category;
  final String focus;
  final DateTime effectiveDate;
  final DateTime verifiedAsOf;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ritualColors;
    return InkWell(
      key: Key('coven-entry-$id'),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.screenSoft,
                shape: BoxShape.circle,
              ),
              child: Text(
                symbol.characters.first,
                style: TextStyle(
                  color: colors.gold,
                  fontFamily: 'LibreBaskerville',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        symbol,
                        style: TextStyle(color: colors.faint, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _categoryLabel(category),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$focus · Effective ${_formatDate(effectiveDate)} · verified ${_formatDate(verifiedAsOf)}',
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
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
}

String _categoryLabel(CovenQualificationCategory value) => switch (value) {
  CovenQualificationCategory.founder => 'Woman founder',
  CovenQualificationCategory.owner => 'Women-owned',
  CovenQualificationCategory.chiefExecutive => 'Woman chief executive',
};
