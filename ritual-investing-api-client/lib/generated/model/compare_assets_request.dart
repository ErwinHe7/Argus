//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'compare_assets_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CompareAssetsRequest {
  /// Returns a new [CompareAssetsRequest] instance.
  CompareAssetsRequest({required this.assetIds});

  @JsonKey(name: r'assetIds', required: true, includeIfNull: false)
  final List<String> assetIds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompareAssetsRequest && other.assetIds == assetIds;

  @override
  int get hashCode => assetIds.hashCode;

  factory CompareAssetsRequest.fromJson(Map<String, dynamic> json) =>
      _$CompareAssetsRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CompareAssetsRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
