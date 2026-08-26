// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_coven_qualification.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdminCovenQualificationCWProxy {
  AdminCovenQualification category(
    AdminCovenQualificationCategoryEnum category,
  );

  AdminCovenQualification currentVerificationId(String? currentVerificationId);

  AdminCovenQualification entryId(String entryId);

  AdminCovenQualification id(String id);

  AdminCovenQualification personName(String personName);

  AdminCovenQualification submittedBy(String? submittedBy);

  AdminCovenQualification validFrom(DateTime validFrom);

  AdminCovenQualification validTo(DateTime? validTo);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminCovenQualification(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminCovenQualification(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminCovenQualification call({
    AdminCovenQualificationCategoryEnum category,
    String? currentVerificationId,
    String entryId,
    String id,
    String personName,
    String? submittedBy,
    DateTime validFrom,
    DateTime? validTo,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAdminCovenQualification.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAdminCovenQualification.copyWith.fieldName(...)`
class _$AdminCovenQualificationCWProxyImpl
    implements _$AdminCovenQualificationCWProxy {
  const _$AdminCovenQualificationCWProxyImpl(this._value);

  final AdminCovenQualification _value;

  @override
  AdminCovenQualification category(
    AdminCovenQualificationCategoryEnum category,
  ) => this(category: category);

  @override
  AdminCovenQualification currentVerificationId(
    String? currentVerificationId,
  ) => this(currentVerificationId: currentVerificationId);

  @override
  AdminCovenQualification entryId(String entryId) => this(entryId: entryId);

  @override
  AdminCovenQualification id(String id) => this(id: id);

  @override
  AdminCovenQualification personName(String personName) =>
      this(personName: personName);

  @override
  AdminCovenQualification submittedBy(String? submittedBy) =>
      this(submittedBy: submittedBy);

  @override
  AdminCovenQualification validFrom(DateTime validFrom) =>
      this(validFrom: validFrom);

  @override
  AdminCovenQualification validTo(DateTime? validTo) => this(validTo: validTo);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminCovenQualification(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminCovenQualification(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminCovenQualification call({
    Object? category = const $CopyWithPlaceholder(),
    Object? currentVerificationId = const $CopyWithPlaceholder(),
    Object? entryId = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? personName = const $CopyWithPlaceholder(),
    Object? submittedBy = const $CopyWithPlaceholder(),
    Object? validFrom = const $CopyWithPlaceholder(),
    Object? validTo = const $CopyWithPlaceholder(),
  }) {
    return AdminCovenQualification(
      category: category == const $CopyWithPlaceholder()
          ? _value.category
          // ignore: cast_nullable_to_non_nullable
          : category as AdminCovenQualificationCategoryEnum,
      currentVerificationId:
          currentVerificationId == const $CopyWithPlaceholder()
          ? _value.currentVerificationId
          // ignore: cast_nullable_to_non_nullable
          : currentVerificationId as String?,
      entryId: entryId == const $CopyWithPlaceholder()
          ? _value.entryId
          // ignore: cast_nullable_to_non_nullable
          : entryId as String,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      personName: personName == const $CopyWithPlaceholder()
          ? _value.personName
          // ignore: cast_nullable_to_non_nullable
          : personName as String,
      submittedBy: submittedBy == const $CopyWithPlaceholder()
          ? _value.submittedBy
          // ignore: cast_nullable_to_non_nullable
          : submittedBy as String?,
      validFrom: validFrom == const $CopyWithPlaceholder()
          ? _value.validFrom
          // ignore: cast_nullable_to_non_nullable
          : validFrom as DateTime,
      validTo: validTo == const $CopyWithPlaceholder()
          ? _value.validTo
          // ignore: cast_nullable_to_non_nullable
          : validTo as DateTime?,
    );
  }
}

extension $AdminCovenQualificationCopyWith on AdminCovenQualification {
  /// Returns a callable class that can be used as follows: `instanceOfAdminCovenQualification.copyWith(...)` or like so:`instanceOfAdminCovenQualification.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdminCovenQualificationCWProxy get copyWith =>
      _$AdminCovenQualificationCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminCovenQualification _$AdminCovenQualificationFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'AdminCovenQualification',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'category',
        'current_verification_id',
        'entry_id',
        'id',
        'person_name',
        'submitted_by',
        'valid_from',
        'valid_to',
      ],
    );
    final val = AdminCovenQualification(
      category: $checkedConvert(
        'category',
        (v) => $enumDecode(
          _$AdminCovenQualificationCategoryEnumEnumMap,
          v,
          unknownValue:
              AdminCovenQualificationCategoryEnum.unknownDefaultOpenApi,
        ),
      ),
      currentVerificationId: $checkedConvert(
        'current_verification_id',
        (v) => v as String?,
      ),
      entryId: $checkedConvert('entry_id', (v) => v as String),
      id: $checkedConvert('id', (v) => v as String),
      personName: $checkedConvert('person_name', (v) => v as String),
      submittedBy: $checkedConvert('submitted_by', (v) => v as String?),
      validFrom: $checkedConvert(
        'valid_from',
        (v) => DateTime.parse(v as String),
      ),
      validTo: $checkedConvert(
        'valid_to',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'currentVerificationId': 'current_verification_id',
    'entryId': 'entry_id',
    'personName': 'person_name',
    'submittedBy': 'submitted_by',
    'validFrom': 'valid_from',
    'validTo': 'valid_to',
  },
);

Map<String, dynamic> _$AdminCovenQualificationToJson(
  AdminCovenQualification instance,
) => <String, dynamic>{
  'category': _$AdminCovenQualificationCategoryEnumEnumMap[instance.category]!,
  'current_verification_id': instance.currentVerificationId,
  'entry_id': instance.entryId,
  'id': instance.id,
  'person_name': instance.personName,
  'submitted_by': instance.submittedBy,
  'valid_from': instance.validFrom.toIso8601String(),
  'valid_to': instance.validTo?.toIso8601String(),
};

const _$AdminCovenQualificationCategoryEnumEnumMap = {
  AdminCovenQualificationCategoryEnum.founder: 'founder',
  AdminCovenQualificationCategoryEnum.owner: 'owner',
  AdminCovenQualificationCategoryEnum.chiefExecutive: 'chief_executive',
  AdminCovenQualificationCategoryEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
