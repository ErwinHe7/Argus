//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/circle_asset_input.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'replace_circle_assets_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ReplaceCircleAssetsRequest {
  /// Returns a new [ReplaceCircleAssetsRequest] instance.
  ReplaceCircleAssetsRequest({required this.assets});

  @JsonKey(name: r'assets', required: true, includeIfNull: false)
  final List<CircleAssetInput> assets;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReplaceCircleAssetsRequest && other.assets == assets;

  @override
  int get hashCode => assets.hashCode;

  factory ReplaceCircleAssetsRequest.fromJson(Map<String, dynamic> json) =>
      _$ReplaceCircleAssetsRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ReplaceCircleAssetsRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
