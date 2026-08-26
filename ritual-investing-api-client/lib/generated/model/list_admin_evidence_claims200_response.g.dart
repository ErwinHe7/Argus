// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_evidence_claims200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminEvidenceClaims200ResponseCWProxy {
  ListAdminEvidenceClaims200Response data(List<AdminEvidenceClaim> data);

  ListAdminEvidenceClaims200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminEvidenceClaims200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminEvidenceClaims200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminEvidenceClaims200Response call({
    List<AdminEvidenceClaim> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminEvidenceClaims200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminEvidenceClaims200Response.copyWith.fieldName(...)`
class _$ListAdminEvidenceClaims200ResponseCWProxyImpl
    implements _$ListAdminEvidenceClaims200ResponseCWProxy {
  const _$ListAdminEvidenceClaims200ResponseCWProxyImpl(this._value);

  final ListAdminEvidenceClaims200Response _value;

  @override
  ListAdminEvidenceClaims200Response data(List<AdminEvidenceClaim> data) =>
      this(data: data);

  @override
  ListAdminEvidenceClaims200Response meta(CollectionMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminEvidenceClaims200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminEvidenceClaims200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminEvidenceClaims200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListAdminEvidenceClaims200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<AdminEvidenceClaim>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListAdminEvidenceClaims200ResponseCopyWith
    on ListAdminEvidenceClaims200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminEvidenceClaims200Response.copyWith(...)` or like so:`instanceOfListAdminEvidenceClaims200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminEvidenceClaims200ResponseCWProxy get copyWith =>
      _$ListAdminEvidenceClaims200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminEvidenceClaims200Response _$ListAdminEvidenceClaims200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListAdminEvidenceClaims200Response', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ListAdminEvidenceClaims200Response(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => AdminEvidenceClaim.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ListAdminEvidenceClaims200ResponseToJson(
  ListAdminEvidenceClaims200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
