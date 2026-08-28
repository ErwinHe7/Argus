// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_audit200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminAudit200ResponseCWProxy {
  ListAdminAudit200Response data(Object? data);

  ListAdminAudit200Response meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAudit200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAudit200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAudit200Response call({
    Object? data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminAudit200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminAudit200Response.copyWith.fieldName(...)`
class _$ListAdminAudit200ResponseCWProxyImpl
    implements _$ListAdminAudit200ResponseCWProxy {
  const _$ListAdminAudit200ResponseCWProxyImpl(this._value);

  final ListAdminAudit200Response _value;

  @override
  ListAdminAudit200Response data(Object? data) => this(data: data);

  @override
  ListAdminAudit200Response meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAudit200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAudit200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAudit200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListAdminAudit200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as Object?,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $ListAdminAudit200ResponseCopyWith on ListAdminAudit200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminAudit200Response.copyWith(...)` or like so:`instanceOfListAdminAudit200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminAudit200ResponseCWProxy get copyWith =>
      _$ListAdminAudit200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminAudit200Response _$ListAdminAudit200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListAdminAudit200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['meta']);
  final val = ListAdminAudit200Response(
    data: $checkedConvert('data', (v) => v),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ListAdminAudit200ResponseToJson(
  ListAdminAudit200Response instance,
) => <String, dynamic>{'data': ?instance.data, 'meta': instance.meta.toJson()};
