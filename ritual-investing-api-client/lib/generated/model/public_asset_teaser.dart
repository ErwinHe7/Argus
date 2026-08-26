//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'public_asset_teaser.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PublicAssetTeaser {
  /// Returns a new [PublicAssetTeaser] instance.
  PublicAssetTeaser({
    required this.appearanceReason,

    required this.name,

    required this.symbol,
  });

  @JsonKey(name: r'appearance_reason', required: true, includeIfNull: false)
  final String appearanceReason;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'symbol', required: true, includeIfNull: false)
  final String symbol;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicAssetTeaser &&
          other.appearanceReason == appearanceReason &&
          other.name == name &&
          other.symbol == symbol;

  @override
  int get hashCode =>
      appearanceReason.hashCode + name.hashCode + symbol.hashCode;

  factory PublicAssetTeaser.fromJson(Map<String, dynamic> json) =>
      _$PublicAssetTeaserFromJson(json);

  Map<String, dynamic> toJson() => _$PublicAssetTeaserToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
