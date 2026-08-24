//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'request_privacy_export202_response_data_download_link.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RequestPrivacyExport202ResponseDataDownloadLink {
  /// Returns a new [RequestPrivacyExport202ResponseDataDownloadLink] instance.
  RequestPrivacyExport202ResponseDataDownloadLink({
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
      other is RequestPrivacyExport202ResponseDataDownloadLink &&
          other.expiresAt == expiresAt &&
          other.url == url;

  @override
  int get hashCode => expiresAt.hashCode + url.hashCode;

  factory RequestPrivacyExport202ResponseDataDownloadLink.fromJson(
    Map<String, dynamic> json,
  ) => _$RequestPrivacyExport202ResponseDataDownloadLinkFromJson(json);

  Map<String, dynamic> toJson() =>
      _$RequestPrivacyExport202ResponseDataDownloadLinkToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
