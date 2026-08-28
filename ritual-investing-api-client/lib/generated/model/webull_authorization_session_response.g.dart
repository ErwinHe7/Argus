// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webull_authorization_session_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WebullAuthorizationSessionResponseCWProxy {
  WebullAuthorizationSessionResponse data(WebullAuthorizationSession data);

  WebullAuthorizationSessionResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullAuthorizationSessionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullAuthorizationSessionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullAuthorizationSessionResponse call({
    WebullAuthorizationSession data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWebullAuthorizationSessionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWebullAuthorizationSessionResponse.copyWith.fieldName(...)`
class _$WebullAuthorizationSessionResponseCWProxyImpl
    implements _$WebullAuthorizationSessionResponseCWProxy {
  const _$WebullAuthorizationSessionResponseCWProxyImpl(this._value);

  final WebullAuthorizationSessionResponse _value;

  @override
  WebullAuthorizationSessionResponse data(WebullAuthorizationSession data) =>
      this(data: data);

  @override
  WebullAuthorizationSessionResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullAuthorizationSessionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullAuthorizationSessionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullAuthorizationSessionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return WebullAuthorizationSessionResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WebullAuthorizationSession,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $WebullAuthorizationSessionResponseCopyWith
    on WebullAuthorizationSessionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfWebullAuthorizationSessionResponse.copyWith(...)` or like so:`instanceOfWebullAuthorizationSessionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WebullAuthorizationSessionResponseCWProxy get copyWith =>
      _$WebullAuthorizationSessionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebullAuthorizationSessionResponse _$WebullAuthorizationSessionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WebullAuthorizationSessionResponse', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = WebullAuthorizationSessionResponse(
    data: $checkedConvert(
      'data',
      (v) => WebullAuthorizationSession.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$WebullAuthorizationSessionResponseToJson(
  WebullAuthorizationSessionResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
