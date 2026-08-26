// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_briefing_read_state_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SetBriefingReadStateRequestCWProxy {
  SetBriefingReadStateRequest read(bool read);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SetBriefingReadStateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SetBriefingReadStateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  SetBriefingReadStateRequest call({bool read});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSetBriefingReadStateRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSetBriefingReadStateRequest.copyWith.fieldName(...)`
class _$SetBriefingReadStateRequestCWProxyImpl
    implements _$SetBriefingReadStateRequestCWProxy {
  const _$SetBriefingReadStateRequestCWProxyImpl(this._value);

  final SetBriefingReadStateRequest _value;

  @override
  SetBriefingReadStateRequest read(bool read) => this(read: read);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SetBriefingReadStateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SetBriefingReadStateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  SetBriefingReadStateRequest call({
    Object? read = const $CopyWithPlaceholder(),
  }) {
    return SetBriefingReadStateRequest(
      read: read == const $CopyWithPlaceholder()
          ? _value.read
          // ignore: cast_nullable_to_non_nullable
          : read as bool,
    );
  }
}

extension $SetBriefingReadStateRequestCopyWith on SetBriefingReadStateRequest {
  /// Returns a callable class that can be used as follows: `instanceOfSetBriefingReadStateRequest.copyWith(...)` or like so:`instanceOfSetBriefingReadStateRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SetBriefingReadStateRequestCWProxy get copyWith =>
      _$SetBriefingReadStateRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SetBriefingReadStateRequest _$SetBriefingReadStateRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SetBriefingReadStateRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['read']);
  final val = SetBriefingReadStateRequest(
    read: $checkedConvert('read', (v) => v as bool),
  );
  return val;
});

Map<String, dynamic> _$SetBriefingReadStateRequestToJson(
  SetBriefingReadStateRequest instance,
) => <String, dynamic>{'read': instance.read};
