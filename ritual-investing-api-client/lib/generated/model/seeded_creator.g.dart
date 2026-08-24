// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seeded_creator.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SeededCreatorCWProxy {
  SeededCreator bio(String bio);

  SeededCreator demo(DemoDisclosure demo);

  SeededCreator displayName(String displayName);

  SeededCreator id(String id);

  SeededCreator isFictional(bool isFictional);

  SeededCreator slug(String slug);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SeededCreator(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SeededCreator(...).copyWith(id: 12, name: "My name")
  /// ````
  SeededCreator call({
    String bio,
    DemoDisclosure demo,
    String displayName,
    String id,
    bool isFictional,
    String slug,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSeededCreator.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSeededCreator.copyWith.fieldName(...)`
class _$SeededCreatorCWProxyImpl implements _$SeededCreatorCWProxy {
  const _$SeededCreatorCWProxyImpl(this._value);

  final SeededCreator _value;

  @override
  SeededCreator bio(String bio) => this(bio: bio);

  @override
  SeededCreator demo(DemoDisclosure demo) => this(demo: demo);

  @override
  SeededCreator displayName(String displayName) =>
      this(displayName: displayName);

  @override
  SeededCreator id(String id) => this(id: id);

  @override
  SeededCreator isFictional(bool isFictional) => this(isFictional: isFictional);

  @override
  SeededCreator slug(String slug) => this(slug: slug);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SeededCreator(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SeededCreator(...).copyWith(id: 12, name: "My name")
  /// ````
  SeededCreator call({
    Object? bio = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? displayName = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? isFictional = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
  }) {
    return SeededCreator(
      bio: bio == const $CopyWithPlaceholder()
          ? _value.bio
          // ignore: cast_nullable_to_non_nullable
          : bio as String,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as DemoDisclosure,
      displayName: displayName == const $CopyWithPlaceholder()
          ? _value.displayName
          // ignore: cast_nullable_to_non_nullable
          : displayName as String,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      isFictional: isFictional == const $CopyWithPlaceholder()
          ? _value.isFictional
          // ignore: cast_nullable_to_non_nullable
          : isFictional as bool,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
    );
  }
}

extension $SeededCreatorCopyWith on SeededCreator {
  /// Returns a callable class that can be used as follows: `instanceOfSeededCreator.copyWith(...)` or like so:`instanceOfSeededCreator.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SeededCreatorCWProxy get copyWith => _$SeededCreatorCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SeededCreator _$SeededCreatorFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'SeededCreator',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'bio',
            'demo',
            'display_name',
            'id',
            'is_fictional',
            'slug',
          ],
        );
        final val = SeededCreator(
          bio: $checkedConvert('bio', (v) => v as String),
          demo: $checkedConvert(
            'demo',
            (v) => DemoDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          displayName: $checkedConvert('display_name', (v) => v as String),
          id: $checkedConvert('id', (v) => v as String),
          isFictional: $checkedConvert('is_fictional', (v) => v as bool),
          slug: $checkedConvert('slug', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'displayName': 'display_name',
        'isFictional': 'is_fictional',
      },
    );

Map<String, dynamic> _$SeededCreatorToJson(SeededCreator instance) =>
    <String, dynamic>{
      'bio': instance.bio,
      'demo': instance.demo.toJson(),
      'display_name': instance.displayName,
      'id': instance.id,
      'is_fictional': instance.isFictional,
      'slug': instance.slug,
    };
