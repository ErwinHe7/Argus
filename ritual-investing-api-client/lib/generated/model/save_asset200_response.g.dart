// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_asset200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SaveAsset200ResponseCWProxy {
  SaveAsset200Response data(SavedItemReceipt data);

  SaveAsset200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SaveAsset200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SaveAsset200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  SaveAsset200Response call({SavedItemReceipt data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSaveAsset200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSaveAsset200Response.copyWith.fieldName(...)`
class _$SaveAsset200ResponseCWProxyImpl
    implements _$SaveAsset200ResponseCWProxy {
  const _$SaveAsset200ResponseCWProxyImpl(this._value);

  final SaveAsset200Response _value;

  @override
  SaveAsset200Response data(SavedItemReceipt data) => this(data: data);

  @override
  SaveAsset200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SaveAsset200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SaveAsset200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  SaveAsset200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return SaveAsset200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as SavedItemReceipt,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $SaveAsset200ResponseCopyWith on SaveAsset200Response {
  /// Returns a callable class that can be used as follows: `instanceOfSaveAsset200Response.copyWith(...)` or like so:`instanceOfSaveAsset200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SaveAsset200ResponseCWProxy get copyWith =>
      _$SaveAsset200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SaveAsset200Response _$SaveAsset200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SaveAsset200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = SaveAsset200Response(
    data: $checkedConvert(
      'data',
      (v) => SavedItemReceipt.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$SaveAsset200ResponseToJson(
  SaveAsset200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
