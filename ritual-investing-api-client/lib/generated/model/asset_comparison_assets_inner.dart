//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/asset_summary.dart';
import 'package:ritual_investing_api_client/generated/model/asset_metric.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'asset_comparison_assets_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AssetComparisonAssetsInner {
  /// Returns a new [AssetComparisonAssetsInner] instance.
  AssetComparisonAssetsInner({
    required this.asset,

    required this.latestMetric,

    required this.riskCount,
  });

  @JsonKey(name: r'asset', required: true, includeIfNull: false)
  final AssetSummary asset;

  @JsonKey(name: r'latest_metric', required: true, includeIfNull: false)
  final AssetMetric latestMetric;

  // minimum: 0
  @JsonKey(name: r'risk_count', required: true, includeIfNull: false)
  final int riskCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetComparisonAssetsInner &&
          other.asset == asset &&
          other.latestMetric == latestMetric &&
          other.riskCount == riskCount;

  @override
  int get hashCode =>
      asset.hashCode + latestMetric.hashCode + riskCount.hashCode;

  factory AssetComparisonAssetsInner.fromJson(Map<String, dynamic> json) =>
      _$AssetComparisonAssetsInnerFromJson(json);

  Map<String, dynamic> toJson() => _$AssetComparisonAssetsInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
