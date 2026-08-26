// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_bootstrap_profile.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionBootstrapProfileCWProxy {
  SessionBootstrapProfile displayName(String displayName);

  SessionBootstrapProfile locale(String locale);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapProfile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapProfile(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapProfile call({String displayName, String locale});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionBootstrapProfile.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionBootstrapProfile.copyWith.fieldName(...)`
class _$SessionBootstrapProfileCWProxyImpl
    implements _$SessionBootstrapProfileCWProxy {
  const _$SessionBootstrapProfileCWProxyImpl(this._value);

  final SessionBootstrapProfile _value;

  @override
  SessionBootstrapProfile displayName(String displayName) =>
      this(displayName: displayName);

  @override
  SessionBootstrapProfile locale(String locale) => this(locale: locale);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapProfile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapProfile(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapProfile call({
    Object? displayName = const $CopyWithPlaceholder(),
    Object? locale = const $CopyWithPlaceholder(),
  }) {
    return SessionBootstrapProfile(
      displayName: displayName == const $CopyWithPlaceholder()
          ? _value.displayName
          // ignore: cast_nullable_to_non_nullable
          : displayName as String,
      locale: locale == const $CopyWithPlaceholder()
          ? _value.locale
          // ignore: cast_nullable_to_non_nullable
          : locale as String,
    );
  }
}

extension $SessionBootstrapProfileCopyWith on SessionBootstrapProfile {
  /// Returns a callable class that can be used as follows: `instanceOfSessionBootstrapProfile.copyWith(...)` or like so:`instanceOfSessionBootstrapProfile.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SessionBootstrapProfileCWProxy get copyWith =>
      _$SessionBootstrapProfileCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionBootstrapProfile _$SessionBootstrapProfileFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SessionBootstrapProfile', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['display_name', 'locale']);
  final val = SessionBootstrapProfile(
    displayName: $checkedConvert('display_name', (v) => v as String),
    locale: $checkedConvert('locale', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'displayName': 'display_name'});

Map<String, dynamic> _$SessionBootstrapProfileToJson(
  SessionBootstrapProfile instance,
) => <String, dynamic>{
  'display_name': instance.displayName,
  'locale': instance.locale,
};
