// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_seeded_creator.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdminSeededCreatorCWProxy {
  AdminSeededCreator avatarMediaId(String? avatarMediaId);

  AdminSeededCreator bio(String bio);

  AdminSeededCreator displayName(String displayName);

  AdminSeededCreator etag(String etag);

  AdminSeededCreator id(String id);

  AdminSeededCreator isFictional(bool isFictional);

  AdminSeededCreator slug(String slug);

  AdminSeededCreator status(AdminSeededCreatorStatusEnum status);

  AdminSeededCreator version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminSeededCreator(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminSeededCreator(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminSeededCreator call({
    String? avatarMediaId,
    String bio,
    String displayName,
    String etag,
    String id,
    bool isFictional,
    String slug,
    AdminSeededCreatorStatusEnum status,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAdminSeededCreator.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAdminSeededCreator.copyWith.fieldName(...)`
class _$AdminSeededCreatorCWProxyImpl implements _$AdminSeededCreatorCWProxy {
  const _$AdminSeededCreatorCWProxyImpl(this._value);

  final AdminSeededCreator _value;

  @override
  AdminSeededCreator avatarMediaId(String? avatarMediaId) =>
      this(avatarMediaId: avatarMediaId);

  @override
  AdminSeededCreator bio(String bio) => this(bio: bio);

  @override
  AdminSeededCreator displayName(String displayName) =>
      this(displayName: displayName);

  @override
  AdminSeededCreator etag(String etag) => this(etag: etag);

  @override
  AdminSeededCreator id(String id) => this(id: id);

  @override
  AdminSeededCreator isFictional(bool isFictional) =>
      this(isFictional: isFictional);

  @override
  AdminSeededCreator slug(String slug) => this(slug: slug);

  @override
  AdminSeededCreator status(AdminSeededCreatorStatusEnum status) =>
      this(status: status);

  @override
  AdminSeededCreator version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminSeededCreator(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminSeededCreator(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminSeededCreator call({
    Object? avatarMediaId = const $CopyWithPlaceholder(),
    Object? bio = const $CopyWithPlaceholder(),
    Object? displayName = const $CopyWithPlaceholder(),
    Object? etag = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? isFictional = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return AdminSeededCreator(
      avatarMediaId: avatarMediaId == const $CopyWithPlaceholder()
          ? _value.avatarMediaId
          // ignore: cast_nullable_to_non_nullable
          : avatarMediaId as String?,
      bio: bio == const $CopyWithPlaceholder()
          ? _value.bio
          // ignore: cast_nullable_to_non_nullable
          : bio as String,
      displayName: displayName == const $CopyWithPlaceholder()
          ? _value.displayName
          // ignore: cast_nullable_to_non_nullable
          : displayName as String,
      etag: etag == const $CopyWithPlaceholder()
          ? _value.etag
          // ignore: cast_nullable_to_non_nullable
          : etag as String,
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
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as AdminSeededCreatorStatusEnum,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $AdminSeededCreatorCopyWith on AdminSeededCreator {
  /// Returns a callable class that can be used as follows: `instanceOfAdminSeededCreator.copyWith(...)` or like so:`instanceOfAdminSeededCreator.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdminSeededCreatorCWProxy get copyWith =>
      _$AdminSeededCreatorCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminSeededCreator _$AdminSeededCreatorFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'AdminSeededCreator',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'avatar_media_id',
            'bio',
            'display_name',
            'etag',
            'id',
            'is_fictional',
            'slug',
            'status',
            'version',
          ],
        );
        final val = AdminSeededCreator(
          avatarMediaId: $checkedConvert(
            'avatar_media_id',
            (v) => v as String?,
          ),
          bio: $checkedConvert('bio', (v) => v as String),
          displayName: $checkedConvert('display_name', (v) => v as String),
          etag: $checkedConvert('etag', (v) => v as String),
          id: $checkedConvert('id', (v) => v as String),
          isFictional: $checkedConvert('is_fictional', (v) => v as bool),
          slug: $checkedConvert('slug', (v) => v as String),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$AdminSeededCreatorStatusEnumEnumMap,
              v,
              unknownValue: AdminSeededCreatorStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          version: $checkedConvert('version', (v) => (v as num).toInt()),
        );
        return val;
      },
      fieldKeyMap: const {
        'avatarMediaId': 'avatar_media_id',
        'displayName': 'display_name',
        'isFictional': 'is_fictional',
      },
    );

Map<String, dynamic> _$AdminSeededCreatorToJson(AdminSeededCreator instance) =>
    <String, dynamic>{
      'avatar_media_id': instance.avatarMediaId,
      'bio': instance.bio,
      'display_name': instance.displayName,
      'etag': instance.etag,
      'id': instance.id,
      'is_fictional': instance.isFictional,
      'slug': instance.slug,
      'status': _$AdminSeededCreatorStatusEnumEnumMap[instance.status]!,
      'version': instance.version,
    };

const _$AdminSeededCreatorStatusEnumEnumMap = {
  AdminSeededCreatorStatusEnum.active: 'active',
  AdminSeededCreatorStatusEnum.retired: 'retired',
  AdminSeededCreatorStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
