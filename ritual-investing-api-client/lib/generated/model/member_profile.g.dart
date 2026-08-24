// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_profile.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberProfileCWProxy {
  MemberProfile displayName(String displayName);

  MemberProfile locale(String locale);

  MemberProfile version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberProfile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberProfile(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberProfile call({String displayName, String locale, int version});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberProfile.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberProfile.copyWith.fieldName(...)`
class _$MemberProfileCWProxyImpl implements _$MemberProfileCWProxy {
  const _$MemberProfileCWProxyImpl(this._value);

  final MemberProfile _value;

  @override
  MemberProfile displayName(String displayName) =>
      this(displayName: displayName);

  @override
  MemberProfile locale(String locale) => this(locale: locale);

  @override
  MemberProfile version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberProfile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberProfile(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberProfile call({
    Object? displayName = const $CopyWithPlaceholder(),
    Object? locale = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return MemberProfile(
      displayName: displayName == const $CopyWithPlaceholder()
          ? _value.displayName
          // ignore: cast_nullable_to_non_nullable
          : displayName as String,
      locale: locale == const $CopyWithPlaceholder()
          ? _value.locale
          // ignore: cast_nullable_to_non_nullable
          : locale as String,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $MemberProfileCopyWith on MemberProfile {
  /// Returns a callable class that can be used as follows: `instanceOfMemberProfile.copyWith(...)` or like so:`instanceOfMemberProfile.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberProfileCWProxy get copyWith => _$MemberProfileCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberProfile _$MemberProfileFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MemberProfile', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['display_name', 'locale', 'version'],
      );
      final val = MemberProfile(
        displayName: $checkedConvert('display_name', (v) => v as String),
        locale: $checkedConvert('locale', (v) => v as String),
        version: $checkedConvert('version', (v) => (v as num).toInt()),
      );
      return val;
    }, fieldKeyMap: const {'displayName': 'display_name'});

Map<String, dynamic> _$MemberProfileToJson(MemberProfile instance) =>
    <String, dynamic>{
      'display_name': instance.displayName,
      'locale': instance.locale,
      'version': instance.version,
    };
