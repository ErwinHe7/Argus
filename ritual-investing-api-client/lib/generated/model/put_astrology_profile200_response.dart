//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/astrology_profile.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'put_astrology_profile200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PutAstrologyProfile200Response {
  /// Returns a new [PutAstrologyProfile200Response] instance.
  PutAstrologyProfile200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final AstrologyProfile data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PutAstrologyProfile200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory PutAstrologyProfile200Response.fromJson(Map<String, dynamic> json) =>
      _$PutAstrologyProfile200ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PutAstrologyProfile200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
