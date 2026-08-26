// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_seeded_creator_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminSeededCreatorRequestCWProxy {
  CreateAdminSeededCreatorRequest avatarMediaId(String? avatarMediaId);

  CreateAdminSeededCreatorRequest bio(String bio);

  CreateAdminSeededCreatorRequest displayName(String displayName);

  CreateAdminSeededCreatorRequest slug(String slug);

  CreateAdminSeededCreatorRequest status(
    CreateAdminSeededCreatorRequestStatusEnum status,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminSeededCreatorRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminSeededCreatorRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminSeededCreatorRequest call({
    String? avatarMediaId,
    String bio,
    String displayName,
    String slug,
    CreateAdminSeededCreatorRequestStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminSeededCreatorRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminSeededCreatorRequest.copyWith.fieldName(...)`
class _$CreateAdminSeededCreatorRequestCWProxyImpl
    implements _$CreateAdminSeededCreatorRequestCWProxy {
  const _$CreateAdminSeededCreatorRequestCWProxyImpl(this._value);

  final CreateAdminSeededCreatorRequest _value;

  @override
  CreateAdminSeededCreatorRequest avatarMediaId(String? avatarMediaId) =>
      this(avatarMediaId: avatarMediaId);

  @override
  CreateAdminSeededCreatorRequest bio(String bio) => this(bio: bio);

  @override
  CreateAdminSeededCreatorRequest displayName(String displayName) =>
      this(displayName: displayName);

  @override
  CreateAdminSeededCreatorRequest slug(String slug) => this(slug: slug);

  @override
  CreateAdminSeededCreatorRequest status(
    CreateAdminSeededCreatorRequestStatusEnum status,
  ) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminSeededCreatorRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminSeededCreatorRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminSeededCreatorRequest call({
    Object? avatarMediaId = const $CopyWithPlaceholder(),
    Object? bio = const $CopyWithPlaceholder(),
    Object? displayName = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminSeededCreatorRequest(
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
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as CreateAdminSeededCreatorRequestStatusEnum,
    );
  }
}

extension $CreateAdminSeededCreatorRequestCopyWith
    on CreateAdminSeededCreatorRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminSeededCreatorRequest.copyWith(...)` or like so:`instanceOfCreateAdminSeededCreatorRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminSeededCreatorRequestCWProxy get copyWith =>
      _$CreateAdminSeededCreatorRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminSeededCreatorRequest _$CreateAdminSeededCreatorRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CreateAdminSeededCreatorRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'avatar_media_id',
        'bio',
        'display_name',
        'slug',
        'status',
      ],
    );
    final val = CreateAdminSeededCreatorRequest(
      avatarMediaId: $checkedConvert('avatar_media_id', (v) => v as String?),
      bio: $checkedConvert('bio', (v) => v as String),
      displayName: $checkedConvert('display_name', (v) => v as String),
      slug: $checkedConvert('slug', (v) => v as String),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$CreateAdminSeededCreatorRequestStatusEnumEnumMap,
          v,
          unknownValue:
              CreateAdminSeededCreatorRequestStatusEnum.unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'avatarMediaId': 'avatar_media_id',
    'displayName': 'display_name',
  },
);

Map<String, dynamic> _$CreateAdminSeededCreatorRequestToJson(
  CreateAdminSeededCreatorRequest instance,
) => <String, dynamic>{
  'avatar_media_id': instance.avatarMediaId,
  'bio': instance.bio,
  'display_name': instance.displayName,
  'slug': instance.slug,
  'status':
      _$CreateAdminSeededCreatorRequestStatusEnumEnumMap[instance.status]!,
};

const _$CreateAdminSeededCreatorRequestStatusEnumEnumMap = {
  CreateAdminSeededCreatorRequestStatusEnum.active: 'active',
  CreateAdminSeededCreatorRequestStatusEnum.retired: 'retired',
  CreateAdminSeededCreatorRequestStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
