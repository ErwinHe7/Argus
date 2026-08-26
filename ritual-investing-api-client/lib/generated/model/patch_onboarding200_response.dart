//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/onboarding_state.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_onboarding200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchOnboarding200Response {
  /// Returns a new [PatchOnboarding200Response] instance.
  PatchOnboarding200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final OnboardingState data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchOnboarding200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory PatchOnboarding200Response.fromJson(Map<String, dynamic> json) =>
      _$PatchOnboarding200ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PatchOnboarding200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
