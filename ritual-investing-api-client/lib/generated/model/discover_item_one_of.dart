//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/asset_summary.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'discover_item_one_of.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DiscoverItemOneOf {
  /// Returns a new [DiscoverItemOneOf] instance.
  DiscoverItemOneOf({required this.asset, required this.kind});

  @JsonKey(name: r'asset', required: true, includeIfNull: false)
  final AssetSummary asset;

  @JsonKey(
    name: r'kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DiscoverItemOneOfKindEnum.unknownDefaultOpenApi,
  )
  final DiscoverItemOneOfKindEnum kind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoverItemOneOf && other.asset == asset && other.kind == kind;

  @override
  int get hashCode => asset.hashCode + kind.hashCode;

  factory DiscoverItemOneOf.fromJson(Map<String, dynamic> json) =>
      _$DiscoverItemOneOfFromJson(json);

  Map<String, dynamic> toJson() => _$DiscoverItemOneOfToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum DiscoverItemOneOfKindEnum {
  @JsonValue(r'asset')
  asset(r'asset'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DiscoverItemOneOfKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
