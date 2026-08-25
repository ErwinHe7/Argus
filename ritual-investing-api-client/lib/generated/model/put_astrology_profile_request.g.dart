// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'put_astrology_profile_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PutAstrologyProfileRequestCWProxy {
  PutAstrologyProfileRequest birthDate(DateTime birthDate);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PutAstrologyProfileRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PutAstrologyProfileRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PutAstrologyProfileRequest call({DateTime birthDate});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPutAstrologyProfileRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPutAstrologyProfileRequest.copyWith.fieldName(...)`
class _$PutAstrologyProfileRequestCWProxyImpl
    implements _$PutAstrologyProfileRequestCWProxy {
  const _$PutAstrologyProfileRequestCWProxyImpl(this._value);

  final PutAstrologyProfileRequest _value;

  @override
  PutAstrologyProfileRequest birthDate(DateTime birthDate) =>
      this(birthDate: birthDate);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PutAstrologyProfileRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PutAstrologyProfileRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PutAstrologyProfileRequest call({
    Object? birthDate = const $CopyWithPlaceholder(),
  }) {
    return PutAstrologyProfileRequest(
      birthDate: birthDate == const $CopyWithPlaceholder()
          ? _value.birthDate
          // ignore: cast_nullable_to_non_nullable
          : birthDate as DateTime,
    );
  }
}

extension $PutAstrologyProfileRequestCopyWith on PutAstrologyProfileRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPutAstrologyProfileRequest.copyWith(...)` or like so:`instanceOfPutAstrologyProfileRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PutAstrologyProfileRequestCWProxy get copyWith =>
      _$PutAstrologyProfileRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PutAstrologyProfileRequest _$PutAstrologyProfileRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PutAstrologyProfileRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['birth_date']);
  final val = PutAstrologyProfileRequest(
    birthDate: $checkedConvert(
      'birth_date',
      (v) => DateTime.parse(v as String),
    ),
  );
  return val;
}, fieldKeyMap: const {'birthDate': 'birth_date'});

Map<String, dynamic> _$PutAstrologyProfileRequestToJson(
  PutAstrologyProfileRequest instance,
) => <String, dynamic>{'birth_date': instance.birthDate.toIso8601String()};
