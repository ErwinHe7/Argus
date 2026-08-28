// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'decide_moderation_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DecideModerationRequestCWProxy {
  DecideModerationRequest status(String status);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DecideModerationRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DecideModerationRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  DecideModerationRequest call({String status});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDecideModerationRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDecideModerationRequest.copyWith.fieldName(...)`
class _$DecideModerationRequestCWProxyImpl
    implements _$DecideModerationRequestCWProxy {
  const _$DecideModerationRequestCWProxyImpl(this._value);

  final DecideModerationRequest _value;

  @override
  DecideModerationRequest status(String status) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DecideModerationRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DecideModerationRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  DecideModerationRequest call({
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return DecideModerationRequest(
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as String,
    );
  }
}

extension $DecideModerationRequestCopyWith on DecideModerationRequest {
  /// Returns a callable class that can be used as follows: `instanceOfDecideModerationRequest.copyWith(...)` or like so:`instanceOfDecideModerationRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DecideModerationRequestCWProxy get copyWith =>
      _$DecideModerationRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DecideModerationRequest _$DecideModerationRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DecideModerationRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['status']);
  final val = DecideModerationRequest(
    status: $checkedConvert('status', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$DecideModerationRequestToJson(
  DecideModerationRequest instance,
) => <String, dynamic>{'status': instance.status};
