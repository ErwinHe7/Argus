//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'update_astrology_profile_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class UpdateAstrologyProfileRequest {
  /// Returns a new [UpdateAstrologyProfileRequest] instance.
  UpdateAstrologyProfileRequest({required this.birthDate});

  @JsonKey(name: r'birthDate', required: true, includeIfNull: false)
  final DateTime birthDate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateAstrologyProfileRequest && other.birthDate == birthDate;

  @override
  int get hashCode => birthDate.hashCode;

  factory UpdateAstrologyProfileRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateAstrologyProfileRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateAstrologyProfileRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
