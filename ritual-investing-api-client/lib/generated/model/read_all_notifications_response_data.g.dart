// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'read_all_notifications_response_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReadAllNotificationsResponseDataCWProxy {
  ReadAllNotificationsResponseData updatedCount(int updatedCount);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReadAllNotificationsResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReadAllNotificationsResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  ReadAllNotificationsResponseData call({int updatedCount});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfReadAllNotificationsResponseData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfReadAllNotificationsResponseData.copyWith.fieldName(...)`
class _$ReadAllNotificationsResponseDataCWProxyImpl
    implements _$ReadAllNotificationsResponseDataCWProxy {
  const _$ReadAllNotificationsResponseDataCWProxyImpl(this._value);

  final ReadAllNotificationsResponseData _value;

  @override
  ReadAllNotificationsResponseData updatedCount(int updatedCount) =>
      this(updatedCount: updatedCount);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReadAllNotificationsResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReadAllNotificationsResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  ReadAllNotificationsResponseData call({
    Object? updatedCount = const $CopyWithPlaceholder(),
  }) {
    return ReadAllNotificationsResponseData(
      updatedCount: updatedCount == const $CopyWithPlaceholder()
          ? _value.updatedCount
          // ignore: cast_nullable_to_non_nullable
          : updatedCount as int,
    );
  }
}

extension $ReadAllNotificationsResponseDataCopyWith
    on ReadAllNotificationsResponseData {
  /// Returns a callable class that can be used as follows: `instanceOfReadAllNotificationsResponseData.copyWith(...)` or like so:`instanceOfReadAllNotificationsResponseData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ReadAllNotificationsResponseDataCWProxy get copyWith =>
      _$ReadAllNotificationsResponseDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReadAllNotificationsResponseData _$ReadAllNotificationsResponseDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ReadAllNotificationsResponseData', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['updated_count']);
  final val = ReadAllNotificationsResponseData(
    updatedCount: $checkedConvert('updated_count', (v) => (v as num).toInt()),
  );
  return val;
}, fieldKeyMap: const {'updatedCount': 'updated_count'});

Map<String, dynamic> _$ReadAllNotificationsResponseDataToJson(
  ReadAllNotificationsResponseData instance,
) => <String, dynamic>{'updated_count': instance.updatedCount};
