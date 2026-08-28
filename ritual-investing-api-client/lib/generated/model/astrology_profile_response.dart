//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_audit200_response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/astrology_profile.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'astrology_profile_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AstrologyProfileResponse {
  /// Returns a new [AstrologyProfileResponse] instance.
  AstrologyProfileResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: true)
  final AstrologyProfile? data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ListAdminAudit200ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AstrologyProfileResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => (data == null ? 0 : data.hashCode) + meta.hashCode;

  factory AstrologyProfileResponse.fromJson(Map<String, dynamic> json) =>
      _$AstrologyProfileResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AstrologyProfileResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
