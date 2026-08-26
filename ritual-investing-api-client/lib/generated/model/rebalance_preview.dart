//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/rebalance_preview_trades_inner.dart';
import 'package:ritual_investing_api_client/generated/model/simulation_demo_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/create_portfolio_request_target_allocation_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rebalance_preview.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RebalancePreview {
  /// Returns a new [RebalancePreview] instance.
  RebalancePreview({
    required this.demo,

    required this.expiresAt,

    required this.id,

    required this.portfolioId,

    required this.portfolioVersion,

    required this.status,

    required this.targetAllocation,

    required this.trades,
  });

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final SimulationDemoDisclosure demo;

  @JsonKey(name: r'expires_at', required: true, includeIfNull: false)
  final DateTime expiresAt;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'portfolio_id', required: true, includeIfNull: false)
  final String portfolioId;

  // minimum: 0
  @JsonKey(name: r'portfolio_version', required: true, includeIfNull: false)
  final int portfolioVersion;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RebalancePreviewStatusEnum.unknownDefaultOpenApi,
  )
  final RebalancePreviewStatusEnum status;

  @JsonKey(name: r'target_allocation', required: true, includeIfNull: false)
  final List<CreatePortfolioRequestTargetAllocationInner> targetAllocation;

  @JsonKey(name: r'trades', required: true, includeIfNull: false)
  final List<RebalancePreviewTradesInner> trades;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RebalancePreview &&
          other.demo == demo &&
          other.expiresAt == expiresAt &&
          other.id == id &&
          other.portfolioId == portfolioId &&
          other.portfolioVersion == portfolioVersion &&
          other.status == status &&
          other.targetAllocation == targetAllocation &&
          other.trades == trades;

  @override
  int get hashCode =>
      demo.hashCode +
      expiresAt.hashCode +
      id.hashCode +
      portfolioId.hashCode +
      portfolioVersion.hashCode +
      status.hashCode +
      targetAllocation.hashCode +
      trades.hashCode;

  factory RebalancePreview.fromJson(Map<String, dynamic> json) =>
      _$RebalancePreviewFromJson(json);

  Map<String, dynamic> toJson() => _$RebalancePreviewToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RebalancePreviewStatusEnum {
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

  const RebalancePreviewStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
