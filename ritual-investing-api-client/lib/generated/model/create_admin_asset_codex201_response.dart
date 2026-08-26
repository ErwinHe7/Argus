//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner.dart';
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_admin_asset_codex201_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateAdminAssetCodex201Response {
  /// Returns a new [CreateAdminAssetCodex201Response] instance.
  CreateAdminAssetCodex201Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final ListAdminAssetCodex200ResponseDataInner data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateAdminAssetCodex201Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory CreateAdminAssetCodex201Response.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateAdminAssetCodex201ResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateAdminAssetCodex201ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
