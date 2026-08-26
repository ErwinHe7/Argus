//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'request_privacy_export_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RequestPrivacyExportRequest {
  /// Returns a new [RequestPrivacyExportRequest] instance.
  RequestPrivacyExportRequest({required this.format});

  @JsonKey(
    name: r'format',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        RequestPrivacyExportRequestFormatEnum.unknownDefaultOpenApi,
  )
  final RequestPrivacyExportRequestFormatEnum format;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestPrivacyExportRequest && other.format == format;

  @override
  int get hashCode => format.hashCode;

  factory RequestPrivacyExportRequest.fromJson(Map<String, dynamic> json) =>
      _$RequestPrivacyExportRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RequestPrivacyExportRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RequestPrivacyExportRequestFormatEnum {
  @JsonValue(r'zip')
  zip(r'zip'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RequestPrivacyExportRequestFormatEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
