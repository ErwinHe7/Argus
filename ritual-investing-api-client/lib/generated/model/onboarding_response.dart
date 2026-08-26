//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/onboarding_state.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'onboarding_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OnboardingResponse {
  /// Returns a new [OnboardingResponse] instance.
  OnboardingResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final OnboardingState data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingResponse && other.data == data && other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory OnboardingResponse.fromJson(Map<String, dynamic> json) =>
      _$OnboardingResponseFromJson(json);

  Map<String, dynamic> toJson() => _$OnboardingResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
