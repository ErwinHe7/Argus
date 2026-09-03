import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

abstract final class DemoDisclosureCopy {
  static const marketScenario =
      'Simulated market scenario · educational exploration only';
}

class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.horizontalPadding = 12});

  final double horizontalPadding;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Simulated experience; no real money moves',
    excludeSemantics: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.ritualColors.goldSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 7,
        ),
        child: Text(
          'SIMULATED',
          style: TextStyle(
            color: context.ritualColors.ink,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    ),
  );
}
