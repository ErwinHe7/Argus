//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'finalize_onboarding_request_astrology.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FinalizeOnboardingRequestAstrology {
  /// Returns a new [FinalizeOnboardingRequestAstrology] instance.
  FinalizeOnboardingRequestAstrology({this.birthDate, required this.enabled});

  @JsonKey(name: r'birth_date', required: false, includeIfNull: false)
  final DateTime? birthDate;

  @JsonKey(name: r'enabled', required: true, includeIfNull: false)
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinalizeOnboardingRequestAstrology &&
          other.birthDate == birthDate &&
          other.enabled == enabled;

  @override
  int get hashCode => birthDate.hashCode + enabled.hashCode;

  factory FinalizeOnboardingRequestAstrology.fromJson(
    Map<String, dynamic> json,
  ) => _$FinalizeOnboardingRequestAstrologyFromJson(json);

  Map<String, dynamic> toJson() =>
      _$FinalizeOnboardingRequestAstrologyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
