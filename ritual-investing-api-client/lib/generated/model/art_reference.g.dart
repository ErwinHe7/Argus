// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'art_reference.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ArtReferenceCWProxy {
  ArtReference alt(String alt);

  ArtReference key(ArtReferenceKeyEnum key);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ArtReference(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ArtReference(...).copyWith(id: 12, name: "My name")
  /// ````
  ArtReference call({String alt, ArtReferenceKeyEnum key});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfArtReference.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfArtReference.copyWith.fieldName(...)`
class _$ArtReferenceCWProxyImpl implements _$ArtReferenceCWProxy {
  const _$ArtReferenceCWProxyImpl(this._value);

  final ArtReference _value;

  @override
  ArtReference alt(String alt) => this(alt: alt);

  @override
  ArtReference key(ArtReferenceKeyEnum key) => this(key: key);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ArtReference(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ArtReference(...).copyWith(id: 12, name: "My name")
  /// ````
  ArtReference call({
    Object? alt = const $CopyWithPlaceholder(),
    Object? key = const $CopyWithPlaceholder(),
  }) {
    return ArtReference(
      alt: alt == const $CopyWithPlaceholder()
          ? _value.alt
          // ignore: cast_nullable_to_non_nullable
          : alt as String,
      key: key == const $CopyWithPlaceholder()
          ? _value.key
          // ignore: cast_nullable_to_non_nullable
          : key as ArtReferenceKeyEnum,
    );
  }
}

extension $ArtReferenceCopyWith on ArtReference {
  /// Returns a callable class that can be used as follows: `instanceOfArtReference.copyWith(...)` or like so:`instanceOfArtReference.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ArtReferenceCWProxy get copyWith => _$ArtReferenceCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ArtReference _$ArtReferenceFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ArtReference', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['alt', 'key']);
      final val = ArtReference(
        alt: $checkedConvert('alt', (v) => v as String),
        key: $checkedConvert(
          'key',
          (v) => $enumDecode(
            _$ArtReferenceKeyEnumEnumMap,
            v,
            unknownValue: ArtReferenceKeyEnum.unknownDefaultOpenApi,
          ),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ArtReferenceToJson(ArtReference instance) =>
    <String, dynamic>{
      'alt': instance.alt,
      'key': _$ArtReferenceKeyEnumEnumMap[instance.key]!,
    };

const _$ArtReferenceKeyEnumEnumMap = {
  ArtReferenceKeyEnum.theCompass: 'the_compass',
  ArtReferenceKeyEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
