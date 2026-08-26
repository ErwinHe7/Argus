// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_jobs200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminJobs200ResponseCWProxy {
  ListAdminJobs200Response data(List<ListAdminJobs200ResponseDataInner> data);

  ListAdminJobs200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminJobs200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminJobs200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminJobs200Response call({
    List<ListAdminJobs200ResponseDataInner> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminJobs200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminJobs200Response.copyWith.fieldName(...)`
class _$ListAdminJobs200ResponseCWProxyImpl
    implements _$ListAdminJobs200ResponseCWProxy {
  const _$ListAdminJobs200ResponseCWProxyImpl(this._value);

  final ListAdminJobs200Response _value;

  @override
  ListAdminJobs200Response data(List<ListAdminJobs200ResponseDataInner> data) =>
      this(data: data);

  @override
  ListAdminJobs200Response meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminJobs200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminJobs200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminJobs200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListAdminJobs200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<ListAdminJobs200ResponseDataInner>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListAdminJobs200ResponseCopyWith on ListAdminJobs200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminJobs200Response.copyWith(...)` or like so:`instanceOfListAdminJobs200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminJobs200ResponseCWProxy get copyWith =>
      _$ListAdminJobs200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminJobs200Response _$ListAdminJobs200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListAdminJobs200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ListAdminJobs200Response(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map(
            (e) => ListAdminJobs200ResponseDataInner.fromJson(
              e as Map<String, dynamic>,
            ),
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

Map<String, dynamic> _$ListAdminJobs200ResponseToJson(
  ListAdminJobs200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
