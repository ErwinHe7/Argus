// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_bootstrap_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionBootstrapResponseCWProxy {
  SessionBootstrapResponse data(SessionBootstrap data);

  SessionBootstrapResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapResponse call({
    SessionBootstrap data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionBootstrapResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionBootstrapResponse.copyWith.fieldName(...)`
class _$SessionBootstrapResponseCWProxyImpl
    implements _$SessionBootstrapResponseCWProxy {
  const _$SessionBootstrapResponseCWProxyImpl(this._value);

  final SessionBootstrapResponse _value;

  @override
  SessionBootstrapResponse data(SessionBootstrap data) => this(data: data);

  @override
  SessionBootstrapResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return SessionBootstrapResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as SessionBootstrap,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $SessionBootstrapResponseCopyWith on SessionBootstrapResponse {
  /// Returns a callable class that can be used as follows: `instanceOfSessionBootstrapResponse.copyWith(...)` or like so:`instanceOfSessionBootstrapResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SessionBootstrapResponseCWProxy get copyWith =>
      _$SessionBootstrapResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionBootstrapResponse _$SessionBootstrapResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SessionBootstrapResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = SessionBootstrapResponse(
    data: $checkedConvert(
      'data',
      (v) => SessionBootstrap.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$SessionBootstrapResponseToJson(
  SessionBootstrapResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
