//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/privacy_request.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_audit200_response_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'privacy_request_collection_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PrivacyRequestCollectionResponse {
  /// Returns a new [PrivacyRequestCollectionResponse] instance.
  PrivacyRequestCollectionResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final List<PrivacyRequest> data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ListAdminAudit200ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyRequestCollectionResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory PrivacyRequestCollectionResponse.fromJson(
    Map<String, dynamic> json,
  ) => _$PrivacyRequestCollectionResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$PrivacyRequestCollectionResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
