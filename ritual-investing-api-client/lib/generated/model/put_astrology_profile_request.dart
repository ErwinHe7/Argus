//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'put_astrology_profile_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PutAstrologyProfileRequest {
  /// Returns a new [PutAstrologyProfileRequest] instance.
  PutAstrologyProfileRequest({required this.birthDate});

  @JsonKey(name: r'birth_date', required: true, includeIfNull: false)
  final DateTime birthDate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PutAstrologyProfileRequest && other.birthDate == birthDate;

  @override
  int get hashCode => birthDate.hashCode;

  factory PutAstrologyProfileRequest.fromJson(Map<String, dynamic> json) =>
      _$PutAstrologyProfileRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PutAstrologyProfileRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
