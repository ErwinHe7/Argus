// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_coven_qualification_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminCovenQualificationRequestCWProxy {
  CreateAdminCovenQualificationRequest category(
    CreateAdminCovenQualificationRequestCategoryEnum category,
  );

  CreateAdminCovenQualificationRequest personName(String personName);

  CreateAdminCovenQualificationRequest validFrom(DateTime validFrom);

  CreateAdminCovenQualificationRequest validTo(DateTime? validTo);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminCovenQualificationRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminCovenQualificationRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminCovenQualificationRequest call({
    CreateAdminCovenQualificationRequestCategoryEnum category,
    String personName,
    DateTime validFrom,
    DateTime? validTo,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminCovenQualificationRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminCovenQualificationRequest.copyWith.fieldName(...)`
class _$CreateAdminCovenQualificationRequestCWProxyImpl
    implements _$CreateAdminCovenQualificationRequestCWProxy {
  const _$CreateAdminCovenQualificationRequestCWProxyImpl(this._value);

  final CreateAdminCovenQualificationRequest _value;

  @override
  CreateAdminCovenQualificationRequest category(
    CreateAdminCovenQualificationRequestCategoryEnum category,
  ) => this(category: category);

  @override
  CreateAdminCovenQualificationRequest personName(String personName) =>
      this(personName: personName);

  @override
  CreateAdminCovenQualificationRequest validFrom(DateTime validFrom) =>
      this(validFrom: validFrom);

  @override
  CreateAdminCovenQualificationRequest validTo(DateTime? validTo) =>
      this(validTo: validTo);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminCovenQualificationRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminCovenQualificationRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminCovenQualificationRequest call({
    Object? category = const $CopyWithPlaceholder(),
    Object? personName = const $CopyWithPlaceholder(),
    Object? validFrom = const $CopyWithPlaceholder(),
    Object? validTo = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminCovenQualificationRequest(
      category: category == const $CopyWithPlaceholder()
          ? _value.category
          // ignore: cast_nullable_to_non_nullable
          : category as CreateAdminCovenQualificationRequestCategoryEnum,
      personName: personName == const $CopyWithPlaceholder()
          ? _value.personName
          // ignore: cast_nullable_to_non_nullable
          : personName as String,
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

extension $CreateAdminCovenQualificationRequestCopyWith
    on CreateAdminCovenQualificationRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminCovenQualificationRequest.copyWith(...)` or like so:`instanceOfCreateAdminCovenQualificationRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminCovenQualificationRequestCWProxy get copyWith =>
      _$CreateAdminCovenQualificationRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminCovenQualificationRequest
_$CreateAdminCovenQualificationRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'CreateAdminCovenQualificationRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['category', 'person_name', 'valid_from'],
        );
        final val = CreateAdminCovenQualificationRequest(
          category: $checkedConvert(
            'category',
            (v) => $enumDecode(
              _$CreateAdminCovenQualificationRequestCategoryEnumEnumMap,
              v,
              unknownValue: CreateAdminCovenQualificationRequestCategoryEnum
                  .unknownDefaultOpenApi,
            ),
          ),
          personName: $checkedConvert('person_name', (v) => v as String),
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
        'personName': 'person_name',
        'validFrom': 'valid_from',
        'validTo': 'valid_to',
      },
    );

Map<String, dynamic> _$CreateAdminCovenQualificationRequestToJson(
  CreateAdminCovenQualificationRequest instance,
) => <String, dynamic>{
  'category':
      _$CreateAdminCovenQualificationRequestCategoryEnumEnumMap[instance
          .category]!,
  'person_name': instance.personName,
  'valid_from': instance.validFrom.toIso8601String(),
  'valid_to': ?instance.validTo?.toIso8601String(),
};

const _$CreateAdminCovenQualificationRequestCategoryEnumEnumMap = {
  CreateAdminCovenQualificationRequestCategoryEnum.founder: 'founder',
  CreateAdminCovenQualificationRequestCategoryEnum.owner: 'owner',
  CreateAdminCovenQualificationRequestCategoryEnum.chiefExecutive:
      'chief_executive',
  CreateAdminCovenQualificationRequestCategoryEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
