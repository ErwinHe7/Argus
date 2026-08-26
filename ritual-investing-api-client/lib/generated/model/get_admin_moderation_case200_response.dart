//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/admin_moderation_case.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'get_admin_moderation_case200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GetAdminModerationCase200Response {
  /// Returns a new [GetAdminModerationCase200Response] instance.
  GetAdminModerationCase200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final AdminModerationCase data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GetAdminModerationCase200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory GetAdminModerationCase200Response.fromJson(
    Map<String, dynamic> json,
  ) => _$GetAdminModerationCase200ResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$GetAdminModerationCase200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
