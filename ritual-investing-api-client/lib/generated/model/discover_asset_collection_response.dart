//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/collection_meta.dart';
import 'package:ritual_investing_api_client/generated/model/asset_summary.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'discover_asset_collection_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DiscoverAssetCollectionResponse {
  /// Returns a new [DiscoverAssetCollectionResponse] instance.
  DiscoverAssetCollectionResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final List<AssetSummary> data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final CollectionMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoverAssetCollectionResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory DiscoverAssetCollectionResponse.fromJson(Map<String, dynamic> json) =>
      _$DiscoverAssetCollectionResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$DiscoverAssetCollectionResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
