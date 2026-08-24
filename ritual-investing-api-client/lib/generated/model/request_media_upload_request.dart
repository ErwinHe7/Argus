//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'request_media_upload_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RequestMediaUploadRequest {
  /// Returns a new [RequestMediaUploadRequest] instance.
  RequestMediaUploadRequest({
    required this.byteSize,

    required this.checksum,

    required this.mimeType,
  });

  // minimum: 0
  // maximum: 10485760
  @JsonKey(name: r'byte_size', required: true, includeIfNull: false)
  final int byteSize;

  @JsonKey(name: r'checksum', required: true, includeIfNull: false)
  final String checksum;

  @JsonKey(
    name: r'mime_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        RequestMediaUploadRequestMimeTypeEnum.unknownDefaultOpenApi,
  )
  final RequestMediaUploadRequestMimeTypeEnum mimeType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestMediaUploadRequest &&
          other.byteSize == byteSize &&
          other.checksum == checksum &&
          other.mimeType == mimeType;

  @override
  int get hashCode => byteSize.hashCode + checksum.hashCode + mimeType.hashCode;

  factory RequestMediaUploadRequest.fromJson(Map<String, dynamic> json) =>
      _$RequestMediaUploadRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RequestMediaUploadRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RequestMediaUploadRequestMimeTypeEnum {
  @JsonValue(r'image/jpeg')
  imageSlashJpeg(r'image/jpeg'),
  @JsonValue(r'image/png')
  imageSlashPng(r'image/png'),
  @JsonValue(r'image/webp')
  imageSlashWebp(r'image/webp'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RequestMediaUploadRequestMimeTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
