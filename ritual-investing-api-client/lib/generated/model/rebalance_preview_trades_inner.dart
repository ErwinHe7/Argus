//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/quantity.dart';
import 'package:ritual_investing_api_client/generated/model/money.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rebalance_preview_trades_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RebalancePreviewTradesInner {
  /// Returns a new [RebalancePreviewTradesInner] instance.
  RebalancePreviewTradesInner({
    required this.assetId,

    required this.notional,

    required this.quantity,

    required this.side,
  });

  @JsonKey(name: r'asset_id', required: true, includeIfNull: false)
  final String assetId;

  @JsonKey(name: r'notional', required: true, includeIfNull: false)
  final Money notional;

  @JsonKey(name: r'quantity', required: true, includeIfNull: false)
  final Quantity quantity;

  @JsonKey(
    name: r'side',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RebalancePreviewTradesInnerSideEnum.unknownDefaultOpenApi,
  )
  final RebalancePreviewTradesInnerSideEnum side;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RebalancePreviewTradesInner &&
          other.assetId == assetId &&
          other.notional == notional &&
          other.quantity == quantity &&
          other.side == side;

  @override
  int get hashCode =>
      assetId.hashCode + notional.hashCode + quantity.hashCode + side.hashCode;

  factory RebalancePreviewTradesInner.fromJson(Map<String, dynamic> json) =>
      _$RebalancePreviewTradesInnerFromJson(json);

  Map<String, dynamic> toJson() => _$RebalancePreviewTradesInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RebalancePreviewTradesInnerSideEnum {
  @JsonValue(r'buy')
  buy(r'buy'),
  @JsonValue(r'sell')
  sell(r'sell'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RebalancePreviewTradesInnerSideEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
