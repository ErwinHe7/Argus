// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_account200_response_meta.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetAccount200ResponseMetaCWProxy {
  GetAccount200ResponseMeta requestId(String requestId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAccount200ResponseMeta(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAccount200ResponseMeta(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAccount200ResponseMeta call({String requestId});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetAccount200ResponseMeta.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetAccount200ResponseMeta.copyWith.fieldName(...)`
class _$GetAccount200ResponseMetaCWProxyImpl
    implements _$GetAccount200ResponseMetaCWProxy {
  const _$GetAccount200ResponseMetaCWProxyImpl(this._value);

  final GetAccount200ResponseMeta _value;

  @override
  GetAccount200ResponseMeta requestId(String requestId) =>
      this(requestId: requestId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAccount200ResponseMeta(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAccount200ResponseMeta(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAccount200ResponseMeta call({
    Object? requestId = const $CopyWithPlaceholder(),
  }) {
    return GetAccount200ResponseMeta(
      requestId: requestId == const $CopyWithPlaceholder()
          ? _value.requestId
          // ignore: cast_nullable_to_non_nullable
          : requestId as String,
    );
  }
}

extension $GetAccount200ResponseMetaCopyWith on GetAccount200ResponseMeta {
  /// Returns a callable class that can be used as follows: `instanceOfGetAccount200ResponseMeta.copyWith(...)` or like so:`instanceOfGetAccount200ResponseMeta.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetAccount200ResponseMetaCWProxy get copyWith =>
      _$GetAccount200ResponseMetaCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetAccount200ResponseMeta _$GetAccount200ResponseMetaFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GetAccount200ResponseMeta', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['request_id']);
  final val = GetAccount200ResponseMeta(
    requestId: $checkedConvert('request_id', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'requestId': 'request_id'});

Map<String, dynamic> _$GetAccount200ResponseMetaToJson(
  GetAccount200ResponseMeta instance,
) => <String, dynamic>{'request_id': instance.requestId};
