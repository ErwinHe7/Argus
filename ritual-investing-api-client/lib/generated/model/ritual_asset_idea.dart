//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ritual_asset_idea.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RitualAssetIdea {
  /// Returns a new [RitualAssetIdea] instance.
  RitualAssetIdea({
    required this.appearanceReason,

    required this.assetId,

    required this.name,

    required this.riskSummary,

    required this.symbol,
  });

  @JsonKey(name: r'appearance_reason', required: true, includeIfNull: false)
  final String appearanceReason;

  @JsonKey(name: r'asset_id', required: true, includeIfNull: false)
  final String assetId;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'risk_summary', required: true, includeIfNull: false)
  final String riskSummary;

  @JsonKey(name: r'symbol', required: true, includeIfNull: false)
  final String symbol;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RitualAssetIdea &&
          other.appearanceReason == appearanceReason &&
          other.assetId == assetId &&
          other.name == name &&
          other.riskSummary == riskSummary &&
          other.symbol == symbol;

  @override
  int get hashCode =>
      appearanceReason.hashCode +
      assetId.hashCode +
      name.hashCode +
      riskSummary.hashCode +
      symbol.hashCode;

  factory RitualAssetIdea.fromJson(Map<String, dynamic> json) =>
      _$RitualAssetIdeaFromJson(json);

  Map<String, dynamic> toJson() => _$RitualAssetIdeaToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
