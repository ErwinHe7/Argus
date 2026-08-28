// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webull_disconnect_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WebullDisconnectResponseCWProxy {
  WebullDisconnectResponse data(WebullDisconnectReceipt data);

  WebullDisconnectResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullDisconnectResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullDisconnectResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullDisconnectResponse call({
    WebullDisconnectReceipt data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWebullDisconnectResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWebullDisconnectResponse.copyWith.fieldName(...)`
class _$WebullDisconnectResponseCWProxyImpl
    implements _$WebullDisconnectResponseCWProxy {
  const _$WebullDisconnectResponseCWProxyImpl(this._value);

  final WebullDisconnectResponse _value;

  @override
  WebullDisconnectResponse data(WebullDisconnectReceipt data) =>
      this(data: data);

  @override
  WebullDisconnectResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullDisconnectResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullDisconnectResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullDisconnectResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return WebullDisconnectResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WebullDisconnectReceipt,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $WebullDisconnectResponseCopyWith on WebullDisconnectResponse {
  /// Returns a callable class that can be used as follows: `instanceOfWebullDisconnectResponse.copyWith(...)` or like so:`instanceOfWebullDisconnectResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WebullDisconnectResponseCWProxy get copyWith =>
      _$WebullDisconnectResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebullDisconnectResponse _$WebullDisconnectResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WebullDisconnectResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = WebullDisconnectResponse(
    data: $checkedConvert(
      'data',
      (v) => WebullDisconnectReceipt.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$WebullDisconnectResponseToJson(
  WebullDisconnectResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
