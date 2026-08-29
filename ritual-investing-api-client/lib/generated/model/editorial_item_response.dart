//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/published_editorial.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_audit200_response_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'editorial_item_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EditorialItemResponse {
  /// Returns a new [EditorialItemResponse] instance.
  EditorialItemResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: true)
  final PublishedEditorial? data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ListAdminAudit200ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorialItemResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => (data == null ? 0 : data.hashCode) + meta.hashCode;

  factory EditorialItemResponse.fromJson(Map<String, dynamic> json) =>
      _$EditorialItemResponseFromJson(json);

  Map<String, dynamic> toJson() => _$EditorialItemResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
