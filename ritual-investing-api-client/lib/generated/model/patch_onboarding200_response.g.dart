// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_onboarding200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchOnboarding200ResponseCWProxy {
  PatchOnboarding200Response data(OnboardingState data);

  PatchOnboarding200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchOnboarding200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchOnboarding200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchOnboarding200Response call({OnboardingState data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchOnboarding200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchOnboarding200Response.copyWith.fieldName(...)`
class _$PatchOnboarding200ResponseCWProxyImpl
    implements _$PatchOnboarding200ResponseCWProxy {
  const _$PatchOnboarding200ResponseCWProxyImpl(this._value);

  final PatchOnboarding200Response _value;

  @override
  PatchOnboarding200Response data(OnboardingState data) => this(data: data);

  @override
  PatchOnboarding200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchOnboarding200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchOnboarding200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchOnboarding200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return PatchOnboarding200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as OnboardingState,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $PatchOnboarding200ResponseCopyWith on PatchOnboarding200Response {
  /// Returns a callable class that can be used as follows: `instanceOfPatchOnboarding200Response.copyWith(...)` or like so:`instanceOfPatchOnboarding200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchOnboarding200ResponseCWProxy get copyWith =>
      _$PatchOnboarding200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchOnboarding200Response _$PatchOnboarding200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PatchOnboarding200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = PatchOnboarding200Response(
    data: $checkedConvert(
      'data',
      (v) => OnboardingState.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$PatchOnboarding200ResponseToJson(
  PatchOnboarding200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
