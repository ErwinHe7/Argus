// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_astrology_profile_response_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DeleteAstrologyProfileResponseDataCWProxy {
  DeleteAstrologyProfileResponseData removed(bool removed);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DeleteAstrologyProfileResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DeleteAstrologyProfileResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  DeleteAstrologyProfileResponseData call({bool removed});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDeleteAstrologyProfileResponseData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDeleteAstrologyProfileResponseData.copyWith.fieldName(...)`
class _$DeleteAstrologyProfileResponseDataCWProxyImpl
    implements _$DeleteAstrologyProfileResponseDataCWProxy {
  const _$DeleteAstrologyProfileResponseDataCWProxyImpl(this._value);

  final DeleteAstrologyProfileResponseData _value;

  @override
  DeleteAstrologyProfileResponseData removed(bool removed) =>
      this(removed: removed);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DeleteAstrologyProfileResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DeleteAstrologyProfileResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  DeleteAstrologyProfileResponseData call({
    Object? removed = const $CopyWithPlaceholder(),
  }) {
    return DeleteAstrologyProfileResponseData(
      removed: removed == const $CopyWithPlaceholder()
          ? _value.removed
          // ignore: cast_nullable_to_non_nullable
          : removed as bool,
    );
  }
}

extension $DeleteAstrologyProfileResponseDataCopyWith
    on DeleteAstrologyProfileResponseData {
  /// Returns a callable class that can be used as follows: `instanceOfDeleteAstrologyProfileResponseData.copyWith(...)` or like so:`instanceOfDeleteAstrologyProfileResponseData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DeleteAstrologyProfileResponseDataCWProxy get copyWith =>
      _$DeleteAstrologyProfileResponseDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeleteAstrologyProfileResponseData _$DeleteAstrologyProfileResponseDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DeleteAstrologyProfileResponseData', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['removed']);
  final val = DeleteAstrologyProfileResponseData(
    removed: $checkedConvert('removed', (v) => v as bool),
  );
  return val;
});

Map<String, dynamic> _$DeleteAstrologyProfileResponseDataToJson(
  DeleteAstrologyProfileResponseData instance,
) => <String, dynamic>{'removed': instance.removed};
