// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_coven_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PublicCovenResponseCWProxy {
  PublicCovenResponse data(List<PublicCovenTeaser> data);

  PublicCovenResponse meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicCovenResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicCovenResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicCovenResponse call({List<PublicCovenTeaser> data, CollectionMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPublicCovenResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPublicCovenResponse.copyWith.fieldName(...)`
class _$PublicCovenResponseCWProxyImpl implements _$PublicCovenResponseCWProxy {
  const _$PublicCovenResponseCWProxyImpl(this._value);

  final PublicCovenResponse _value;

  @override
  PublicCovenResponse data(List<PublicCovenTeaser> data) => this(data: data);

  @override
  PublicCovenResponse meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicCovenResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicCovenResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicCovenResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return PublicCovenResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<PublicCovenTeaser>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $PublicCovenResponseCopyWith on PublicCovenResponse {
  /// Returns a callable class that can be used as follows: `instanceOfPublicCovenResponse.copyWith(...)` or like so:`instanceOfPublicCovenResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PublicCovenResponseCWProxy get copyWith =>
      _$PublicCovenResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicCovenResponse _$PublicCovenResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PublicCovenResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = PublicCovenResponse(
        data: $checkedConvert(
          'data',
          (v) => (v as List<dynamic>)
              .map((e) => PublicCovenTeaser.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$PublicCovenResponseToJson(
  PublicCovenResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
