//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/asset_comparison_assets_inner.dart';
import 'package:ritual_investing_api_client/generated/model/research_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'asset_comparison.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AssetComparison {
  /// Returns a new [AssetComparison] instance.
  AssetComparison({
    required this.assets,

    required this.comparedAt,

    required this.demo,
  });

  @JsonKey(name: r'assets', required: true, includeIfNull: false)
  final List<AssetComparisonAssetsInner> assets;

  @JsonKey(name: r'compared_at', required: true, includeIfNull: false)
  final DateTime comparedAt;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final ResearchDisclosure demo;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetComparison &&
          other.assets == assets &&
          other.comparedAt == comparedAt &&
          other.demo == demo;

  @override
  int get hashCode => assets.hashCode + comparedAt.hashCode + demo.hashCode;

  factory AssetComparison.fromJson(Map<String, dynamic> json) =>
      _$AssetComparisonFromJson(json);

  Map<String, dynamic> toJson() => _$AssetComparisonToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
