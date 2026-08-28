// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webull_connection_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WebullConnectionResponseCWProxy {
  WebullConnectionResponse data(WebullConnection data);

  WebullConnectionResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullConnectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullConnectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullConnectionResponse call({
    WebullConnection data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWebullConnectionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWebullConnectionResponse.copyWith.fieldName(...)`
class _$WebullConnectionResponseCWProxyImpl
    implements _$WebullConnectionResponseCWProxy {
  const _$WebullConnectionResponseCWProxyImpl(this._value);

  final WebullConnectionResponse _value;

  @override
  WebullConnectionResponse data(WebullConnection data) => this(data: data);

  @override
  WebullConnectionResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullConnectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullConnectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullConnectionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return WebullConnectionResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WebullConnection,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $WebullConnectionResponseCopyWith on WebullConnectionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfWebullConnectionResponse.copyWith(...)` or like so:`instanceOfWebullConnectionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WebullConnectionResponseCWProxy get copyWith =>
      _$WebullConnectionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebullConnectionResponse _$WebullConnectionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WebullConnectionResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = WebullConnectionResponse(
    data: $checkedConvert(
      'data',
      (v) => WebullConnection.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$WebullConnectionResponseToJson(
  WebullConnectionResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
