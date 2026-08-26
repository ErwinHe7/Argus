// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_audit_events200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminAuditEvents200ResponseCWProxy {
  ListAdminAuditEvents200Response data(List<AdminAuditEvent> data);

  ListAdminAuditEvents200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAuditEvents200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAuditEvents200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAuditEvents200Response call({
    List<AdminAuditEvent> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminAuditEvents200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminAuditEvents200Response.copyWith.fieldName(...)`
class _$ListAdminAuditEvents200ResponseCWProxyImpl
    implements _$ListAdminAuditEvents200ResponseCWProxy {
  const _$ListAdminAuditEvents200ResponseCWProxyImpl(this._value);

  final ListAdminAuditEvents200Response _value;

  @override
  ListAdminAuditEvents200Response data(List<AdminAuditEvent> data) =>
      this(data: data);

  @override
  ListAdminAuditEvents200Response meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAuditEvents200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAuditEvents200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAuditEvents200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListAdminAuditEvents200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<AdminAuditEvent>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListAdminAuditEvents200ResponseCopyWith
    on ListAdminAuditEvents200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminAuditEvents200Response.copyWith(...)` or like so:`instanceOfListAdminAuditEvents200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminAuditEvents200ResponseCWProxy get copyWith =>
      _$ListAdminAuditEvents200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminAuditEvents200Response _$ListAdminAuditEvents200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListAdminAuditEvents200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ListAdminAuditEvents200Response(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => AdminAuditEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ListAdminAuditEvents200ResponseToJson(
  ListAdminAuditEvents200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
