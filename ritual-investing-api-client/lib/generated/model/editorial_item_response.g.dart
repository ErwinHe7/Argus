// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'editorial_item_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EditorialItemResponseCWProxy {
  EditorialItemResponse data(PublishedEditorial? data);

  EditorialItemResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EditorialItemResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EditorialItemResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  EditorialItemResponse call({
    PublishedEditorial? data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEditorialItemResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEditorialItemResponse.copyWith.fieldName(...)`
class _$EditorialItemResponseCWProxyImpl
    implements _$EditorialItemResponseCWProxy {
  const _$EditorialItemResponseCWProxyImpl(this._value);

  final EditorialItemResponse _value;

  @override
  EditorialItemResponse data(PublishedEditorial? data) => this(data: data);

  @override
  EditorialItemResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EditorialItemResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EditorialItemResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  EditorialItemResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return EditorialItemResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as PublishedEditorial?,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $EditorialItemResponseCopyWith on EditorialItemResponse {
  /// Returns a callable class that can be used as follows: `instanceOfEditorialItemResponse.copyWith(...)` or like so:`instanceOfEditorialItemResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EditorialItemResponseCWProxy get copyWith =>
      _$EditorialItemResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EditorialItemResponse _$EditorialItemResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('EditorialItemResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = EditorialItemResponse(
    data: $checkedConvert(
      'data',
      (v) => v == null
          ? null
          : PublishedEditorial.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$EditorialItemResponseToJson(
  EditorialItemResponse instance,
) => <String, dynamic>{
  'data': instance.data?.toJson(),
  'meta': instance.meta.toJson(),
};
