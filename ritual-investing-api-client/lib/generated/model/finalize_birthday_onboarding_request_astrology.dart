//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'finalize_birthday_onboarding_request_astrology.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FinalizeBirthdayOnboardingRequestAstrology {
  /// Returns a new [FinalizeBirthdayOnboardingRequestAstrology] instance.
  FinalizeBirthdayOnboardingRequestAstrology({required this.birthDate});

  @JsonKey(name: r'birth_date', required: true, includeIfNull: false)
  final DateTime birthDate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinalizeBirthdayOnboardingRequestAstrology &&
          other.birthDate == birthDate;

  @override
  int get hashCode => birthDate.hashCode;

  factory FinalizeBirthdayOnboardingRequestAstrology.fromJson(
    Map<String, dynamic> json,
  ) => _$FinalizeBirthdayOnboardingRequestAstrologyFromJson(json);

  Map<String, dynamic> toJson() =>
      _$FinalizeBirthdayOnboardingRequestAstrologyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
