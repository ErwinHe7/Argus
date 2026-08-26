//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_media200_response_data_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminMedia200ResponseDataInner {
  /// Returns a new [ListAdminMedia200ResponseDataInner] instance.
  ListAdminMedia200ResponseDataInner({
    required this.byteSize,

    required this.checksum,

    required this.derivativeStatus,

    required this.id,

    required this.mimeType,

    required this.quarantineStatus,

    required this.referenceCount,

    required this.scanResult,

    required this.uploadStatus,

    required this.version,
  });

  // minimum: 0
  @JsonKey(name: r'byte_size', required: true, includeIfNull: false)
  final int byteSize;

  @JsonKey(name: r'checksum', required: true, includeIfNull: false)
  final String checksum;

  @JsonKey(
    name: r'derivative_status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: ListAdminMedia200ResponseDataInnerDerivativeStatusEnum
        .unknownDefaultOpenApi,
  )
  final ListAdminMedia200ResponseDataInnerDerivativeStatusEnum derivativeStatus;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(
    name: r'mime_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        ListAdminMedia200ResponseDataInnerMimeTypeEnum.unknownDefaultOpenApi,
  )
  final ListAdminMedia200ResponseDataInnerMimeTypeEnum mimeType;

  @JsonKey(
    name: r'quarantine_status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: ListAdminMedia200ResponseDataInnerQuarantineStatusEnum
        .unknownDefaultOpenApi,
  )
  final ListAdminMedia200ResponseDataInnerQuarantineStatusEnum quarantineStatus;

  // minimum: 0
  @JsonKey(name: r'reference_count', required: true, includeIfNull: false)
  final int referenceCount;

  @JsonKey(name: r'scan_result', required: true, includeIfNull: true)
  final String? scanResult;

  @JsonKey(
    name: r'upload_status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: ListAdminMedia200ResponseDataInnerUploadStatusEnum
        .unknownDefaultOpenApi,
  )
  final ListAdminMedia200ResponseDataInnerUploadStatusEnum uploadStatus;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListAdminMedia200ResponseDataInner &&
          other.byteSize == byteSize &&
          other.checksum == checksum &&
          other.derivativeStatus == derivativeStatus &&
          other.id == id &&
          other.mimeType == mimeType &&
          other.quarantineStatus == quarantineStatus &&
          other.referenceCount == referenceCount &&
          other.scanResult == scanResult &&
          other.uploadStatus == uploadStatus &&
          other.version == version;

  @override
  int get hashCode =>
      byteSize.hashCode +
      checksum.hashCode +
      derivativeStatus.hashCode +
      id.hashCode +
      mimeType.hashCode +
      quarantineStatus.hashCode +
      referenceCount.hashCode +
      (scanResult == null ? 0 : scanResult.hashCode) +
      uploadStatus.hashCode +
      version.hashCode;

  factory ListAdminMedia200ResponseDataInner.fromJson(
    Map<String, dynamic> json,
  ) => _$ListAdminMedia200ResponseDataInnerFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ListAdminMedia200ResponseDataInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ListAdminMedia200ResponseDataInnerDerivativeStatusEnum {
  @JsonValue(r'unavailable')
  unavailable(r'unavailable'),
  @JsonValue(r'uploading')
  uploading(r'uploading'),
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'retired')
  retired(r'retired'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminMedia200ResponseDataInnerDerivativeStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum ListAdminMedia200ResponseDataInnerMimeTypeEnum {
  @JsonValue(r'image/jpeg')
  imageSlashJpeg(r'image/jpeg'),
  @JsonValue(r'image/png')
  imageSlashPng(r'image/png'),
  @JsonValue(r'image/webp')
  imageSlashWebp(r'image/webp'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminMedia200ResponseDataInnerMimeTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum ListAdminMedia200ResponseDataInnerQuarantineStatusEnum {
  @JsonValue(r'pending')
  pending(r'pending'),
  @JsonValue(r'clear')
  clear(r'clear'),
  @JsonValue(r'rejected')
  rejected(r'rejected'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminMedia200ResponseDataInnerQuarantineStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum ListAdminMedia200ResponseDataInnerUploadStatusEnum {
  @JsonValue(r'issued')
  issued(r'issued'),
  @JsonValue(r'uploaded')
  uploaded(r'uploaded'),
  @JsonValue(r'scanning')
  scanning(r'scanning'),
  @JsonValue(r'accepted')
  accepted(r'accepted'),
  @JsonValue(r'rejected')
  rejected(r'rejected'),
  @JsonValue(r'expired')
  expired(r'expired'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminMedia200ResponseDataInnerUploadStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
