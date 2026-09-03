import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:simple_icons/simple_icons.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/api/view_state.dart';
import '../../../core/presentation/demo_disclosure.dart';
import '../application/controller.dart';
import '../domain/model.dart';

class AiAnalysisScreen extends StatefulWidget {
  const AiAnalysisScreen({super.key, required this.controller});

  final AiAnalysisController controller;

  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen> {
  String? _selectedPortfolioId;

  @override
  void initState() {
    super.initState();
    if (widget.controller.state.phase == LoadPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.state.phase == LoadPhase.idle) {
          unawaited(widget.controller.load());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final state = widget.controller.state;
      final snapshot = state.value;
      final selectedPortfolio = snapshot == null
          ? null
          : _findPortfolio(snapshot.models, _selectedPortfolioId);
      return Scaffold(
        key: const Key('ai-analysis-screen'),
        appBar: AppBar(
          leading: selectedPortfolio == null
              ? null
              : IconButton(
                  key: const Key('discover-ai-detail-back'),
                  tooltip: 'Back to AI Analysis',
                  onPressed: () => setState(() => _selectedPortfolioId = null),
                  icon: const Icon(Icons.arrow_back),
                ),
          title: Text(
            selectedPortfolio?.name ?? 'AI Analysis',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (selectedPortfolio == null && (snapshot?.isDemo ?? false))
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Center(child: DemoBadge(horizontalPadding: 9)),
              ),
          ],
        ),
        body: SafeArea(
          child: switch (state.phase) {
            LoadPhase.ready when snapshot != null =>
              selectedPortfolio == null
                  ? _ReadyBody(
                      snapshot: snapshot,
                      onOpenPortfolio: (portfolio) =>
                          setState(() => _selectedPortfolioId = portfolio.id),
                    )
                  : _PortfolioDetail(
                      key: ValueKey('detail-${selectedPortfolio.id}'),
                      portfolio: selectedPortfolio,
                    ),
            LoadPhase.retryableFailure ||
            LoadPhase.terminalFailure => _UnavailableBody(
              expired: state.phase == LoadPhase.terminalFailure,
              onRetry: widget.controller.load,
            ),
            LoadPhase.idle || LoadPhase.loading => const _LoadingBody(),
            _ => _UnavailableBody(
              expired: false,
              onRetry: widget.controller.load,
            ),
          },
        ),
      );
    },
  );
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.snapshot, required this.onOpenPortfolio});

  final AiAnalysisSnapshot snapshot;
  final ValueChanged<AiModelPortfolio> onOpenPortfolio;

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('ai-analysis-scroll'),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
    children: [
      Text(
        '${snapshot.sourceLabel} · updated ${_date(snapshot.observedAt)}',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 16),
      _RiskRegimeSection(regime: snapshot.riskRegime),
      const SizedBox(height: 30),
      Column(
        key: const Key('discover-ai-model-list'),
        children: [
          for (final category in AiPortfolioCategory.values) ...[
            _PortfolioCategorySection(
              category: category,
              portfolios: snapshot.models
                  .where((model) => model.category == category)
                  .toList(growable: false),
              onOpenPortfolio: onOpenPortfolio,
            ),
            if (category != AiPortfolioCategory.values.last)
              const SizedBox(height: 28),
          ],
        ],
      ),
      const SizedBox(height: 30),
      _ComparisonRanking(
        portfolios: snapshot.models,
        onOpenPortfolio: onOpenPortfolio,
      ),
      const SizedBox(height: 30),
      _MethodologyNote(snapshot: snapshot),
    ],
  );
}

AiModelPortfolio? _findPortfolio(
  List<AiModelPortfolio> portfolios,
  String? id,
) {
  if (id == null) return null;
  for (final portfolio in portfolios) {
    if (portfolio.id == id) return portfolio;
  }
  return null;
}

class _RiskRegimeSection extends StatefulWidget {
  const _RiskRegimeSection({required this.regime});

  final MarketRiskRegime regime;

  @override
  State<_RiskRegimeSection> createState() => _RiskRegimeSectionState();
}

class _RiskRegimeSectionState extends State<_RiskRegimeSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final regime = widget.regime;
    final colors = context.ritualColors;
    final presentation = _riskPresentation(regime.level, context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Market risk regime, ${regime.levelLabel}',
      child: Material(
        key: const Key('discover-ai-risk-regime'),
        color: presentation.tint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          key: const Key('discover-ai-risk-toggle'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      presentation.icon,
                      color: presentation.foreground,
                      semanticLabel: presentation.iconLabel,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            regime.levelLabel,
                            key: const Key('discover-ai-risk-level'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${regime.activeSignalCount}/${regime.totalSignalCount} signals · valid through ${_date(regime.validThrough)}',
                            key: const Key('discover-ai-risk-summary'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: colors.ink,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 16),
                  Divider(color: colors.line),
                  const SizedBox(height: 8),
                  Text(regime.summary),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      _InlineFact(
                        icon: Icons.radar_outlined,
                        text:
                            '${regime.activeSignalCount}/${regime.totalSignalCount} signals need attention',
                      ),
                      _InlineFact(
                        icon: Icons.schedule_outlined,
                        text: regime.horizon,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'As of ${_timestamp(regime.observedAt)} · valid through ${_timestamp(regime.validThrough)}',
                    key: const Key('discover-ai-risk-as-of'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  for (
                    var index = 0;
                    index < regime.signals.length;
                    index++
                  ) ...[
                    _RiskSignalRow(signal: regime.signals[index]),
                    if (index != regime.signals.length - 1)
                      Divider(color: colors.line),
                  ],
                  const SizedBox(height: 10),
                  _LabeledText(
                    label: 'Validation window',
                    value: regime.validation,
                  ),
                  const SizedBox(height: 10),
                  _LabeledText(
                    label: 'Known limits',
                    value: regime.limitations,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    key: const Key('discover-ai-risk-disclosure'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.screen.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'This is a dated risk regime, not a forecast or crash prediction. Signals can miss, lag, or reverse.',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RiskSignalRow extends StatelessWidget {
  const _RiskSignalRow({required this.signal});

  final MarketRiskSignal signal;

  @override
  Widget build(BuildContext context) {
    final presentation = _signalPresentation(signal.state, context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              presentation.icon,
              color: presentation.foreground,
              semanticLabel: presentation.iconLabel,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${signal.label} · ${_signalLabel(signal.state)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(signal.summary),
                const SizedBox(height: 4),
                Text(
                  '${signal.horizon} · observed ${_date(signal.observedAt)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PortfolioCategorySection extends StatelessWidget {
  const _PortfolioCategorySection({
    required this.category,
    required this.portfolios,
    required this.onOpenPortfolio,
  });

  final AiPortfolioCategory category;
  final List<AiModelPortfolio> portfolios;
  final ValueChanged<AiModelPortfolio> onOpenPortfolio;

  @override
  Widget build(BuildContext context) {
    if (portfolios.isEmpty) return const SizedBox.shrink();
    if (category == AiPortfolioCategory.publicDisclosureTracker) {
      return _PublicFilingSection(
        portfolios: portfolios,
        onOpenPortfolio: onOpenPortfolio,
      );
    }
    final presentation = _categoryPresentation(category);
    return Column(
      key: Key('discover-ai-category-${category.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.ritualColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(presentation.icon, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    presentation.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    presentation.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < portfolios.length; index++) ...[
          _PortfolioRow(
            portfolio: portfolios[index],
            onTap: () => onOpenPortfolio(portfolios[index]),
          ),
          if (index != portfolios.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PublicFilingSection extends StatelessWidget {
  const _PublicFilingSection({
    required this.portfolios,
    required this.onOpenPortfolio,
  });

  final List<AiModelPortfolio> portfolios;
  final ValueChanged<AiModelPortfolio> onOpenPortfolio;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('discover-ai-category-publicDisclosureTracker'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.ritualColors.goldSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.people_alt_outlined,
              size: 22,
              color: context.ritualColors.gold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Money',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Public filings · independently reconstructed',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      for (var index = 0; index < portfolios.length; index++) ...[
        _PublicPortfolioCard(
          portfolio: portfolios[index],
          onTap: () => onOpenPortfolio(portfolios[index]),
        ),
        if (index != portfolios.length - 1) const SizedBox(height: 12),
      ],
    ],
  );
}

class _PublicPortfolioCard extends StatelessWidget {
  const _PublicPortfolioCard({required this.portfolio, required this.onTap});

  final AiModelPortfolio portfolio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ritualColors;
    final figure = _PublicFigurePresentation.fromPortfolio(portfolio);
    final holdings = [...portfolio.holdings]
      ..sort((a, b) => b.weightBps.compareTo(a.weightBps));
    final majorHoldings = holdings.take(2).toList(growable: false);
    final keyPrefix = 'discover-ai-smart-money-${portfolio.id}';
    final legacyPrefix = 'discover-ai-model-${portfolio.id}';

    return Semantics(
      key: Key(keyPrefix),
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      label: _publicPortfolioSemanticLabel(
        portfolio: portfolio,
        figure: figure,
        majorHoldings: majorHoldings,
      ),
      child: Material(
        color: colors.screen,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.line),
        ),
        child: InkWell(
          key: Key(legacyPrefix),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale =
                    MediaQuery.textScalerOf(context).scale(16) / 16;
                final stackContent =
                    constraints.maxWidth < 330 || textScale > 1.35;
                final copy = _PublicPortfolioCardCopy(
                  keyPrefix: keyPrefix,
                  portfolio: portfolio,
                  figure: figure,
                  majorHoldings: majorHoldings,
                );
                final allocation = _HoldingAllocationPortrait(
                  keyPrefix: keyPrefix,
                  portfolio: portfolio,
                  figure: figure,
                  size: stackContent ? 156 : 132,
                );

                if (stackContent) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      copy,
                      const SizedBox(height: 16),
                      Center(child: allocation),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 14),
                    allocation,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicPortfolioCardCopy extends StatelessWidget {
  const _PublicPortfolioCardCopy({
    required this.keyPrefix,
    required this.portfolio,
    required this.figure,
    required this.majorHoldings,
  });

  final String keyPrefix;
  final AiModelPortfolio portfolio;
  final _PublicFigurePresentation figure;
  final List<AiHolding> majorHoldings;

  @override
  Widget build(BuildContext context) {
    final colors = context.ritualColors;
    final isPositive = portfolio.totalReturnBps >= 0;
    final returnColor = isPositive
        ? colors.positive
        : Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _TrackRecordBadge(
              key: Key('discover-ai-model-${portfolio.id}-status'),
              kind: portfolio.trackRecordKind,
            ),
            _SmallBadge(
              key: Key('$keyPrefix-disclosure'),
              label: 'FILING RECONSTRUCTION',
            ),
          ],
        ),
        const SizedBox(height: 11),
        Text(
          figure.personName,
          key: Key('$keyPrefix-person'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.link, size: 16, color: colors.muted),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                figure.entityLabel,
                key: Key('$keyPrefix-entity'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _percentBps(portfolio.totalReturnBps),
          key: Key('discover-ai-model-${portfolio.id}-return'),
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: returnColor, fontFamily: 'Inter'),
        ),
        const SizedBox(height: 1),
        Text(
          'Hypothetical Leo return',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: colors.muted),
        ),
        const SizedBox(height: 3),
        Text(
          _period(portfolio.start, portfolio.end),
          key: Key('discover-ai-model-${portfolio.id}-period'),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.muted),
        ),
        const SizedBox(height: 12),
        Text(
          'Major disclosed positions',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: colors.ink, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        for (final holding in majorHoldings)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _PublicHoldingSummary(
              key: Key('$keyPrefix-holding-${holding.id}'),
              holding: holding,
              logoKey: Key('$keyPrefix-holding-${holding.id}-logo'),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          'Disclosure as of ${_date(portfolio.sourceDataAsOf)}',
          key: Key('$keyPrefix-updated'),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.muted),
        ),
      ],
    );
  }
}

class _PublicHoldingSummary extends StatelessWidget {
  const _PublicHoldingSummary({
    super.key,
    required this.holding,
    required this.logoKey,
  });

  final AiHolding holding;
  final Key logoKey;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      _CompanyLogoAvatar(key: logoKey, holding: holding, size: 30),
      const SizedBox(width: 7),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              holding.symbol,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.ritualColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              holding.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.ritualColors.muted),
            ),
          ],
        ),
      ),
      const SizedBox(width: 5),
      Text(
        _percentBps(holding.weightBps),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.ritualColors.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _CompanyLogoAvatar extends StatelessWidget {
  const _CompanyLogoAvatar({
    super.key,
    required this.holding,
    required this.size,
  });

  final AiHolding holding;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brand = _companyBrandForSymbol(holding.symbol);
    final colors = context.ritualColors;
    final rawColor =
        brand?.color ?? _fallbackTickerColor(holding.symbol, colors);
    final background = Color.alphaBlend(
      rawColor.withValues(alpha: brand == null ? .16 : .12),
      colors.screen,
    );
    final foreground = _ensureNonTextContrast(
      foreground: rawColor,
      background: background,
      brightness: Theme.of(context).brightness,
    );
    final radius = math.min(12.0, size * .25);
    return Semantics(
      image: true,
      label: brand == null
          ? '${holding.name}, ticker ${holding.symbol}'
          : '${holding.name} brand mark, used only to identify the holding',
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: colors.line),
          ),
          child: brand == null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _fallbackTickerMark(holding.symbol),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.2,
                      ),
                    ),
                  ),
                )
              : Icon(brand.icon, size: size * .56, color: foreground),
        ),
      ),
    );
  }
}

class _CompanyBrand {
  const _CompanyBrand({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

_CompanyBrand? _companyBrandForSymbol(String symbol) {
  return switch (symbol.trim().toUpperCase()) {
    'AAPL' => const _CompanyBrand(
      icon: SimpleIcons.apple,
      color: SimpleIconColors.apple,
    ),
    'AXP' => const _CompanyBrand(
      icon: SimpleIcons.americanexpress,
      color: SimpleIconColors.americanexpress,
    ),
    'AVGO' => const _CompanyBrand(
      icon: SimpleIcons.broadcom,
      color: SimpleIconColors.broadcom,
    ),
    'BAC' => const _CompanyBrand(
      icon: SimpleIcons.bankofamerica,
      color: SimpleIconColors.bankofamerica,
    ),
    'COIN' => const _CompanyBrand(
      icon: SimpleIcons.coinbase,
      color: SimpleIconColors.coinbase,
    ),
    'EA' => const _CompanyBrand(
      icon: SimpleIcons.ea,
      color: SimpleIconColors.ea,
    ),
    'GOOG' || 'GOOGL' => const _CompanyBrand(
      icon: SimpleIcons.google,
      color: SimpleIconColors.google,
    ),
    'JPM' => const _CompanyBrand(
      icon: SimpleIcons.chase,
      color: SimpleIconColors.chase,
    ),
    'KO' => const _CompanyBrand(
      icon: SimpleIcons.cocacola,
      color: SimpleIconColors.cocacola,
    ),
    'META' => const _CompanyBrand(
      icon: SimpleIcons.meta,
      color: SimpleIconColors.meta,
    ),
    'NVDA' || 'NVIDIA' => const _CompanyBrand(
      icon: SimpleIcons.nvidia,
      color: SimpleIconColors.nvidia,
    ),
    'PLTR' => const _CompanyBrand(
      icon: SimpleIcons.palantir,
      color: SimpleIconColors.palantir,
    ),
    'ROKU' => const _CompanyBrand(
      icon: SimpleIcons.roku,
      color: SimpleIconColors.roku,
    ),
    'TSLA' => const _CompanyBrand(
      icon: SimpleIcons.tesla,
      color: SimpleIconColors.tesla,
    ),
    'V' => const _CompanyBrand(
      icon: SimpleIcons.visa,
      color: SimpleIconColors.visa,
    ),
    _ => null,
  };
}

Color _fallbackTickerColor(String symbol, RitualColors colors) {
  final mapped = _tickerBrandColors[symbol.trim().toUpperCase()];
  if (mapped != null) return mapped;
  final palette = [
    colors.gold,
    colors.positive,
    colors.primarySoft,
    colors.muted,
  ];
  final hash = symbol.codeUnits.fold<int>(0, (sum, value) => sum + value);
  return palette[hash % palette.length];
}

String _fallbackTickerMark(String symbol) {
  final normalized = symbol.trim().toUpperCase().replaceAll(
    RegExp('[^A-Z0-9]'),
    '',
  );
  if (normalized.length <= 4) return normalized;
  return normalized.substring(0, 3);
}

const _tickerBrandColors = <String, Color>{
  'AMZN': Color(0xFFFF9900),
  'ASML': Color(0xFF0B3C82),
  'BE': Color(0xFF00866A),
  'BRK.B': Color(0xFF1B3A57),
  'COST': Color(0xFFE31837),
  'CRSP': Color(0xFF64358C),
  'JNJ': Color(0xFFD71920),
  'MSFT': Color(0xFF0078D4),
  'MU': Color(0xFF0057B8),
  'NBIS': Color(0xFF4D56D8),
  'OXY': Color(0xFFD9272E),
  'PG': Color(0xFF003DA5),
  'SNDK': Color(0xFFE31B23),
  'TSM': Color(0xFFC8102E),
  'UNH': Color(0xFF005EB8),
  'WMT': Color(0xFF0071CE),
  'XOM': Color(0xFFED1B2F),
};

Color _ensureNonTextContrast({
  required Color foreground,
  required Color background,
  required Brightness brightness,
}) {
  var candidate = foreground;
  final target = brightness == Brightness.dark ? Colors.white : Colors.black;
  for (var attempt = 0; attempt < 8; attempt++) {
    if (_contrastRatio(candidate, background) >= 3) return candidate;
    candidate = Color.lerp(candidate, target, .16)!;
  }
  return candidate;
}

double _contrastRatio(Color first, Color second) {
  final lighter = math.max(first.computeLuminance(), second.computeLuminance());
  final darker = math.min(first.computeLuminance(), second.computeLuminance());
  return (lighter + .05) / (darker + .05);
}

class _HoldingAllocationPortrait extends StatelessWidget {
  const _HoldingAllocationPortrait({
    required this.keyPrefix,
    required this.portfolio,
    required this.figure,
    required this.size,
  });

  final String keyPrefix;
  final AiModelPortfolio portfolio;
  final _PublicFigurePresentation figure;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.ritualColors;
    final sortedHoldings = [...portfolio.holdings]
      ..sort((a, b) => b.weightBps.compareTo(a.weightBps));
    final textScale = MediaQuery.textScalerOf(context).scale(11) / 11;
    final visibleTickerCount = textScale > 1.5 ? 2 : 4;
    final visibleHoldings = sortedHoldings
        .take(math.min(visibleTickerCount, sortedHoldings.length))
        .toList(growable: false);
    final segmentColors = <Color>[
      Theme.of(context).colorScheme.primary,
      colors.gold,
      colors.positive,
      colors.coven,
      colors.muted,
    ];
    return Semantics(
      key: Key('$keyPrefix-allocation'),
      image: true,
      label:
          '${figure.personName} portrait surrounded by a holding allocation chart',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _HoldingAllocationPainter(
                  weightsBps: portfolio.holdings
                      .map((holding) => holding.weightBps)
                      .toList(growable: false),
                  segmentColors: segmentColors,
                  trackColor: colors.screenSoft,
                ),
              ),
            ),
            Container(
              key: Key('$keyPrefix-portrait'),
              width: size * .57,
              height: size * .57,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.screenSoft,
                border: Border.all(color: colors.screen, width: 3),
              ),
              clipBehavior: Clip.antiAlias,
              child: _PortraitImage(figure: figure),
            ),
            for (var index = 0; index < visibleHoldings.length; index++)
              Align(
                alignment: _tickerAlignment(index, visibleHoldings.length),
                child: ExcludeSemantics(
                  child: _CompanyLogoAvatar(
                    key: Key(
                      '$keyPrefix-ticker-${visibleHoldings[index].symbol}',
                    ),
                    holding: visibleHoldings[index],
                    size: textScale > 1.5 ? 34 : 30,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Alignment _tickerAlignment(int index, int count) {
  if (count <= 2) {
    return index == 0 ? const Alignment(-.72, -.72) : const Alignment(.72, .72);
  }
  return switch (index) {
    0 => const Alignment(-.68, -.76),
    1 => const Alignment(.78, -.12),
    2 => const Alignment(.48, .76),
    _ => const Alignment(-.78, .32),
  };
}

class _PortraitImage extends StatelessWidget {
  const _PortraitImage({required this.figure});

  final _PublicFigurePresentation figure;

  @override
  Widget build(BuildContext context) {
    final assetPath = figure.portraitAssetPath;
    if (assetPath == null) return _PortraitFallback(name: figure.personName);
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      errorBuilder: (context, error, stackTrace) =>
          _PortraitFallback(name: figure.personName),
    );
  }
}

class _PortraitFallback extends StatelessWidget {
  const _PortraitFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.ritualColors.primarySoft,
    child: Center(
      child: Text(
        _initials(name),
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: context.ritualColors.ink),
      ),
    ),
  );
}

class _HoldingAllocationPainter extends CustomPainter {
  const _HoldingAllocationPainter({
    required this.weightsBps,
    required this.segmentColors,
    required this.trackColor,
  });

  final List<int> weightsBps;
  final List<Color> segmentColors;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final strokeWidth = size.shortestSide * .18;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final total = weightsBps.fold<int>(0, (sum, value) => sum + value);
    if (total <= 0 || segmentColors.isEmpty) return;
    const gap = .035;
    var startAngle = -math.pi / 2;
    for (var index = 0; index < weightsBps.length; index++) {
      final sweep = weightsBps[index] / total * math.pi * 2;
      final paint = Paint()
        ..color = segmentColors[index % segmentColors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        rect,
        startAngle + gap / 2,
        math.max(.01, sweep - gap),
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _HoldingAllocationPainter oldDelegate) =>
      oldDelegate.weightsBps != weightsBps ||
      oldDelegate.segmentColors != segmentColors ||
      oldDelegate.trackColor != trackColor;
}

class _PublicFigurePresentation {
  const _PublicFigurePresentation({
    required this.personName,
    required this.entityLabel,
    required this.portraitAssetPath,
  });

  factory _PublicFigurePresentation.fromPortfolio(AiModelPortfolio portfolio) =>
      _PublicFigurePresentation(
        personName: portfolio.publicFigureName ?? portfolio.name,
        entityLabel: portfolio.publicFigureRole ?? portfolio.name,
        portraitAssetPath: portfolio.portraitAssetPath,
      );

  final String personName;
  final String entityLabel;
  final String? portraitAssetPath;
}

String _publicPortfolioSemanticLabel({
  required AiModelPortfolio portfolio,
  required _PublicFigurePresentation figure,
  required List<AiHolding> majorHoldings,
}) {
  final holdings = majorHoldings
      .map((holding) => '${holding.name}, ${_percentBps(holding.weightBps)}')
      .join('; ');
  return '${figure.personName}, ${figure.entityLabel}. '
      'Hypothetical Leo return ${_percentBps(portfolio.totalReturnBps)}, '
      '${_period(portfolio.start, portfolio.end)}. '
      'Major disclosed positions: $holdings. '
      'Disclosure as of ${_date(portfolio.sourceDataAsOf)}. '
      'Filing reconstruction. Open details.';
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.characters.first.toUpperCase();
  return '${words.first.characters.first}${words.last.characters.first}'
      .toUpperCase();
}

class _PortfolioRow extends StatelessWidget {
  const _PortfolioRow({required this.portfolio, required this.onTap});

  final AiModelPortfolio portfolio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ritualColors;
    final prefix = 'discover-ai-model-${portfolio.id}';
    return Material(
      color: colors.screen,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.line),
      ),
      child: InkWell(
        key: Key(prefix),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 10, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PortfolioOverviewIdentity(portfolio: portfolio, prefix: prefix),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _TrackRecordBadge(
                    key: Key('$prefix-status'),
                    kind: portfolio.trackRecordKind,
                  ),
                  _SmallBadge(
                    label:
                        portfolio.category ==
                            AiPortfolioCategory.publicDisclosureTracker
                        ? 'FILING-BASED'
                        : 'HYPOTHETICAL',
                  ),
                  if (portfolio.category == AiPortfolioCategory.aiSimulation)
                    const _SmallBadge(label: 'UNOFFICIAL'),
                  if (portfolio.category ==
                      AiPortfolioCategory.publicDisclosureTracker)
                    const _SmallBadge(label: 'DISCLOSURE'),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 18,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    key: Key('$prefix-return'),
                    width: 112,
                    child: _CompactValue(
                      value: _percentBps(portfolio.totalReturnBps),
                      label: 'Total return',
                    ),
                  ),
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 108,
                      height: 48,
                      child: CustomPaint(
                        painter: _ReturnSparklinePainter(
                          values: portfolio.returnSeriesBps,
                          lineColor: Theme.of(context).colorScheme.primary,
                          baselineColor: colors.line,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 156,
                    child: Text(
                      _period(portfolio.start, portfolio.end),
                      key: Key('$prefix-period'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  SizedBox(
                    key: Key('$prefix-benchmark'),
                    width: 210,
                    child: _CompactValue(
                      value: _percentBps(portfolio.benchmarkReturnBps),
                      label: portfolio.benchmarkLabel,
                    ),
                  ),
                  SizedBox(
                    key: Key('$prefix-max-drawdown'),
                    width: 128,
                    child: _CompactValue(
                      value: _percentBps(-portfolio.maxDrawdownMagnitudeBps),
                      label: 'Max drawdown',
                    ),
                  ),
                ],
              ),
              if (portfolio.category ==
                  AiPortfolioCategory.publicDisclosureTracker) ...[
                const SizedBox(height: 10),
                Text(
                  'Disclosure data as of ${_date(portfolio.sourceDataAsOf)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PortfolioOverviewIdentity extends StatelessWidget {
  const _PortfolioOverviewIdentity({
    required this.portfolio,
    required this.prefix,
  });

  final AiModelPortfolio portfolio;
  final String prefix;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final stackContent = constraints.maxWidth < 330 || textScale > 1.35;
      final cover = _PortfolioVisual(
        key: Key('$prefix-cover'),
        portfolio: portfolio,
        size: stackContent ? 104 : 92,
      );
      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  portfolio.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            portfolio.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          _CompanyLogoStrip(
            key: Key('$prefix-company-logos'),
            keyPrefix: '$prefix-company-logo',
            holdings: portfolio.holdings,
            avatarSize: 30,
          ),
        ],
      );

      if (stackContent) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [cover, const SizedBox(height: 12), copy],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cover,
          const SizedBox(width: 12),
          Expanded(child: copy),
        ],
      );
    },
  );
}

class _PortfolioVisual extends StatelessWidget {
  const _PortfolioVisual({
    super.key,
    required this.portfolio,
    required this.size,
  });

  final AiModelPortfolio portfolio;
  final double size;

  @override
  Widget build(BuildContext context) {
    final category = _categoryPresentation(portfolio.category);
    final assetPath = portfolio.visualAssetPath;
    final fallback = _PortfolioVisualFallback(icon: category.icon, size: size);
    return Semantics(
      image: true,
      label: '${portfolio.name} strategy visual',
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.ritualColors.screenSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.ritualColors.line),
        ),
        child: assetPath == null
            ? fallback
            : Image.asset(
                assetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }
}

class _PortfolioVisualFallback extends StatelessWidget {
  const _PortfolioVisualFallback({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Center(
    child: Icon(
      icon,
      size: size * .38,
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}

class _CompanyLogoStrip extends StatelessWidget {
  const _CompanyLogoStrip({
    super.key,
    required this.keyPrefix,
    required this.holdings,
    required this.avatarSize,
  });

  final String keyPrefix;
  final List<AiHolding> holdings;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final sortedHoldings = [...holdings]
      ..sort((a, b) => b.weightBps.compareTo(a.weightBps));
    final visible = sortedHoldings.take(4).toList(growable: false);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final holding in visible)
          _CompanyLogoAvatar(
            key: Key('$keyPrefix-${holding.id}'),
            holding: holding,
            size: avatarSize,
          ),
        if (sortedHoldings.length > visible.length)
          Text(
            '+${sortedHoldings.length - visible.length}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: context.ritualColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: context.ritualColors.screenSoft,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.ritualColors.ink,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _CompactValue extends StatelessWidget {
  const _CompactValue({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 2),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _ComparisonRanking extends StatelessWidget {
  const _ComparisonRanking({
    required this.portfolios,
    required this.onOpenPortfolio,
  });

  final List<AiModelPortfolio> portfolios;
  final ValueChanged<AiModelPortfolio> onOpenPortfolio;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<AiModelPortfolio>>{};
    for (final portfolio in portfolios.where(
      (item) => item.category != AiPortfolioCategory.publicDisclosureTracker,
    )) {
      groups
          .putIfAbsent(_period(portfolio.start, portfolio.end), () => [])
          .add(portfolio);
    }
    for (final group in groups.values) {
      group.sort((a, b) => b.totalReturnBps.compareTo(a.totalReturnBps));
    }
    return Column(
      key: const Key('discover-ai-comparison-ranking'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comparison ranking',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Leo and AI experiments are ranked only when their exact dates match. Public-filing reconstructions are excluded.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        for (final entry in groups.entries) ...[
          Text(entry.key, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          for (var index = 0; index < entry.value.length; index++)
            InkWell(
              key: Key('discover-ai-ranking-${entry.value[index].id}'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => onOpenPortfolio(entry.value[index]),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${index + 1}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.value[index].name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            entry.value[index].categoryLabel,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _percentBps(entry.value[index].totalReturnBps),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

enum _ReturnWindow { threeMonths, sixMonths, oneYear }

extension on _ReturnWindow {
  String get label => switch (this) {
    _ReturnWindow.threeMonths => '3M',
    _ReturnWindow.sixMonths => '6M',
    _ReturnWindow.oneYear => '1Y',
  };

  int get months => switch (this) {
    _ReturnWindow.threeMonths => 3,
    _ReturnWindow.sixMonths => 6,
    _ReturnWindow.oneYear => 12,
  };
}

class _PortfolioDetail extends StatefulWidget {
  const _PortfolioDetail({super.key, required this.portfolio});

  final AiModelPortfolio portfolio;

  @override
  State<_PortfolioDetail> createState() => _PortfolioDetailState();
}

class _PortfolioDetailState extends State<_PortfolioDetail> {
  _ReturnWindow _window = _ReturnWindow.oneYear;
  int _investmentAmount = 5000;

  @override
  Widget build(BuildContext context) {
    final portfolio = widget.portfolio;
    final prefix = 'discover-ai-model-${portfolio.id}';
    final windowData = _windowData(portfolio, _window);
    return ListView(
      key: Key('discover-ai-detail-${portfolio.id}'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        _DetailHeader(portfolio: portfolio),
        const SizedBox(height: 24),
        _PerformanceChartSection(
          portfolio: portfolio,
          prefix: prefix,
          selectedWindow: _window,
          data: windowData,
          onSelectWindow: (value) => setState(() => _window = value),
        ),
        const SizedBox(height: 28),
        _ReturnCalculator(
          portfolio: portfolio,
          windowData: windowData,
          amount: _investmentAmount,
          onAmountChanged: (value) => setState(() => _investmentAmount = value),
        ),
        const SizedBox(height: 32),
        _HoldingsSection(portfolio: portfolio, prefix: prefix),
        if (portfolio.sectorAllocations.isNotEmpty) ...[
          const SizedBox(height: 32),
          _SectorAllocationSection(portfolio: portfolio),
        ],
        const SizedBox(height: 32),
        _AssumptionsSection(portfolio: portfolio),
        const SizedBox(height: 26),
        _PortfolioDisclosure(portfolio: portfolio, prefix: prefix),
      ],
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.portfolio});

  final AiModelPortfolio portfolio;

  @override
  Widget build(BuildContext context) {
    final isPublic =
        portfolio.category == AiPortfolioCategory.publicDisclosureTracker;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isPublic)
          _PublicDetailIdentity(portfolio: portfolio)
        else
          _NonPublicDetailIdentity(portfolio: portfolio),
        const SizedBox(height: 8),
        Text(portfolio.summary, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _TrackRecordBadge(kind: portfolio.trackRecordKind),
            _SmallBadge(
              label:
                  portfolio.category ==
                      AiPortfolioCategory.publicDisclosureTracker
                  ? 'FILING-BASED'
                  : 'HYPOTHETICAL',
            ),
            _SmallBadge(label: portfolio.holdingsBasisLabel.toUpperCase()),
          ],
        ),
        if (portfolio.category ==
            AiPortfolioCategory.publicDisclosureTracker) ...[
          const SizedBox(height: 12),
          Text(
            'Report date ${_date(portfolio.sourceDataAsOf)} · reconstruction dated ${_date(portfolio.holdingsAsOf)}',
            key: Key('discover-ai-disclosure-date-${portfolio.id}'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Text(
            portfolio.sourceDisclosure,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class _NonPublicDetailIdentity extends StatelessWidget {
  const _NonPublicDetailIdentity({required this.portfolio});

  final AiModelPortfolio portfolio;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final stackContent = constraints.maxWidth < 330 || textScale > 1.35;
      final prefix = 'discover-ai-detail-${portfolio.id}';
      final visual = _PortfolioVisual(
        key: Key('$prefix-cover'),
        portfolio: portfolio,
        size: stackContent ? 104 : 110,
      );
      final identity = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            portfolio.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          _CompanyLogoStrip(
            key: Key('$prefix-company-logos'),
            keyPrefix: '$prefix-company-logo',
            holdings: portfolio.holdings,
            avatarSize: 34,
          ),
        ],
      );

      if (stackContent) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [visual, const SizedBox(height: 14), identity],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          visual,
          const SizedBox(width: 16),
          Expanded(child: identity),
        ],
      );
    },
  );
}

class _PublicDetailIdentity extends StatelessWidget {
  const _PublicDetailIdentity({required this.portfolio});

  final AiModelPortfolio portfolio;

  @override
  Widget build(BuildContext context) {
    final figure = _PublicFigurePresentation.fromPortfolio(portfolio);
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final stackContent = constraints.maxWidth < 330 || textScale > 1.35;
        final identity = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              figure.personName,
              key: Key('discover-ai-detail-person-${portfolio.id}'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.link, size: 18, color: context.ritualColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    figure.entityLabel,
                    key: Key('discover-ai-detail-entity-${portfolio.id}'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
        final allocation = _HoldingAllocationPortrait(
          keyPrefix: 'discover-ai-detail-smart-money-${portfolio.id}',
          portfolio: portfolio,
          figure: figure,
          size: stackContent ? 132 : 116,
        );

        if (stackContent) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [identity, const SizedBox(height: 14), allocation],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: identity),
            const SizedBox(width: 16),
            allocation,
          ],
        );
      },
    );
  }
}

class _PerformanceChartSection extends StatelessWidget {
  const _PerformanceChartSection({
    required this.portfolio,
    required this.prefix,
    required this.selectedWindow,
    required this.data,
    required this.onSelectWindow,
  });

  final AiModelPortfolio portfolio;
  final String prefix;
  final _ReturnWindow selectedWindow;
  final _WindowData data;
  final ValueChanged<_ReturnWindow> onSelectWindow;

  @override
  Widget build(BuildContext context) {
    final colors = context.ritualColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historical return',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _period(data.start, portfolio.end),
                    key: Key('$prefix-period'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _percentBps(data.portfolioReturnBps),
              key: Key('$prefix-return'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in _ReturnWindow.values)
              ChoiceChip(
                key: Key(
                  'discover-ai-detail-${portfolio.id}-window-${value.label.toLowerCase()}',
                ),
                label: Text(value.label),
                selected: value == selectedWindow,
                onSelected: (_) => onSelectWindow(value),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          key: Key('discover-ai-detail-${portfolio.id}-chart'),
          height: 230,
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
          decoration: BoxDecoration(
            color: colors.screen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ExcludeSemantics(
            child: CustomPaint(
              painter: _ComparisonChartPainter(
                portfolioValues: data.portfolioSeries,
                benchmarkValues: data.benchmarkSeries,
                portfolioColor: Theme.of(context).colorScheme.primary,
                benchmarkColor: colors.gold,
                gridColor: colors.line,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            _Legend(
              label: portfolio.name,
              color: Theme.of(context).colorScheme.primary,
            ),
            _Legend(label: portfolio.benchmarkLabel, color: colors.gold),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 20,
          runSpacing: 14,
          children: [
            _Metric(
              label: 'Portfolio return',
              value: _percentBps(data.portfolioReturnBps),
              icon: Icons.show_chart,
            ),
            _Metric(
              key: Key('$prefix-benchmark'),
              label: portfolio.benchmarkLabel,
              value: data.benchmarkReturnBps == null
                  ? 'Unavailable'
                  : _percentBps(data.benchmarkReturnBps!),
              icon: Icons.stacked_line_chart,
            ),
            _Metric(
              key: Key('$prefix-max-drawdown'),
              label: 'Max drawdown',
              value: _percentBps(-portfolio.maxDrawdownMagnitudeBps),
              icon: Icons.south_east,
            ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 260),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 18, height: 3, color: color),
        const SizedBox(width: 7),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 136, maxWidth: 210),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: context.ritualColors.muted),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.titleMedium),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReturnCalculator extends StatelessWidget {
  const _ReturnCalculator({
    required this.portfolio,
    required this.windowData,
    required this.amount,
    required this.onAmountChanged,
  });

  final AiModelPortfolio portfolio;
  final _WindowData windowData;
  final int amount;
  final ValueChanged<int> onAmountChanged;

  @override
  Widget build(BuildContext context) {
    final endingValue = amount * (1 + windowData.portfolioReturnBps / 10000);
    final change = endingValue - amount;
    return Container(
      key: Key('discover-ai-detail-${portfolio.id}-calculator'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.ritualColors.screenSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historical return calculator',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'What a hypothetical starting amount would have become during the selected recorded period.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in const [1000, 5000, 10000])
                ChoiceChip(
                  key: Key('discover-ai-detail-${portfolio.id}-amount-$value'),
                  label: Text(_currency(value.toDouble())),
                  selected: amount == value,
                  onSelected: (_) => onAmountChanged(value),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              _CompactValue(
                value: _currency(amount.toDouble()),
                label: 'Starting amount',
              ),
              _CompactValue(
                value: _currency(endingValue),
                label: 'Hypothetical ending value',
              ),
              _CompactValue(
                value: '${change >= 0 ? '+' : '−'}${_currency(change.abs())}',
                label:
                    '${_period(windowData.start, portfolio.end)} historical change',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Hypothetical only. This does not project future returns and excludes your taxes and personal costs.',
          ),
        ],
      ),
    );
  }
}

class _HoldingsSection extends StatelessWidget {
  const _HoldingsSection({required this.portfolio, required this.prefix});

  final AiModelPortfolio portfolio;
  final String prefix;

  @override
  Widget build(BuildContext context) => Column(
    key: Key('$prefix-holdings'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Holdings', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 5),
      Text(
        'Holdings as of ${_date(portfolio.holdingsAsOf)}',
        key: Key('$prefix-holdings-as-of'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 4),
      Text(
        portfolio.holdingsBasisLabel,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: 4),
      Text(
        'Company marks identify holdings only; no affiliation or endorsement is implied.',
        key: Key('$prefix-logo-disclosure'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      for (var index = 0; index < portfolio.holdings.length; index++) ...[
        _HoldingRow(
          key: Key('$prefix-holding-${portfolio.holdings[index].id}'),
          holding: portfolio.holdings[index],
          logoKey: Key('$prefix-holding-${portfolio.holdings[index].id}-logo'),
        ),
        if (index != portfolio.holdings.length - 1)
          Divider(color: context.ritualColors.line),
      ],
    ],
  );
}

class _HoldingRow extends StatelessWidget {
  const _HoldingRow({super.key, required this.holding, required this.logoKey});

  final AiHolding holding;
  final Key logoKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CompanyLogoAvatar(key: logoKey, holding: holding, size: 52),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      holding.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _weightBps(holding.weightBps),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                holding.rationale,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectorAllocationSection extends StatelessWidget {
  const _SectorAllocationSection({required this.portfolio});

  final AiModelPortfolio portfolio;

  @override
  Widget build(BuildContext context) {
    final palette = _sectorPalette(context);
    return Column(
      key: Key('discover-ai-detail-${portfolio.id}-sectors'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sector allocation',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'A compact view of where the tracked weights are concentrated.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 18,
            child: Row(
              children: [
                for (
                  var index = 0;
                  index < portfolio.sectorAllocations.length;
                  index++
                )
                  Expanded(
                    flex: portfolio.sectorAllocations[index].weightBps,
                    child: ColoredBox(color: palette[index % palette.length]),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < portfolio.sectorAllocations.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: palette[index % palette.length],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(portfolio.sectorAllocations[index].label)),
                const SizedBox(width: 12),
                Text(
                  _weightBps(portfolio.sectorAllocations[index].weightBps),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AssumptionsSection extends StatelessWidget {
  const _AssumptionsSection({required this.portfolio});

  final AiModelPortfolio portfolio;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'How this record was built',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 10),
      _DetailRow(
        label: 'Version',
        value: _displayVersion(portfolio.modelVersion),
      ),
      _DetailRow(label: 'Universe', value: portfolio.selectionUniverse),
      _DetailRow(label: 'Cadence', value: portfolio.cadence),
      _DetailRow(
        label: 'Costs',
        value:
            '${portfolio.dividendsIncluded ? 'Dividends included' : 'Dividends excluded'} · ${portfolio.feeAssumption}',
      ),
      _DetailRow(
        label: '${portfolio.bestPeriodLabel} / ${portfolio.worstPeriodLabel}',
        value:
            '${_percentBps(portfolio.bestQuarterBps)} / ${_percentBps(portfolio.worstQuarterBps)}',
      ),
      _DetailRow(
        label: 'Source data',
        value: 'As of ${_date(portfolio.sourceDataAsOf)}',
      ),
    ],
  );
}

class _PortfolioDisclosure extends StatelessWidget {
  const _PortfolioDisclosure({required this.portfolio, required this.prefix});

  final AiModelPortfolio portfolio;
  final String prefix;

  @override
  Widget build(BuildContext context) => Container(
    key: Key('$prefix-disclosure'),
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.ritualColors.goldSoft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.fact_check_outlined, size: 21),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Read before comparing',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(portfolio.affiliationDisclosure),
        const SizedBox(height: 8),
        Text(portfolio.sourceDisclosure),
        const SizedBox(height: 8),
        const Text(
          'Backtests and paper results are hypothetical. Live and historical performance do not guarantee future results. This is research, not a recommendation to buy or sell.',
        ),
      ],
    ),
  );
}

class _TrackRecordBadge extends StatelessWidget {
  const _TrackRecordBadge({super.key, required this.kind});

  final AiTrackRecordKind kind;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: context.ritualColors.primarySoft,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      _trackRecordLabel(kind),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.ritualColors.ink,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Wrap(
      spacing: 12,
      runSpacing: 3,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(value),
        ),
      ],
    ),
  );
}

class _LabeledText extends StatelessWidget {
  const _LabeledText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 3),
      Text(value),
    ],
  );
}

class _InlineFact extends StatelessWidget {
  const _InlineFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: context.ritualColors.muted),
      const SizedBox(width: 6),
      Flexible(child: Text(text)),
    ],
  );
}

class _MethodologyNote extends StatelessWidget {
  const _MethodologyNote({required this.snapshot});

  final AiAnalysisSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Coverage limits', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      for (final limitation in snapshot.limitations)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text('• $limitation'),
        ),
      const SizedBox(height: 8),
      Text(
        'Method ${_displayVersion(snapshot.methodologyVersion)} · snapshot observed ${_timestamp(snapshot.observedAt)} · available ${_timestamp(snapshot.availableAt)} · expires ${_timestamp(snapshot.expiresAt)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

String _displayVersion(String value) =>
    value.replaceAll('-demo-', '-research-').replaceAll('demo-', 'research-');

class _CategoryPresentation {
  const _CategoryPresentation({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

_CategoryPresentation _categoryPresentation(AiPortfolioCategory category) =>
    switch (category) {
      AiPortfolioCategory.leoModel => const _CategoryPresentation(
        title: 'Leo Models',
        description: 'Rules-based Leo research with fixed assumptions and same-period benchmarks.',
        icon: Icons.auto_awesome_outlined,
      ),
      AiPortfolioCategory.aiSimulation => const _CategoryPresentation(
        title: 'AI Model Experiments',
        description: 'Unofficial historical simulations. They are not provider track records or endorsements.',
        icon: Icons.memory_outlined,
      ),
      AiPortfolioCategory.publicDisclosureTracker =>
        const _CategoryPresentation(
          title: 'Public Filing Reconstructions',
          description: 'Delayed public filings reconstructed into dated examples—not current holdings.',
          icon: Icons.description_outlined,
        ),
    };

class _WindowData {
  const _WindowData({
    required this.start,
    required this.portfolioSeries,
    required this.benchmarkSeries,
    required this.portfolioReturnBps,
    required this.benchmarkReturnBps,
  });

  final DateTime start;
  final List<int> portfolioSeries;
  final List<int> benchmarkSeries;
  final int portfolioReturnBps;
  final int? benchmarkReturnBps;
}

_WindowData _windowData(AiModelPortfolio portfolio, _ReturnWindow window) {
  final values = portfolio.returnSeriesBps;
  final target = DateTime.utc(
    portfolio.end.year,
    portfolio.end.month - window.months,
    portfolio.end.day,
  );
  final actualStart = target.isAfter(portfolio.start)
      ? target
      : portfolio.start;
  final totalMicros = portfolio.end.difference(portfolio.start).inMicroseconds;
  final elapsedMicros = actualStart.difference(portfolio.start).inMicroseconds;
  final rawIndex = totalMicros <= 0
      ? 0
      : (elapsedMicros / totalMicros * (values.length - 1)).ceil();
  final startIndex = rawIndex.clamp(0, values.length - 1);
  final modelSlice = values.sublist(startIndex);
  final modelSeries = _rebaseSeries(modelSlice);

  var benchmarkSeries = const <int>[];
  int? benchmarkReturn;
  if (portfolio.benchmarkReturnSeriesBps.length == values.length) {
    final benchmarkSlice = portfolio.benchmarkReturnSeriesBps.sublist(
      startIndex,
    );
    benchmarkSeries = _rebaseSeries(benchmarkSlice);
    benchmarkReturn = benchmarkSeries.last;
  }

  return _WindowData(
    start: actualStart,
    portfolioSeries: modelSeries,
    benchmarkSeries: benchmarkSeries,
    portfolioReturnBps: modelSeries.last,
    benchmarkReturnBps: benchmarkReturn,
  );
}

List<int> _rebaseSeries(List<int> values) {
  if (values.isEmpty) return const [];
  final startFactor = 10000 + values.first;
  if (startFactor <= 0) {
    return values.map((value) => value - values.first).toList(growable: false);
  }
  return values
      .map((value) => (((10000 + value) * 10000 / startFactor) - 10000).round())
      .toList(growable: false);
}

List<Color> _sectorPalette(BuildContext context) {
  final colors = context.ritualColors;
  final primary = Theme.of(context).colorScheme.primary;
  return [
    primary,
    colors.gold,
    colors.positive,
    Color.lerp(primary, colors.gold, 0.48)!,
    Color.lerp(colors.positive, colors.primarySoft, 0.42)!,
    colors.muted,
  ];
}

class _ComparisonChartPainter extends CustomPainter {
  const _ComparisonChartPainter({
    required this.portfolioValues,
    required this.benchmarkValues,
    required this.portfolioColor,
    required this.benchmarkColor,
    required this.gridColor,
  });

  final List<int> portfolioValues;
  final List<int> benchmarkValues;
  final Color portfolioColor;
  final Color benchmarkColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (portfolioValues.isEmpty || size.isEmpty) return;
    const left = 6.0;
    const top = 8.0;
    const right = 6.0;
    const bottom = 10.0;
    final allValues = <int>[...portfolioValues, ...benchmarkValues];
    final minValue = allValues.reduce(math.min).toDouble();
    final maxValue = allValues.reduce(math.max).toDouble();
    final range = math.max(1.0, maxValue - minValue);
    final chartWidth = math.max(0.0, size.width - left - right);
    final chartHeight = math.max(0.0, size.height - top - bottom);

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.72)
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = top + chartHeight * index / 3;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
    }

    Offset pointFor(int value, int index, int length) {
      final progress = length <= 1 ? 0.0 : index / (length - 1);
      return Offset(
        left + chartWidth * progress,
        top + chartHeight * (1 - (value - minValue) / range),
      );
    }

    Path pathFor(List<int> values) {
      final path = Path();
      for (var index = 0; index < values.length; index++) {
        final point = pointFor(values[index], index, values.length);
        if (index == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      return path;
    }

    final portfolioPath = pathFor(portfolioValues);
    if (portfolioValues.length > 1) {
      final area = Path.from(portfolioPath)
        ..lineTo(size.width - right, size.height - bottom)
        ..lineTo(left, size.height - bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              portfolioColor.withValues(alpha: 0.20),
              portfolioColor.withValues(alpha: 0.01),
            ],
          ).createShader(Offset.zero & size),
      );
    }
    if (benchmarkValues.isNotEmpty) {
      canvas.drawPath(
        pathFor(benchmarkValues),
        Paint()
          ..color = benchmarkColor
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.drawPath(
      portfolioPath,
      Paint()
        ..color = portfolioColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ComparisonChartPainter oldDelegate) =>
      oldDelegate.portfolioValues != portfolioValues ||
      oldDelegate.benchmarkValues != benchmarkValues ||
      oldDelegate.portfolioColor != portfolioColor ||
      oldDelegate.benchmarkColor != benchmarkColor ||
      oldDelegate.gridColor != gridColor;
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('discover-ai-loading'),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
    children: [
      Text(
        'Model research, measured against risk.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      const Text('Historical research, not personalized recommendations.'),
      const SizedBox(height: 24),
      const LinearProgressIndicator(semanticsLabel: 'Loading AI analysis'),
      const SizedBox(height: 18),
      const _LoadingBlock(height: 210),
      const SizedBox(height: 18),
      const _LoadingBlock(height: 136),
      const SizedBox(height: 12),
      const _LoadingBlock(height: 136),
    ],
  );
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: context.ritualColors.screenSoft,
        borderRadius: BorderRadius.circular(14),
      ),
    ),
  );
}

class _UnavailableBody extends StatelessWidget {
  const _UnavailableBody({required this.expired, required this.onRetry});

  final bool expired;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('discover-ai-unavailable'),
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
    children: [
      Icon(
        Icons.shield_outlined,
        size: 40,
        color: context.ritualColors.muted,
        semanticLabel: 'Analysis unavailable',
      ),
      const SizedBox(height: 16),
      Text(
        'AI analysis unavailable',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 10),
      Text(
        expired
            ? 'This analysis expired before it could be shown. Risk status and model metrics stay hidden until a fresh snapshot is confirmed.'
            : 'Risk status and model metrics stay hidden when the source cannot be confirmed as fresh.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 8),
      Text(
        'No earlier warning or performance result is being reused.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        key: const Key('discover-ai-retry'),
        onPressed: () => unawaited(onRetry()),
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
      ),
    ],
  );
}

class _ReturnSparklinePainter extends CustomPainter {
  const _ReturnSparklinePainter({
    required this.values,
    required this.lineColor,
    required this.baselineColor,
  });

  final List<int> values;
  final Color lineColor;
  final Color baselineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.isEmpty) return;
    const horizontalPadding = 4.0;
    const verticalPadding = 8.0;
    final minValue = values.reduce(math.min).toDouble();
    final maxValue = values.reduce(math.max).toDouble();
    final range = math.max(1.0, maxValue - minValue);
    final drawableWidth = math.max(0.0, size.width - horizontalPadding * 2);
    final drawableHeight = math.max(0.0, size.height - verticalPadding * 2);

    if (minValue <= 0 && maxValue >= 0) {
      final zeroY = verticalPadding + (maxValue / range) * drawableHeight;
      canvas.drawLine(
        Offset(horizontalPadding, zeroY),
        Offset(size.width - horizontalPadding, zeroY),
        Paint()
          ..color = baselineColor
          ..strokeWidth = 1,
      );
    }

    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final progress = values.length == 1 ? 0.0 : index / (values.length - 1);
      final x = horizontalPadding + progress * drawableWidth;
      final normalized = (values[index] - minValue) / range;
      final y = verticalPadding + (1 - normalized) * drawableHeight;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ReturnSparklinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.baselineColor != baselineColor;
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.icon,
    required this.iconLabel,
    required this.foreground,
    required this.tint,
  });

  final IconData icon;
  final String iconLabel;
  final Color foreground;
  final Color tint;
}

_StatusPresentation _riskPresentation(
  MarketRiskLevel level,
  BuildContext context,
) {
  final colors = context.ritualColors;
  final scheme = Theme.of(context).colorScheme;
  return switch (level) {
    MarketRiskLevel.normal => _StatusPresentation(
      icon: Icons.check_circle_outline,
      iconLabel: 'Normal risk level',
      foreground: colors.positive,
      tint: colors.positive.withValues(alpha: 0.14),
    ),
    MarketRiskLevel.watch => _StatusPresentation(
      icon: Icons.visibility_outlined,
      iconLabel: 'Watch risk level',
      foreground: _attentionColor(context),
      tint: colors.gold.withValues(alpha: 0.14),
    ),
    MarketRiskLevel.elevated => _StatusPresentation(
      icon: Icons.warning_amber_rounded,
      iconLabel: 'Elevated risk level',
      foreground: _attentionColor(context),
      tint: colors.gold.withValues(alpha: 0.18),
    ),
    MarketRiskLevel.highStress => _StatusPresentation(
      icon: Icons.crisis_alert,
      iconLabel: 'High stress risk level',
      foreground: scheme.error,
      tint: scheme.error.withValues(alpha: 0.14),
    ),
  };
}

_StatusPresentation _signalPresentation(
  MarketRiskSignalState state,
  BuildContext context,
) {
  final colors = context.ritualColors;
  final scheme = Theme.of(context).colorScheme;
  return switch (state) {
    MarketRiskSignalState.supportive => _StatusPresentation(
      icon: Icons.check_circle_outline,
      iconLabel: 'Supportive signal',
      foreground: colors.positive,
      tint: colors.positive.withValues(alpha: 0.12),
    ),
    MarketRiskSignalState.watch => _StatusPresentation(
      icon: Icons.visibility_outlined,
      iconLabel: 'Watch signal',
      foreground: _attentionColor(context),
      tint: colors.gold.withValues(alpha: 0.12),
    ),
    MarketRiskSignalState.stressed => _StatusPresentation(
      icon: Icons.warning_amber_rounded,
      iconLabel: 'Stressed signal',
      foreground: scheme.error,
      tint: scheme.error.withValues(alpha: 0.12),
    ),
  };
}

Color _attentionColor(BuildContext context) {
  final colors = context.ritualColors;
  return Theme.of(context).brightness == Brightness.dark
      ? colors.gold
      : Color.lerp(colors.gold, colors.ink, 0.42)!;
}

String _trackRecordLabel(AiTrackRecordKind kind) => switch (kind) {
  AiTrackRecordKind.backtest => 'BACKTEST',
  AiTrackRecordKind.paperForwardTest => 'PAPER',
  AiTrackRecordKind.live => 'LIVE',
};

String _signalLabel(MarketRiskSignalState state) => switch (state) {
  MarketRiskSignalState.supportive => 'Supportive',
  MarketRiskSignalState.watch => 'Watch',
  MarketRiskSignalState.stressed => 'Stressed',
};

String _percentBps(int basisPoints) {
  final value = basisPoints / 100;
  final prefix = basisPoints > 0 ? '+' : '';
  return '$prefix${value.toStringAsFixed(2)}%';
}

String _weightBps(int basisPoints) =>
    '${(basisPoints / 100).toStringAsFixed(2)}%';

String _currency(double value) {
  final rounded = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < rounded.length; index++) {
    if (index > 0 && (rounded.length - index) % 3 == 0) buffer.write(',');
    buffer.write(rounded[index]);
  }
  return '\$${buffer.toString()}';
}

String _period(DateTime start, DateTime end) =>
    '${_date(start)} – ${_date(end)}';

String _timestamp(DateTime value) {
  final utc = value.toUtc();
  final hour = utc.hour.toString().padLeft(2, '0');
  final minute = utc.minute.toString().padLeft(2, '0');
  return '${_date(utc)} $hour:$minute UTC';
}

String _date(DateTime value) {
  final utc = value.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day';
}
