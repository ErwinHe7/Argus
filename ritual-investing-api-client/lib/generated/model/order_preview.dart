//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/simulation_demo_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/quantity.dart';
import 'package:ritual_investing_api_client/generated/model/money.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_preview.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OrderPreview {
  /// Returns a new [OrderPreview] instance.
  OrderPreview({
    required this.assetId,

    required this.demo,

    required this.expiresAt,

    required this.frozenPrice,

    required this.id,

    required this.notional,

    required this.observedAt,

    required this.portfolioId,

    required this.portfolioVersion,

    required this.quantity,

    required this.quoteSnapshotId,

    required this.side,

    required this.status,

    required this.symbol,
  });

  @JsonKey(name: r'asset_id', required: true, includeIfNull: false)
  final String assetId;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final SimulationDemoDisclosure demo;

  @JsonKey(name: r'expires_at', required: true, includeIfNull: false)
  final DateTime expiresAt;

  @JsonKey(name: r'frozen_price', required: true, includeIfNull: false)
  final Money frozenPrice;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'notional', required: true, includeIfNull: false)
  final Money notional;

  @JsonKey(name: r'observed_at', required: true, includeIfNull: false)
  final DateTime observedAt;

  @JsonKey(name: r'portfolio_id', required: true, includeIfNull: false)
  final String portfolioId;

  // minimum: 0
  @JsonKey(name: r'portfolio_version', required: true, includeIfNull: false)
  final int portfolioVersion;

  @JsonKey(name: r'quantity', required: true, includeIfNull: false)
  final Quantity quantity;

  @JsonKey(name: r'quote_snapshot_id', required: true, includeIfNull: false)
  final String quoteSnapshotId;

  @JsonKey(
    name: r'side',
    required: true,
    includeIfNull: false,
    unknownEnumValue: OrderPreviewSideEnum.unknownDefaultOpenApi,
  )
  final OrderPreviewSideEnum side;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: OrderPreviewStatusEnum.unknownDefaultOpenApi,
  )
  final OrderPreviewStatusEnum status;

  @JsonKey(name: r'symbol', required: true, includeIfNull: false)
  final String symbol;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderPreview &&
          other.assetId == assetId &&
          other.demo == demo &&
          other.expiresAt == expiresAt &&
          other.frozenPrice == frozenPrice &&
          other.id == id &&
          other.notional == notional &&
          other.observedAt == observedAt &&
          other.portfolioId == portfolioId &&
          other.portfolioVersion == portfolioVersion &&
          other.quantity == quantity &&
          other.quoteSnapshotId == quoteSnapshotId &&
          other.side == side &&
          other.status == status &&
          other.symbol == symbol;

  @override
  int get hashCode =>
      assetId.hashCode +
      demo.hashCode +
      expiresAt.hashCode +
      frozenPrice.hashCode +
      id.hashCode +
      notional.hashCode +
      observedAt.hashCode +
      portfolioId.hashCode +
      portfolioVersion.hashCode +
      quantity.hashCode +
      quoteSnapshotId.hashCode +
      side.hashCode +
      status.hashCode +
      symbol.hashCode;

  factory OrderPreview.fromJson(Map<String, dynamic> json) =>
      _$OrderPreviewFromJson(json);

  Map<String, dynamic> toJson() => _$OrderPreviewToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum OrderPreviewSideEnum {
  @JsonValue(r'buy')
  buy(r'buy'),
  @JsonValue(r'sell')
  sell(r'sell'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const OrderPreviewSideEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum OrderPreviewStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'executed')
  executed(r'executed'),
  @JsonValue(r'expired')
  expired(r'expired'),
  @JsonValue(r'invalidated')
  invalidated(r'invalidated'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const OrderPreviewStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
