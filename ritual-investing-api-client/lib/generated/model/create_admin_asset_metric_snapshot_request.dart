//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_admin_asset_metric_snapshot_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateAdminAssetMetricSnapshotRequest {
  /// Returns a new [CreateAdminAssetMetricSnapshotRequest] instance.
  CreateAdminAssetMetricSnapshotRequest({
    required this.changeBps,

    required this.expenseRatioBps,

    required this.observedAt,

    required this.priceMinor,

    required this.sourceLabel,
  });

  // minimum: -100000
  // maximum: 100000
  @JsonKey(name: r'change_bps', required: true, includeIfNull: true)
  final int? changeBps;

  // minimum: 0
  // maximum: 100000
  @JsonKey(name: r'expense_ratio_bps', required: true, includeIfNull: true)
  final int? expenseRatioBps;

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
      other is CreateAdminAssetMetricSnapshotRequest &&
          other.changeBps == changeBps &&
          other.expenseRatioBps == expenseRatioBps &&
          other.observedAt == observedAt &&
          other.priceMinor == priceMinor &&
          other.sourceLabel == sourceLabel;

  @override
  int get hashCode =>
      (changeBps == null ? 0 : changeBps.hashCode) +
      (expenseRatioBps == null ? 0 : expenseRatioBps.hashCode) +
      observedAt.hashCode +
      priceMinor.hashCode +
      sourceLabel.hashCode;

  factory CreateAdminAssetMetricSnapshotRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateAdminAssetMetricSnapshotRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateAdminAssetMetricSnapshotRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
