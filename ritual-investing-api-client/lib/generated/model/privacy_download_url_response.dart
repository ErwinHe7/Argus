//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/privacy_download_url.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_audit200_response_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'privacy_download_url_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PrivacyDownloadUrlResponse {
  /// Returns a new [PrivacyDownloadUrlResponse] instance.
  PrivacyDownloadUrlResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final PrivacyDownloadUrl data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ListAdminAudit200ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyDownloadUrlResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory PrivacyDownloadUrlResponse.fromJson(Map<String, dynamic> json) =>
      _$PrivacyDownloadUrlResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PrivacyDownloadUrlResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
