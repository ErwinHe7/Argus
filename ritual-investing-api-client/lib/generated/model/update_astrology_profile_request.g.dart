// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_astrology_profile_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$UpdateAstrologyProfileRequestCWProxy {
  UpdateAstrologyProfileRequest birthDate(DateTime birthDate);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UpdateAstrologyProfileRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UpdateAstrologyProfileRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  UpdateAstrologyProfileRequest call({DateTime birthDate});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfUpdateAstrologyProfileRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfUpdateAstrologyProfileRequest.copyWith.fieldName(...)`
class _$UpdateAstrologyProfileRequestCWProxyImpl
    implements _$UpdateAstrologyProfileRequestCWProxy {
  const _$UpdateAstrologyProfileRequestCWProxyImpl(this._value);

  final UpdateAstrologyProfileRequest _value;

  @override
  UpdateAstrologyProfileRequest birthDate(DateTime birthDate) =>
      this(birthDate: birthDate);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UpdateAstrologyProfileRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UpdateAstrologyProfileRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  UpdateAstrologyProfileRequest call({
    Object? birthDate = const $CopyWithPlaceholder(),
  }) {
    return UpdateAstrologyProfileRequest(
      birthDate: birthDate == const $CopyWithPlaceholder()
          ? _value.birthDate
          // ignore: cast_nullable_to_non_nullable
          : birthDate as DateTime,
    );
  }
}

extension $UpdateAstrologyProfileRequestCopyWith
    on UpdateAstrologyProfileRequest {
  /// Returns a callable class that can be used as follows: `instanceOfUpdateAstrologyProfileRequest.copyWith(...)` or like so:`instanceOfUpdateAstrologyProfileRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$UpdateAstrologyProfileRequestCWProxy get copyWith =>
      _$UpdateAstrologyProfileRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateAstrologyProfileRequest _$UpdateAstrologyProfileRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('UpdateAstrologyProfileRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['birthDate']);
  final val = UpdateAstrologyProfileRequest(
    birthDate: $checkedConvert('birthDate', (v) => DateTime.parse(v as String)),
  );
  return val;
});

Map<String, dynamic> _$UpdateAstrologyProfileRequestToJson(
  UpdateAstrologyProfileRequest instance,
) => <String, dynamic>{'birthDate': instance.birthDate.toIso8601String()};
