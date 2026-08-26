//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'admin_coven_qualification.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AdminCovenQualification {
  /// Returns a new [AdminCovenQualification] instance.
  AdminCovenQualification({
    required this.category,

    required this.currentVerificationId,

    required this.entryId,

    required this.id,

    required this.personName,

    required this.submittedBy,

    required this.validFrom,

    required this.validTo,
  });

  @JsonKey(
    name: r'category',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminCovenQualificationCategoryEnum.unknownDefaultOpenApi,
  )
  final AdminCovenQualificationCategoryEnum category;

  @JsonKey(
    name: r'current_verification_id',
    required: true,
    includeIfNull: true,
  )
  final String? currentVerificationId;

  @JsonKey(name: r'entry_id', required: true, includeIfNull: false)
  final String entryId;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'person_name', required: true, includeIfNull: false)
  final String personName;

  @JsonKey(name: r'submitted_by', required: true, includeIfNull: true)
  final String? submittedBy;

  @JsonKey(name: r'valid_from', required: true, includeIfNull: false)
  final DateTime validFrom;

  @JsonKey(name: r'valid_to', required: true, includeIfNull: true)
  final DateTime? validTo;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminCovenQualification &&
          other.category == category &&
          other.currentVerificationId == currentVerificationId &&
          other.entryId == entryId &&
          other.id == id &&
          other.personName == personName &&
          other.submittedBy == submittedBy &&
          other.validFrom == validFrom &&
          other.validTo == validTo;

  @override
  int get hashCode =>
      category.hashCode +
      (currentVerificationId == null ? 0 : currentVerificationId.hashCode) +
      entryId.hashCode +
      id.hashCode +
      personName.hashCode +
      (submittedBy == null ? 0 : submittedBy.hashCode) +
      validFrom.hashCode +
      (validTo == null ? 0 : validTo.hashCode);

  factory AdminCovenQualification.fromJson(Map<String, dynamic> json) =>
      _$AdminCovenQualificationFromJson(json);

  Map<String, dynamic> toJson() => _$AdminCovenQualificationToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AdminCovenQualificationCategoryEnum {
  @JsonValue(r'founder')
  founder(r'founder'),
  @JsonValue(r'owner')
  owner(r'owner'),
  @JsonValue(r'chief_executive')
  chiefExecutive(r'chief_executive'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminCovenQualificationCategoryEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
