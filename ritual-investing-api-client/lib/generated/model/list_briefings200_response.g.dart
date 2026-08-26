// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_briefings200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListBriefings200ResponseCWProxy {
  ListBriefings200Response data(List<ListBriefings200ResponseDataInner> data);

  ListBriefings200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListBriefings200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListBriefings200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListBriefings200Response call({
    List<ListBriefings200ResponseDataInner> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListBriefings200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListBriefings200Response.copyWith.fieldName(...)`
class _$ListBriefings200ResponseCWProxyImpl
    implements _$ListBriefings200ResponseCWProxy {
  const _$ListBriefings200ResponseCWProxyImpl(this._value);

  final ListBriefings200Response _value;

  @override
  ListBriefings200Response data(List<ListBriefings200ResponseDataInner> data) =>
      this(data: data);

  @override
  ListBriefings200Response meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListBriefings200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListBriefings200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListBriefings200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListBriefings200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<ListBriefings200ResponseDataInner>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListBriefings200ResponseCopyWith on ListBriefings200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListBriefings200Response.copyWith(...)` or like so:`instanceOfListBriefings200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListBriefings200ResponseCWProxy get copyWith =>
      _$ListBriefings200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListBriefings200Response _$ListBriefings200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListBriefings200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ListBriefings200Response(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map(
            (e) => ListBriefings200ResponseDataInner.fromJson(
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

Map<String, dynamic> _$ListBriefings200ResponseToJson(
  ListBriefings200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
