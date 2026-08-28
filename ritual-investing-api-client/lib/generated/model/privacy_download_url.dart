//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'privacy_download_url.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PrivacyDownloadUrl {
  /// Returns a new [PrivacyDownloadUrl] instance.
  PrivacyDownloadUrl({required this.expiresAt, required this.url});

  @JsonKey(name: r'expires_at', required: true, includeIfNull: false)
  final DateTime expiresAt;

  @JsonKey(name: r'url', required: true, includeIfNull: false)
  final String url;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyDownloadUrl &&
          other.expiresAt == expiresAt &&
          other.url == url;

  @override
  int get hashCode => expiresAt.hashCode + url.hashCode;

  factory PrivacyDownloadUrl.fromJson(Map<String, dynamic> json) =>
      _$PrivacyDownloadUrlFromJson(json);

  Map<String, dynamic> toJson() => _$PrivacyDownloadUrlToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
