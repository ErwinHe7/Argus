//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'admin_asset_metric_snapshot.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AdminAssetMetricSnapshot {
  /// Returns a new [AdminAssetMetricSnapshot] instance.
  AdminAssetMetricSnapshot({
    required this.assetId,

    required this.changeBps,

    required this.expenseRatioBps,

    required this.id,

    required this.isDemo,

    required this.observedAt,

    required this.priceMinor,

    required this.sourceLabel,
  });

  @JsonKey(name: r'asset_id', required: true, includeIfNull: false)
  final String assetId;

  // minimum: -100000
  // maximum: 100000
  @JsonKey(name: r'change_bps', required: true, includeIfNull: true)
  final int? changeBps;

  // minimum: 0
  // maximum: 100000
  @JsonKey(name: r'expense_ratio_bps', required: true, includeIfNull: true)
  final int? expenseRatioBps;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'is_demo', required: true, includeIfNull: false)
  final bool isDemo;

  @JsonKey(name: r'observed_at', required: true, includeIfNull: false)
  final DateTime observedAt;

  // minimum: 0
  // maximum: 9007199254740991
  @JsonKey(name: r'price_minor', required: true, includeIfNull: false)
  final int priceMinor;

  @JsonKey(name: r'source_label', required: true, includeIfNull: false)
  final String sourceLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminAssetMetricSnapshot &&
          other.assetId == assetId &&
          other.changeBps == changeBps &&
          other.expenseRatioBps == expenseRatioBps &&
          other.id == id &&
          other.isDemo == isDemo &&
          other.observedAt == observedAt &&
          other.priceMinor == priceMinor &&
          other.sourceLabel == sourceLabel;

  @override
  int get hashCode =>
      assetId.hashCode +
      (changeBps == null ? 0 : changeBps.hashCode) +
      (expenseRatioBps == null ? 0 : expenseRatioBps.hashCode) +
      id.hashCode +
      isDemo.hashCode +
      observedAt.hashCode +
      priceMinor.hashCode +
      sourceLabel.hashCode;

  factory AdminAssetMetricSnapshot.fromJson(Map<String, dynamic> json) =>
      _$AdminAssetMetricSnapshotFromJson(json);

  Map<String, dynamic> toJson() => _$AdminAssetMetricSnapshotToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
