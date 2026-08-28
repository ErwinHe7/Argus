//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_upload_intent_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateUploadIntentRequest {
  /// Returns a new [CreateUploadIntentRequest] instance.
  CreateUploadIntentRequest({
    required this.bucketId,

    required this.expiresAt,

    required this.maxBytes,

    required this.mimeType,

    required this.objectPath,
  });

  @JsonKey(
    name: r'bucketId',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CreateUploadIntentRequestBucketIdEnum.unknownDefaultOpenApi,
  )
  final CreateUploadIntentRequestBucketIdEnum bucketId;

  @JsonKey(name: r'expiresAt', required: true, includeIfNull: true)
  final DateTime? expiresAt;

  // minimum: 1
  // maximum: 10485760
  @JsonKey(name: r'maxBytes', required: true, includeIfNull: false)
  final int maxBytes;

  @JsonKey(
    name: r'mimeType',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CreateUploadIntentRequestMimeTypeEnum.unknownDefaultOpenApi,
  )
  final CreateUploadIntentRequestMimeTypeEnum mimeType;

  @JsonKey(name: r'objectPath', required: true, includeIfNull: false)
  final String objectPath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateUploadIntentRequest &&
          other.bucketId == bucketId &&
          other.expiresAt == expiresAt &&
          other.maxBytes == maxBytes &&
          other.mimeType == mimeType &&
          other.objectPath == objectPath;

  @override
  int get hashCode =>
      bucketId.hashCode +
      (expiresAt == null ? 0 : expiresAt.hashCode) +
      maxBytes.hashCode +
      mimeType.hashCode +
      objectPath.hashCode;

  factory CreateUploadIntentRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateUploadIntentRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateUploadIntentRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateUploadIntentRequestBucketIdEnum {
  @JsonValue(r'member-media')
  memberMedia(r'member-media'),
  @JsonValue(r'media-quarantine')
  mediaQuarantine(r'media-quarantine'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateUploadIntentRequestBucketIdEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CreateUploadIntentRequestMimeTypeEnum {
  @JsonValue(r'image/jpeg')
  imageSlashJpeg(r'image/jpeg'),
  @JsonValue(r'image/png')
  imageSlashPng(r'image/png'),
  @JsonValue(r'image/webp')
  imageSlashWebp(r'image/webp'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateUploadIntentRequestMimeTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
