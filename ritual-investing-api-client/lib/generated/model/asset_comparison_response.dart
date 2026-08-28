//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_audit200_response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/asset_comparison.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'asset_comparison_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AssetComparisonResponse {
  /// Returns a new [AssetComparisonResponse] instance.
  AssetComparisonResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final AssetComparison data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ListAdminAudit200ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetComparisonResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory AssetComparisonResponse.fromJson(Map<String, dynamic> json) =>
      _$AssetComparisonResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AssetComparisonResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
