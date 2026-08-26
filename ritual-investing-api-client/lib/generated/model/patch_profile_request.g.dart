// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_profile_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchProfileRequestCWProxy {
  PatchProfileRequest displayName(String? displayName);

  PatchProfileRequest locale(String? locale);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchProfileRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchProfileRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchProfileRequest call({String? displayName, String? locale});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchProfileRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchProfileRequest.copyWith.fieldName(...)`
class _$PatchProfileRequestCWProxyImpl implements _$PatchProfileRequestCWProxy {
  const _$PatchProfileRequestCWProxyImpl(this._value);

  final PatchProfileRequest _value;

  @override
  PatchProfileRequest displayName(String? displayName) =>
      this(displayName: displayName);

  @override
  PatchProfileRequest locale(String? locale) => this(locale: locale);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchProfileRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchProfileRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchProfileRequest call({
    Object? displayName = const $CopyWithPlaceholder(),
    Object? locale = const $CopyWithPlaceholder(),
  }) {
    return PatchProfileRequest(
      displayName: displayName == const $CopyWithPlaceholder()
          ? _value.displayName
          // ignore: cast_nullable_to_non_nullable
          : displayName as String?,
      locale: locale == const $CopyWithPlaceholder()
          ? _value.locale
          // ignore: cast_nullable_to_non_nullable
          : locale as String?,
    );
  }
}

extension $PatchProfileRequestCopyWith on PatchProfileRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchProfileRequest.copyWith(...)` or like so:`instanceOfPatchProfileRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchProfileRequestCWProxy get copyWith =>
      _$PatchProfileRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchProfileRequest _$PatchProfileRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PatchProfileRequest', json, ($checkedConvert) {
      final val = PatchProfileRequest(
        displayName: $checkedConvert('display_name', (v) => v as String?),
        locale: $checkedConvert('locale', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'displayName': 'display_name'});

Map<String, dynamic> _$PatchProfileRequestToJson(
  PatchProfileRequest instance,
) => <String, dynamic>{
  'display_name': ?instance.displayName,
  'locale': ?instance.locale,
};
