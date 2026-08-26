// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_coven_detail_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PublicCovenDetailResponseCWProxy {
  PublicCovenDetailResponse data(PublicCovenTeaser data);

  PublicCovenDetailResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicCovenDetailResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicCovenDetailResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicCovenDetailResponse call({PublicCovenTeaser data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPublicCovenDetailResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPublicCovenDetailResponse.copyWith.fieldName(...)`
class _$PublicCovenDetailResponseCWProxyImpl
    implements _$PublicCovenDetailResponseCWProxy {
  const _$PublicCovenDetailResponseCWProxyImpl(this._value);

  final PublicCovenDetailResponse _value;

  @override
  PublicCovenDetailResponse data(PublicCovenTeaser data) => this(data: data);

  @override
  PublicCovenDetailResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicCovenDetailResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicCovenDetailResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicCovenDetailResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return PublicCovenDetailResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as PublicCovenTeaser,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $PublicCovenDetailResponseCopyWith on PublicCovenDetailResponse {
  /// Returns a callable class that can be used as follows: `instanceOfPublicCovenDetailResponse.copyWith(...)` or like so:`instanceOfPublicCovenDetailResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PublicCovenDetailResponseCWProxy get copyWith =>
      _$PublicCovenDetailResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicCovenDetailResponse _$PublicCovenDetailResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PublicCovenDetailResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = PublicCovenDetailResponse(
    data: $checkedConvert(
      'data',
      (v) => PublicCovenTeaser.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$PublicCovenDetailResponseToJson(
  PublicCovenDetailResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
