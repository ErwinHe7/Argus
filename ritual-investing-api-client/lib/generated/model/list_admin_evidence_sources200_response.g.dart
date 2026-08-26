// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_evidence_sources200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminEvidenceSources200ResponseCWProxy {
  ListAdminEvidenceSources200Response data(List<AdminEvidenceSource> data);

  ListAdminEvidenceSources200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminEvidenceSources200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminEvidenceSources200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminEvidenceSources200Response call({
    List<AdminEvidenceSource> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminEvidenceSources200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminEvidenceSources200Response.copyWith.fieldName(...)`
class _$ListAdminEvidenceSources200ResponseCWProxyImpl
    implements _$ListAdminEvidenceSources200ResponseCWProxy {
  const _$ListAdminEvidenceSources200ResponseCWProxyImpl(this._value);

  final ListAdminEvidenceSources200Response _value;

  @override
  ListAdminEvidenceSources200Response data(List<AdminEvidenceSource> data) =>
      this(data: data);

  @override
  ListAdminEvidenceSources200Response meta(CollectionMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminEvidenceSources200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminEvidenceSources200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminEvidenceSources200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListAdminEvidenceSources200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<AdminEvidenceSource>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListAdminEvidenceSources200ResponseCopyWith
    on ListAdminEvidenceSources200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminEvidenceSources200Response.copyWith(...)` or like so:`instanceOfListAdminEvidenceSources200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminEvidenceSources200ResponseCWProxy get copyWith =>
      _$ListAdminEvidenceSources200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminEvidenceSources200Response
_$ListAdminEvidenceSources200ResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ListAdminEvidenceSources200Response', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = ListAdminEvidenceSources200Response(
        data: $checkedConvert(
          'data',
          (v) => (v as List<dynamic>)
              .map(
                (e) => AdminEvidenceSource.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ListAdminEvidenceSources200ResponseToJson(
  ListAdminEvidenceSources200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
