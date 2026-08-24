// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_notifications200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListNotifications200ResponseCWProxy {
  ListNotifications200Response data(
    List<ListNotifications200ResponseDataInner> data,
  );

  ListNotifications200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListNotifications200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListNotifications200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListNotifications200Response call({
    List<ListNotifications200ResponseDataInner> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListNotifications200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListNotifications200Response.copyWith.fieldName(...)`
class _$ListNotifications200ResponseCWProxyImpl
    implements _$ListNotifications200ResponseCWProxy {
  const _$ListNotifications200ResponseCWProxyImpl(this._value);

  final ListNotifications200Response _value;

  @override
  ListNotifications200Response data(
    List<ListNotifications200ResponseDataInner> data,
  ) => this(data: data);

  @override
  ListNotifications200Response meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListNotifications200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListNotifications200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListNotifications200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListNotifications200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<ListNotifications200ResponseDataInner>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListNotifications200ResponseCopyWith
    on ListNotifications200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListNotifications200Response.copyWith(...)` or like so:`instanceOfListNotifications200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListNotifications200ResponseCWProxy get copyWith =>
      _$ListNotifications200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListNotifications200Response _$ListNotifications200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListNotifications200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ListNotifications200Response(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map(
            (e) => ListNotifications200ResponseDataInner.fromJson(
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

Map<String, dynamic> _$ListNotifications200ResponseToJson(
  ListNotifications200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
