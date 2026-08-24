// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'read_all_notifications_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReadAllNotificationsRequestCWProxy {
  ReadAllNotificationsRequest before(DateTime? before);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReadAllNotificationsRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReadAllNotificationsRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ReadAllNotificationsRequest call({DateTime? before});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfReadAllNotificationsRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfReadAllNotificationsRequest.copyWith.fieldName(...)`
class _$ReadAllNotificationsRequestCWProxyImpl
    implements _$ReadAllNotificationsRequestCWProxy {
  const _$ReadAllNotificationsRequestCWProxyImpl(this._value);

  final ReadAllNotificationsRequest _value;

  @override
  ReadAllNotificationsRequest before(DateTime? before) => this(before: before);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReadAllNotificationsRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReadAllNotificationsRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ReadAllNotificationsRequest call({
    Object? before = const $CopyWithPlaceholder(),
  }) {
    return ReadAllNotificationsRequest(
      before: before == const $CopyWithPlaceholder()
          ? _value.before
          // ignore: cast_nullable_to_non_nullable
          : before as DateTime?,
    );
  }
}

extension $ReadAllNotificationsRequestCopyWith on ReadAllNotificationsRequest {
  /// Returns a callable class that can be used as follows: `instanceOfReadAllNotificationsRequest.copyWith(...)` or like so:`instanceOfReadAllNotificationsRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ReadAllNotificationsRequestCWProxy get copyWith =>
      _$ReadAllNotificationsRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReadAllNotificationsRequest _$ReadAllNotificationsRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ReadAllNotificationsRequest', json, ($checkedConvert) {
  final val = ReadAllNotificationsRequest(
    before: $checkedConvert(
      'before',
      (v) => v == null ? null : DateTime.parse(v as String),
    ),
  );
  return val;
});

Map<String, dynamic> _$ReadAllNotificationsRequestToJson(
  ReadAllNotificationsRequest instance,
) => <String, dynamic>{'before': ?instance.before?.toIso8601String()};
