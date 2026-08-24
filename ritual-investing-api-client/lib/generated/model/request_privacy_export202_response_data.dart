//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/request_privacy_export202_response_data_download_link.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'request_privacy_export202_response_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RequestPrivacyExport202ResponseData {
  /// Returns a new [RequestPrivacyExport202ResponseData] instance.
  RequestPrivacyExport202ResponseData({
    required this.completedAt,

    required this.downloadLink,

    required this.expiresAt,

    required this.failureCode,

    required this.format,

    required this.id,

    required this.requestType,

    required this.snapshotAt,

    required this.status,
  });

  @JsonKey(name: r'completed_at', required: true, includeIfNull: true)
  final DateTime? completedAt;

  @JsonKey(name: r'download_link', required: true, includeIfNull: true)
  final RequestPrivacyExport202ResponseDataDownloadLink? downloadLink;

  @JsonKey(name: r'expires_at', required: true, includeIfNull: true)
  final DateTime? expiresAt;

  @JsonKey(name: r'failure_code', required: true, includeIfNull: true)
  final String? failureCode;

  @JsonKey(
    name: r'format',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        RequestPrivacyExport202ResponseDataFormatEnum.unknownDefaultOpenApi,
  )
  final RequestPrivacyExport202ResponseDataFormatEnum format;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(
    name: r'request_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RequestPrivacyExport202ResponseDataRequestTypeEnum
        .unknownDefaultOpenApi,
  )
  final RequestPrivacyExport202ResponseDataRequestTypeEnum requestType;

  @JsonKey(name: r'snapshot_at', required: true, includeIfNull: true)
  final DateTime? snapshotAt;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        RequestPrivacyExport202ResponseDataStatusEnum.unknownDefaultOpenApi,
  )
  final RequestPrivacyExport202ResponseDataStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestPrivacyExport202ResponseData &&
          other.completedAt == completedAt &&
          other.downloadLink == downloadLink &&
          other.expiresAt == expiresAt &&
          other.failureCode == failureCode &&
          other.format == format &&
          other.id == id &&
          other.requestType == requestType &&
          other.snapshotAt == snapshotAt &&
          other.status == status;

  @override
  int get hashCode =>
      (completedAt == null ? 0 : completedAt.hashCode) +
      (downloadLink == null ? 0 : downloadLink.hashCode) +
      (expiresAt == null ? 0 : expiresAt.hashCode) +
      (failureCode == null ? 0 : failureCode.hashCode) +
      format.hashCode +
      id.hashCode +
      requestType.hashCode +
      (snapshotAt == null ? 0 : snapshotAt.hashCode) +
      status.hashCode;

  factory RequestPrivacyExport202ResponseData.fromJson(
    Map<String, dynamic> json,
  ) => _$RequestPrivacyExport202ResponseDataFromJson(json);

  Map<String, dynamic> toJson() =>
      _$RequestPrivacyExport202ResponseDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RequestPrivacyExport202ResponseDataFormatEnum {
  @JsonValue(r'zip')
  zip(r'zip'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RequestPrivacyExport202ResponseDataFormatEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum RequestPrivacyExport202ResponseDataRequestTypeEnum {
  @JsonValue(r'export')
  export_(r'export'),
  @JsonValue(r'delete')
  delete(r'delete'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RequestPrivacyExport202ResponseDataRequestTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum RequestPrivacyExport202ResponseDataStatusEnum {
  @JsonValue(r'requested')
  requested(r'requested'),
  @JsonValue(r'verified')
  verified(r'verified'),
  @JsonValue(r'queued')
  queued(r'queued'),
  @JsonValue(r'processing')
  processing(r'processing'),
  @JsonValue(r'completed')
  completed(r'completed'),
  @JsonValue(r'failed')
  failed(r'failed'),
  @JsonValue(r'cancelled')
  cancelled(r'cancelled'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RequestPrivacyExport202ResponseDataStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
