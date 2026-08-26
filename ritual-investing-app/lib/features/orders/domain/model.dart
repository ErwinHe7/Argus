import 'package:flutter/foundation.dart';

enum OrderSide { buy, sell }

enum OrderPreviewStatus { active, executed, expired, invalidated }

enum OrderStatus { accepted, rejected }

@immutable
class OrderDemoDisclosure {
  const OrderDemoDisclosure({
    required this.isDemo,
    required this.observedAt,
    required this.sourceLabel,
    required this.limitations,
  });
  final bool isDemo;
  final DateTime observedAt;
  final String sourceLabel;
  final List<String> limitations;
}

@immutable
class OrderDraft {
  const OrderDraft.notional({
    required this.portfolioId,
    required this.assetId,
    required this.side,
    required int minorUnits,
  }) : notionalMinor = minorUnits,
       quantityValue = null,
       quantityScale = null;

  const OrderDraft.quantity({
    required this.portfolioId,
    required this.assetId,
    required this.side,
    required this.quantityValue,
    required this.quantityScale,
  }) : notionalMinor = null,
       assert(quantityValue != null),
       assert(quantityScale != null);

  final String portfolioId;
  final String assetId;
  final OrderSide side;
  final int? notionalMinor;
  final String? quantityValue;
  final int? quantityScale;

  Map<String, Object?> toCanonicalMap() => {
    'portfolio_id': portfolioId,
    'asset_id': assetId,
    'side': side.name,
    'notional_minor': notionalMinor,
    'quantity_value': quantityValue,
    'quantity_scale': quantityScale,
    'currency': 'USD',
  };
}

@immutable
class OrderPreview {
  const OrderPreview({
    required this.id,
    required this.portfolioId,
    required this.portfolioVersion,
    required this.assetId,
    required this.symbol,
    required this.side,
    required this.notionalMinor,
    required this.quantityValue,
    required this.quantityScale,
    required this.frozenPriceMinor,
    required this.quoteSnapshotId,
    required this.observedAt,
    required this.expiresAt,
    required this.status,
    required this.demo,
  });
  final String id;
  final String portfolioId;
  final int portfolioVersion;
  final String assetId;
  final String symbol;
  final OrderSide side;
  final int notionalMinor;
  final String quantityValue;
  final int quantityScale;
  final int frozenPriceMinor;
  final String quoteSnapshotId;
  final DateTime observedAt;
  final DateTime expiresAt;
  final OrderPreviewStatus status;
  final OrderDemoDisclosure demo;

  Map<String, Object?> toProtectedMap() => {
    'id': id,
    'portfolio_id': portfolioId,
    'portfolio_version': portfolioVersion,
    'asset_id': assetId,
    'symbol': symbol,
    'side': side.name,
    'notional_minor': notionalMinor,
    'quantity_value': quantityValue,
    'quantity_scale': quantityScale,
    'frozen_price_minor': frozenPriceMinor,
    'quote_snapshot_id': quoteSnapshotId,
    'observed_at': observedAt.toUtc().toIso8601String(),
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'status': status.name,
    'demo': {
      'is_demo': demo.isDemo,
      'observed_at': demo.observedAt.toUtc().toIso8601String(),
      'source_label': demo.sourceLabel,
      'limitations': demo.limitations,
    },
  };

  factory OrderPreview.fromProtectedMap(Map<String, Object?> value) {
    const requiredKeys = {
      'id',
      'portfolio_id',
      'portfolio_version',
      'asset_id',
      'symbol',
      'side',
      'notional_minor',
      'quantity_value',
      'quantity_scale',
      'frozen_price_minor',
      'quote_snapshot_id',
      'observed_at',
      'expires_at',
      'status',
      'demo',
    };
    if (!setEquals(value.keys.toSet(), requiredKeys) ||
        value['id'] is! String ||
        (value['id']! as String).trim().isEmpty ||
        value['portfolio_id'] is! String ||
        (value['portfolio_id']! as String).trim().isEmpty ||
        value['portfolio_version'] is! int ||
        (value['portfolio_version']! as int) < 1 ||
        value['asset_id'] is! String ||
        (value['asset_id']! as String).trim().isEmpty ||
        value['symbol'] is! String ||
        (value['symbol']! as String).trim().isEmpty ||
        value['notional_minor'] is! int ||
        (value['notional_minor']! as int) < 1 ||
        value['quantity_value'] is! String ||
        !RegExp(r'^(?:0|[1-9]\d*)(?:\.\d{1,12})?$')
            .hasMatch(value['quantity_value']! as String) ||
        value['quantity_scale'] is! int ||
        (value['quantity_scale']! as int) < 0 ||
        (value['quantity_scale']! as int) > 12 ||
        value['frozen_price_minor'] is! int ||
        (value['frozen_price_minor']! as int) < 0 ||
        value['quote_snapshot_id'] is! String ||
        (value['quote_snapshot_id']! as String).trim().isEmpty ||
        value['status'] != 'active' ||
        value['demo'] is! Map) {
      throw const FormatException('Invalid protected order preview.');
    }
    final demo = (value['demo'] as Map).cast<String, Object?>();
    if (!setEquals(demo.keys.toSet(), {
          'is_demo',
          'observed_at',
          'source_label',
          'limitations',
        }) ||
        demo['is_demo'] != true ||
        demo['source_label'] is! String ||
        (demo['source_label']! as String).trim().isEmpty ||
        demo['limitations'] is! List ||
        (demo['limitations']! as List).isEmpty ||
        !(demo['limitations']! as List).every(
          (value) => value is String && value.trim().isNotEmpty,
        )) {
      throw const FormatException('Invalid protected Demo disclosure.');
    }
    final observedAt = DateTime.tryParse(value['observed_at']! as String);
    final expiresAt = DateTime.tryParse(value['expires_at']! as String);
    final demoObservedAt = DateTime.tryParse(demo['observed_at']! as String);
    if (observedAt == null || expiresAt == null || demoObservedAt == null) {
      throw const FormatException('Invalid protected timestamps.');
    }
    return OrderPreview(
      id: value['id']! as String,
      portfolioId: value['portfolio_id']! as String,
      portfolioVersion: value['portfolio_version']! as int,
      assetId: value['asset_id']! as String,
      symbol: value['symbol']! as String,
      side: OrderSide.values.byName(value['side']! as String),
      notionalMinor: value['notional_minor']! as int,
      quantityValue: value['quantity_value']! as String,
      quantityScale: value['quantity_scale']! as int,
      frozenPriceMinor: value['frozen_price_minor']! as int,
      quoteSnapshotId: value['quote_snapshot_id']! as String,
      observedAt: observedAt.toUtc(),
      expiresAt: expiresAt.toUtc(),
      status: OrderPreviewStatus.active,
      demo: OrderDemoDisclosure(
        isDemo: demo['is_demo']! as bool,
        observedAt: demoObservedAt.toUtc(),
        sourceLabel: demo['source_label']! as String,
        limitations: List<String>.unmodifiable(
          (demo['limitations']! as List).cast<String>(),
        ),
      ),
    );
  }
}

@immutable
class OrderCommit {
  const OrderCommit({
    required this.portfolioId,
    required this.previewId,
    required this.portfolioVersion,
    required this.idempotencyKey,
  });
  final String portfolioId;
  final String previewId;
  final int portfolioVersion;
  final String idempotencyKey;

  Map<String, Object?> toCanonicalMap() => {
    'portfolio_id': portfolioId,
    'preview_id': previewId,
    'portfolio_version': portfolioVersion,
  };
}

@immutable
class OrderReceipt {
  const OrderReceipt({
    required this.commandId,
    required this.portfolioVersion,
    required this.ledgerTransactionIds,
    required this.demo,
  });
  final String commandId;
  final int portfolioVersion;
  final List<String> ledgerTransactionIds;
  final OrderDemoDisclosure demo;
}

@immutable
class OrderFill {
  const OrderFill({
    required this.quantityValue,
    required this.quantityScale,
    required this.priceMinor,
    required this.filledAt,
  });
  final String quantityValue;
  final int quantityScale;
  final int priceMinor;
  final DateTime filledAt;
}

@immutable
class OrderView {
  const OrderView({
    required this.id,
    required this.portfolioId,
    required this.commandId,
    required this.assetId,
    required this.symbol,
    required this.side,
    required this.status,
    required this.notionalMinor,
    required this.quantityValue,
    required this.quantityScale,
    required this.fill,
    required this.demo,
  });
  final String id;
  final String portfolioId;
  final String commandId;
  final String assetId;
  final String symbol;
  final OrderSide side;
  final OrderStatus status;
  final int? notionalMinor;
  final String? quantityValue;
  final int? quantityScale;
  final OrderFill? fill;
  final OrderDemoDisclosure demo;
}

class AmbiguousOrderFailure implements Exception {
  const AmbiguousOrderFailure();
}

enum OrderCommitFailureReason { stalePreview, other }

class OrderCommitFailure implements Exception {
  const OrderCommitFailure.stalePreview()
    : reason = OrderCommitFailureReason.stalePreview;
  const OrderCommitFailure.other() : reason = OrderCommitFailureReason.other;
  final OrderCommitFailureReason reason;
}
