// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OnboardingResponseCWProxy {
  OnboardingResponse data(OnboardingState data);

  OnboardingResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OnboardingResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OnboardingResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  OnboardingResponse call({OnboardingState data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOnboardingResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOnboardingResponse.copyWith.fieldName(...)`
class _$OnboardingResponseCWProxyImpl implements _$OnboardingResponseCWProxy {
  const _$OnboardingResponseCWProxyImpl(this._value);

  final OnboardingResponse _value;

  @override
  OnboardingResponse data(OnboardingState data) => this(data: data);

  @override
  OnboardingResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OnboardingResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OnboardingResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  OnboardingResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return OnboardingResponse(
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

extension $OnboardingResponseCopyWith on OnboardingResponse {
  /// Returns a callable class that can be used as follows: `instanceOfOnboardingResponse.copyWith(...)` or like so:`instanceOfOnboardingResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OnboardingResponseCWProxy get copyWith =>
      _$OnboardingResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OnboardingResponse _$OnboardingResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('OnboardingResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = OnboardingResponse(
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

Map<String, dynamic> _$OnboardingResponseToJson(OnboardingResponse instance) =>
    <String, dynamic>{
      'data': instance.data.toJson(),
      'meta': instance.meta.toJson(),
    };
