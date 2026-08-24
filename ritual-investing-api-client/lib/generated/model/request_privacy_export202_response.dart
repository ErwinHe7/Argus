//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/request_privacy_export202_response_data.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'request_privacy_export202_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RequestPrivacyExport202Response {
  /// Returns a new [RequestPrivacyExport202Response] instance.
  RequestPrivacyExport202Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final RequestPrivacyExport202ResponseData data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestPrivacyExport202Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory RequestPrivacyExport202Response.fromJson(Map<String, dynamic> json) =>
      _$RequestPrivacyExport202ResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$RequestPrivacyExport202ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
