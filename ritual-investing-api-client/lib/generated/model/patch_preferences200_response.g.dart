// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_preferences200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchPreferences200ResponseCWProxy {
  PatchPreferences200Response data(MemberPreferences data);

  PatchPreferences200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchPreferences200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchPreferences200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchPreferences200Response call({MemberPreferences data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchPreferences200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchPreferences200Response.copyWith.fieldName(...)`
class _$PatchPreferences200ResponseCWProxyImpl
    implements _$PatchPreferences200ResponseCWProxy {
  const _$PatchPreferences200ResponseCWProxyImpl(this._value);

  final PatchPreferences200Response _value;

  @override
  PatchPreferences200Response data(MemberPreferences data) => this(data: data);

  @override
  PatchPreferences200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchPreferences200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchPreferences200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchPreferences200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return PatchPreferences200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as MemberPreferences,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $PatchPreferences200ResponseCopyWith on PatchPreferences200Response {
  /// Returns a callable class that can be used as follows: `instanceOfPatchPreferences200Response.copyWith(...)` or like so:`instanceOfPatchPreferences200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchPreferences200ResponseCWProxy get copyWith =>
      _$PatchPreferences200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchPreferences200Response _$PatchPreferences200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PatchPreferences200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = PatchPreferences200Response(
    data: $checkedConvert(
      'data',
      (v) => MemberPreferences.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$PatchPreferences200ResponseToJson(
  PatchPreferences200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
