import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/api/state_status.dart';
import '../../../core/presentation/demo_disclosure.dart';
import '../../../core/presentation/minor_money.dart';
import '../../portfolio/application/controller.dart';
import '../../portfolio/domain/model.dart';
import '../application/controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.controller,
    required this.portfolioController,
  });
  final ProfileController controller;
  final PortfolioController portfolioController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, portfolioController]),
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final colors = context.ritualColors;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  excludeSemantics: true,
                  label: controller.state.value == null
                      ? 'Your chamber'
                      : 'Your chamber for ${controller.state.value!.displayName}',
                  child: Text(
                    'Your chamber',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
              ),
              const DemoBadge(horizontalPadding: 11),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'An authenticated simulated portfolio. No money or account is connected.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          StateStatus(phase: controller.state.phase, onRetry: controller.load),
          StateStatus(
            phase: portfolioController.state.phase,
            onRetry: portfolioController.load,
          ),
          if (controller.state.value != null &&
              portfolioController.state.value?.items.isNotEmpty == true) ...[
            const SizedBox(height: 22),
            _PortfolioCard(
              colors: colors,
              portfolio: portfolioController.state.value!.items.first,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.screenSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: colors.gold,
                    foregroundImage: const AssetImage(
                      'assets/images/persona-triptych.png',
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      'Rowan can explain the model. He never decides for you.',
                      style: TextStyle(
                        color: colors.ink,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({required this.colors, required this.portfolio});

  final RitualColors colors;
  final PortfolioSummary portfolio;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          '${portfolio.name}, simulated value ${MinorMoney.usd(portfolio.valuationMinor)}, cash ${MinorMoney.usd(portfolio.cashMinor)}, version ${portfolio.version}, ledger watermark ${portfolio.ledgerWatermark}',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.coven,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SIMULATED BALANCE',
              style: TextStyle(
                color: Color(0xFFDCCBDE),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              MinorMoney.usd(portfolio.valuationMinor),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'LibreBaskerville',
                fontSize: 36,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${portfolio.name} · ${MinorMoney.usd(portfolio.cashMinor)} cash',
              style: TextStyle(color: colors.gold, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
