// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_intentions200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListIntentions200ResponseCWProxy {
  ListIntentions200Response data(List<Intention> data);

  ListIntentions200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListIntentions200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListIntentions200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListIntentions200Response call({List<Intention> data, CollectionMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListIntentions200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListIntentions200Response.copyWith.fieldName(...)`
class _$ListIntentions200ResponseCWProxyImpl
    implements _$ListIntentions200ResponseCWProxy {
  const _$ListIntentions200ResponseCWProxyImpl(this._value);

  final ListIntentions200Response _value;

  @override
  ListIntentions200Response data(List<Intention> data) => this(data: data);

  @override
  ListIntentions200Response meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListIntentions200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListIntentions200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListIntentions200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListIntentions200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<Intention>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListIntentions200ResponseCopyWith on ListIntentions200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListIntentions200Response.copyWith(...)` or like so:`instanceOfListIntentions200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListIntentions200ResponseCWProxy get copyWith =>
      _$ListIntentions200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListIntentions200Response _$ListIntentions200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListIntentions200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ListIntentions200Response(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => Intention.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ListIntentions200ResponseToJson(
  ListIntentions200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
