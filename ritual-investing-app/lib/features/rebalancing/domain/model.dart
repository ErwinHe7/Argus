import 'package:flutter/foundation.dart';

enum RebalanceSide { buy, sell }
enum RebalancePreviewStatus { active, executed, expired, invalidated }

@immutable
class RebalanceDemoDisclosure {
  const RebalanceDemoDisclosure({
    required this.isDemo,
    required this.observedAt,
    required this.sourceLabel,
    required this.limitations,
  });
  final bool isDemo;
  final DateTime observedAt;
  final String sourceLabel;
  final List<String> limitations;

  Map<String, Object?> toMap() => {
    'is_demo': isDemo,
    'observed_at': observedAt.toUtc().toIso8601String(),
    'source_label': sourceLabel,
    'limitations': limitations,
  };
}

@immutable
class RebalanceAllocation {
  const RebalanceAllocation({required this.assetId, required this.targetBps});
  final String assetId;
  final int targetBps;
  Map<String, Object?> toMap() => {'asset_id': assetId, 'target_bps': targetBps};
  factory RebalanceAllocation.fromMap(Map<String, Object?> value) =>
      RebalanceAllocation(
        assetId: value['asset_id']! as String,
        targetBps: value['target_bps']! as int,
      );
}

@immutable
class RebalanceTrade {
  const RebalanceTrade({
    required this.assetId,
    required this.side,
    required this.quantityValue,
    required this.quantityScale,
    required this.notionalMinor,
  });
  final String assetId;
  final RebalanceSide side;
  final String quantityValue;
  final int quantityScale;
  final int notionalMinor;
  Map<String, Object?> toMap() => {
    'asset_id': assetId,
    'side': side.name,
    'quantity_value': quantityValue,
    'quantity_scale': quantityScale,
    'notional_minor': notionalMinor,
  };
  factory RebalanceTrade.fromMap(Map<String, Object?> value) => RebalanceTrade(
    assetId: value['asset_id']! as String,
    side: RebalanceSide.values.byName(value['side']! as String),
    quantityValue: value['quantity_value']! as String,
    quantityScale: value['quantity_scale']! as int,
    notionalMinor: value['notional_minor']! as int,
  );
}

@immutable
class RebalancePreview {
  const RebalancePreview({
    required this.id,
    required this.portfolioId,
    required this.portfolioVersion,
    required this.targetAllocation,
    required this.trades,
    required this.expiresAt,
    required this.status,
    required this.demo,
  });
  final String id;
  final String portfolioId;
  final int portfolioVersion;
  final List<RebalanceAllocation> targetAllocation;
  final List<RebalanceTrade> trades;
  final DateTime expiresAt;
  final RebalancePreviewStatus status;
  final RebalanceDemoDisclosure demo;

  Map<String, Object?> toProtectedMap() => {
    'id': id,
    'portfolio_id': portfolioId,
    'portfolio_version': portfolioVersion,
    'target_allocation': targetAllocation.map((value) => value.toMap()).toList(),
    'trades': trades.map((value) => value.toMap()).toList(),
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'status': status.name,
    'demo': demo.toMap(),
  };

  factory RebalancePreview.fromProtectedMap(Map<String, Object?> value) {
    const keys = {
      'id',
      'portfolio_id',
      'portfolio_version',
      'target_allocation',
      'trades',
      'expires_at',
      'status',
      'demo',
    };
    if (!setEquals(value.keys.toSet(), keys) ||
        value['id'] is! String ||
        (value['id']! as String).trim().isEmpty ||
        value['portfolio_id'] is! String ||
        (value['portfolio_id']! as String).trim().isEmpty ||
        value['portfolio_version'] is! int ||
        (value['portfolio_version']! as int) < 1 ||
        value['target_allocation'] is! List ||
        value['trades'] is! List ||
        value['status'] != 'active' ||
        value['demo'] is! Map) {
      throw const FormatException('Invalid protected rebalance preview.');
    }
    final expiresAt = DateTime.tryParse(value['expires_at'] as String? ?? '');
    final allocations = (value['target_allocation']! as List)
        .map(
          (item) => RebalanceAllocation.fromMap(
            (item as Map).cast<String, Object?>(),
          ),
        )
        .toList(growable: false);
    final trades = (value['trades']! as List)
        .map(
          (item) => RebalanceTrade.fromMap(
            (item as Map).cast<String, Object?>(),
          ),
        )
        .toList(growable: false);
    final demo = (value['demo']! as Map).cast<String, Object?>();
    final demoObservedAt = DateTime.tryParse(demo['observed_at'] as String? ?? '');
    if (expiresAt == null ||
        demoObservedAt == null ||
        !_validAllocations(allocations) ||
        trades.isEmpty ||
        trades.length > 50 ||
        trades.any(
          (trade) =>
              trade.assetId.trim().isEmpty ||
              trade.notionalMinor < 0 ||
              trade.quantityScale < 0 ||
              trade.quantityScale > 12 ||
              !RegExp(r'^(?:0|[1-9]\d*)(?:\.\d{1,12})?$')
                  .hasMatch(trade.quantityValue),
        ) ||
        demo['is_demo'] != true ||
        demo['source_label'] is! String ||
        (demo['source_label']! as String).trim().isEmpty ||
        demo['limitations'] is! List ||
        (demo['limitations']! as List).isEmpty ||
        !(demo['limitations']! as List).every(
          (item) => item is String && item.trim().isNotEmpty,
        )) {
      throw const FormatException('Invalid protected rebalance details.');
    }
    return RebalancePreview(
      id: value['id']! as String,
      portfolioId: value['portfolio_id']! as String,
      portfolioVersion: value['portfolio_version']! as int,
      targetAllocation: List.unmodifiable(allocations),
      trades: List.unmodifiable(trades),
      expiresAt: expiresAt.toUtc(),
      status: RebalancePreviewStatus.active,
      demo: RebalanceDemoDisclosure(
        isDemo: true,
        observedAt: demoObservedAt.toUtc(),
        sourceLabel: demo['source_label']! as String,
        limitations: List.unmodifiable((demo['limitations']! as List).cast<String>()),
      ),
    );
  }
}

@immutable
class RebalanceCommit {
  const RebalanceCommit({
    required this.portfolioId,
    required this.previewId,
    required this.portfolioVersion,
    required this.idempotencyKey,
  });
  final String portfolioId;
  final String previewId;
  final int portfolioVersion;
  final String idempotencyKey;
}

@immutable
class RebalanceReceipt {
  const RebalanceReceipt({
    required this.commandId,
    required this.portfolioVersion,
    required this.ledgerTransactionIds,
    required this.demo,
  });
  final String commandId;
  final int portfolioVersion;
  final List<String> ledgerTransactionIds;
  final RebalanceDemoDisclosure demo;
}

class AmbiguousRebalanceFailure implements Exception {
  const AmbiguousRebalanceFailure();
}
class RebalanceAlreadyBalanced implements Exception {
  const RebalanceAlreadyBalanced();
}
enum RebalanceCommitFailureReason { stalePreview, other }
class RebalanceCommitFailure implements Exception {
  const RebalanceCommitFailure.stalePreview()
    : reason = RebalanceCommitFailureReason.stalePreview;
  const RebalanceCommitFailure.other()
    : reason = RebalanceCommitFailureReason.other;
  final RebalanceCommitFailureReason reason;
}

bool validRebalanceAllocations(List<RebalanceAllocation> values) =>
    _validAllocations(values);

bool _validAllocations(List<RebalanceAllocation> values) =>
    values.isNotEmpty &&
    values.length <= 50 &&
    values.every(
      (value) =>
          value.assetId.trim().isNotEmpty &&
          value.targetBps >= 0 &&
          value.targetBps <= 10000,
    ) &&
    values.map((value) => value.assetId).toSet().length == values.length &&
    values.fold<int>(0, (sum, value) => sum + value.targetBps) == 10000;
