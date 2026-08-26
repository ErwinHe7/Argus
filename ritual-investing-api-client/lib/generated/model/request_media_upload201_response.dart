//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/request_media_upload201_response_data.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'request_media_upload201_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RequestMediaUpload201Response {
  /// Returns a new [RequestMediaUpload201Response] instance.
  RequestMediaUpload201Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final RequestMediaUpload201ResponseData data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestMediaUpload201Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory RequestMediaUpload201Response.fromJson(Map<String, dynamic> json) =>
      _$RequestMediaUpload201ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$RequestMediaUpload201ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
