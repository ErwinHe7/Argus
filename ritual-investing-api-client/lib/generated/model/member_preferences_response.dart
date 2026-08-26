//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/member_preferences.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'member_preferences_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemberPreferencesResponse {
  /// Returns a new [MemberPreferencesResponse] instance.
  MemberPreferencesResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final MemberPreferences data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberPreferencesResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory MemberPreferencesResponse.fromJson(Map<String, dynamic> json) =>
      _$MemberPreferencesResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MemberPreferencesResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
