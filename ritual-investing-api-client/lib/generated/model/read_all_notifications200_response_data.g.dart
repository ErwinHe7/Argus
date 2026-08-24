// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'read_all_notifications200_response_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReadAllNotifications200ResponseDataCWProxy {
  ReadAllNotifications200ResponseData updatedCount(int updatedCount);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReadAllNotifications200ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReadAllNotifications200ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  ReadAllNotifications200ResponseData call({int updatedCount});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfReadAllNotifications200ResponseData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfReadAllNotifications200ResponseData.copyWith.fieldName(...)`
class _$ReadAllNotifications200ResponseDataCWProxyImpl
    implements _$ReadAllNotifications200ResponseDataCWProxy {
  const _$ReadAllNotifications200ResponseDataCWProxyImpl(this._value);

  final ReadAllNotifications200ResponseData _value;

  @override
  ReadAllNotifications200ResponseData updatedCount(int updatedCount) =>
      this(updatedCount: updatedCount);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReadAllNotifications200ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReadAllNotifications200ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  ReadAllNotifications200ResponseData call({
    Object? updatedCount = const $CopyWithPlaceholder(),
  }) {
    return ReadAllNotifications200ResponseData(
      updatedCount: updatedCount == const $CopyWithPlaceholder()
          ? _value.updatedCount
          // ignore: cast_nullable_to_non_nullable
          : updatedCount as int,
    );
  }
}

extension $ReadAllNotifications200ResponseDataCopyWith
    on ReadAllNotifications200ResponseData {
  /// Returns a callable class that can be used as follows: `instanceOfReadAllNotifications200ResponseData.copyWith(...)` or like so:`instanceOfReadAllNotifications200ResponseData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ReadAllNotifications200ResponseDataCWProxy get copyWith =>
      _$ReadAllNotifications200ResponseDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReadAllNotifications200ResponseData
_$ReadAllNotifications200ResponseDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReadAllNotifications200ResponseData', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['updated_count']);
      final val = ReadAllNotifications200ResponseData(
        updatedCount: $checkedConvert(
          'updated_count',
          (v) => (v as num).toInt(),
        ),
      );
      return val;
    }, fieldKeyMap: const {'updatedCount': 'updated_count'});

Map<String, dynamic> _$ReadAllNotifications200ResponseDataToJson(
  ReadAllNotifications200ResponseData instance,
) => <String, dynamic>{'updated_count': instance.updatedCount};
