//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/research_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'asset_metric.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AssetMetric {
  /// Returns a new [AssetMetric] instance.
  AssetMetric({
    required this.changeBps,

    required this.demo,

    required this.expenseRatioBps,

    required this.observedAt,

    required this.priceMinor,

    required this.sourceLabel,
  });

  @JsonKey(name: r'change_bps', required: true, includeIfNull: true)
  final int? changeBps;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final ResearchDisclosure demo;

  // minimum: 0
  @JsonKey(name: r'expense_ratio_bps', required: true, includeIfNull: true)
  final int? expenseRatioBps;

  @JsonKey(name: r'observed_at', required: true, includeIfNull: false)
  final DateTime observedAt;

  // minimum: 0
  @JsonKey(name: r'price_minor', required: true, includeIfNull: false)
  final int priceMinor;

  @JsonKey(name: r'source_label', required: true, includeIfNull: false)
  final String sourceLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetMetric &&
          other.changeBps == changeBps &&
          other.demo == demo &&
          other.expenseRatioBps == expenseRatioBps &&
          other.observedAt == observedAt &&
          other.priceMinor == priceMinor &&
          other.sourceLabel == sourceLabel;

  @override
  int get hashCode =>
      (changeBps == null ? 0 : changeBps.hashCode) +
      demo.hashCode +
      (expenseRatioBps == null ? 0 : expenseRatioBps.hashCode) +
      observedAt.hashCode +
      priceMinor.hashCode +
      sourceLabel.hashCode;

  factory AssetMetric.fromJson(Map<String, dynamic> json) =>
      _$AssetMetricFromJson(json);

  Map<String, dynamic> toJson() => _$AssetMetricToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
