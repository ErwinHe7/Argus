//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_privacy_download_url200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreatePrivacyDownloadUrl200Response {
  /// Returns a new [CreatePrivacyDownloadUrl200Response] instance.
  CreatePrivacyDownloadUrl200Response({
    required this.expiresAt,

    required this.url,
  });

  @JsonKey(name: r'expires_at', required: true, includeIfNull: false)
  final DateTime expiresAt;

  @JsonKey(name: r'url', required: true, includeIfNull: false)
  final String url;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatePrivacyDownloadUrl200Response &&
          other.expiresAt == expiresAt &&
          other.url == url;

  @override
  int get hashCode => expiresAt.hashCode + url.hashCode;

  factory CreatePrivacyDownloadUrl200Response.fromJson(
    Map<String, dynamic> json,
  ) => _$CreatePrivacyDownloadUrl200ResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreatePrivacyDownloadUrl200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
