//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_privacy_requests200_response_data_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'get_admin_privacy_request200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GetAdminPrivacyRequest200Response {
  /// Returns a new [GetAdminPrivacyRequest200Response] instance.
  GetAdminPrivacyRequest200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final ListAdminPrivacyRequests200ResponseDataInner data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GetAdminPrivacyRequest200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory GetAdminPrivacyRequest200Response.fromJson(
    Map<String, dynamic> json,
  ) => _$GetAdminPrivacyRequest200ResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$GetAdminPrivacyRequest200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
