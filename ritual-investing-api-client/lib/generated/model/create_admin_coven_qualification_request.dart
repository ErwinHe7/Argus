//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_admin_coven_qualification_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateAdminCovenQualificationRequest {
  /// Returns a new [CreateAdminCovenQualificationRequest] instance.
  CreateAdminCovenQualificationRequest({
    required this.category,

    required this.personName,

    required this.validFrom,

    this.validTo,
  });

  @JsonKey(
    name: r'category',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CreateAdminCovenQualificationRequestCategoryEnum.unknownDefaultOpenApi,
  )
  final CreateAdminCovenQualificationRequestCategoryEnum category;

  @JsonKey(name: r'person_name', required: true, includeIfNull: false)
  final String personName;

  @JsonKey(name: r'valid_from', required: true, includeIfNull: false)
  final DateTime validFrom;

  @JsonKey(name: r'valid_to', required: false, includeIfNull: false)
  final DateTime? validTo;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateAdminCovenQualificationRequest &&
          other.category == category &&
          other.personName == personName &&
          other.validFrom == validFrom &&
          other.validTo == validTo;

  @override
  int get hashCode =>
      category.hashCode +
      personName.hashCode +
      validFrom.hashCode +
      (validTo == null ? 0 : validTo.hashCode);

  factory CreateAdminCovenQualificationRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateAdminCovenQualificationRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateAdminCovenQualificationRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateAdminCovenQualificationRequestCategoryEnum {
  @JsonValue(r'founder')
  founder(r'founder'),
  @JsonValue(r'owner')
  owner(r'owner'),
  @JsonValue(r'chief_executive')
  chiefExecutive(r'chief_executive'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateAdminCovenQualificationRequestCategoryEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
