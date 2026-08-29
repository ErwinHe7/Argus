// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'creator_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreatorResponseCWProxy {
  CreatorResponse data(SeededCreator? data);

  CreatorResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreatorResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreatorResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CreatorResponse call({
    SeededCreator? data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreatorResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreatorResponse.copyWith.fieldName(...)`
class _$CreatorResponseCWProxyImpl implements _$CreatorResponseCWProxy {
  const _$CreatorResponseCWProxyImpl(this._value);

  final CreatorResponse _value;

  @override
  CreatorResponse data(SeededCreator? data) => this(data: data);

  @override
  CreatorResponse meta(ListAdminAudit200ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreatorResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreatorResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CreatorResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreatorResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as SeededCreator?,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $CreatorResponseCopyWith on CreatorResponse {
  /// Returns a callable class that can be used as follows: `instanceOfCreatorResponse.copyWith(...)` or like so:`instanceOfCreatorResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreatorResponseCWProxy get copyWith => _$CreatorResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreatorResponse _$CreatorResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CreatorResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = CreatorResponse(
        data: $checkedConvert(
          'data',
          (v) => v == null
              ? null
              : SeededCreator.fromJson(v as Map<String, dynamic>),
        ),
        meta: $checkedConvert(
          'meta',
          (v) =>
              ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CreatorResponseToJson(CreatorResponse instance) =>
    <String, dynamic>{
      'data': instance.data?.toJson(),
      'meta': instance.meta.toJson(),
    };
