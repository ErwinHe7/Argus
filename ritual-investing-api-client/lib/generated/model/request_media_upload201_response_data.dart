//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'request_media_upload201_response_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RequestMediaUpload201ResponseData {
  /// Returns a new [RequestMediaUpload201ResponseData] instance.
  RequestMediaUpload201ResponseData({
    required this.expiresAt,

    required this.mediaId,

    required this.quarantineKey,

    required this.uploadUrl,
  });

  @JsonKey(name: r'expires_at', required: true, includeIfNull: false)
  final DateTime expiresAt;

  @JsonKey(name: r'media_id', required: true, includeIfNull: false)
  final String mediaId;

  @JsonKey(name: r'quarantine_key', required: true, includeIfNull: false)
  final String quarantineKey;

  @JsonKey(name: r'upload_url', required: true, includeIfNull: false)
  final String uploadUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestMediaUpload201ResponseData &&
          other.expiresAt == expiresAt &&
          other.mediaId == mediaId &&
          other.quarantineKey == quarantineKey &&
          other.uploadUrl == uploadUrl;

  @override
  int get hashCode =>
      expiresAt.hashCode +
      mediaId.hashCode +
      quarantineKey.hashCode +
      uploadUrl.hashCode;

  factory RequestMediaUpload201ResponseData.fromJson(
    Map<String, dynamic> json,
  ) => _$RequestMediaUpload201ResponseDataFromJson(json);

  Map<String, dynamic> toJson() =>
      _$RequestMediaUpload201ResponseDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
