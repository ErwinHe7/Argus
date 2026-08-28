// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_notification_read_state_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SetNotificationReadStateRequestCWProxy {
  SetNotificationReadStateRequest read(bool read);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SetNotificationReadStateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SetNotificationReadStateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  SetNotificationReadStateRequest call({bool read});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSetNotificationReadStateRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSetNotificationReadStateRequest.copyWith.fieldName(...)`
class _$SetNotificationReadStateRequestCWProxyImpl
    implements _$SetNotificationReadStateRequestCWProxy {
  const _$SetNotificationReadStateRequestCWProxyImpl(this._value);

  final SetNotificationReadStateRequest _value;

  @override
  SetNotificationReadStateRequest read(bool read) => this(read: read);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SetNotificationReadStateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SetNotificationReadStateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  SetNotificationReadStateRequest call({
    Object? read = const $CopyWithPlaceholder(),
  }) {
    return SetNotificationReadStateRequest(
      read: read == const $CopyWithPlaceholder()
          ? _value.read
          // ignore: cast_nullable_to_non_nullable
          : read as bool,
    );
  }
}

extension $SetNotificationReadStateRequestCopyWith
    on SetNotificationReadStateRequest {
  /// Returns a callable class that can be used as follows: `instanceOfSetNotificationReadStateRequest.copyWith(...)` or like so:`instanceOfSetNotificationReadStateRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SetNotificationReadStateRequestCWProxy get copyWith =>
      _$SetNotificationReadStateRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SetNotificationReadStateRequest _$SetNotificationReadStateRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SetNotificationReadStateRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['read']);
  final val = SetNotificationReadStateRequest(
    read: $checkedConvert('read', (v) => v as bool),
  );
  return val;
});

Map<String, dynamic> _$SetNotificationReadStateRequestToJson(
  SetNotificationReadStateRequest instance,
) => <String, dynamic>{'read': instance.read};
