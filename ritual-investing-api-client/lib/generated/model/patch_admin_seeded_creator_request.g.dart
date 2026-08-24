// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_admin_seeded_creator_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchAdminSeededCreatorRequestCWProxy {
  PatchAdminSeededCreatorRequest avatarMediaId(String? avatarMediaId);

  PatchAdminSeededCreatorRequest bio(String? bio);

  PatchAdminSeededCreatorRequest displayName(String? displayName);

  PatchAdminSeededCreatorRequest status(
    PatchAdminSeededCreatorRequestStatusEnum? status,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchAdminSeededCreatorRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchAdminSeededCreatorRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchAdminSeededCreatorRequest call({
    String? avatarMediaId,
    String? bio,
    String? displayName,
    PatchAdminSeededCreatorRequestStatusEnum? status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchAdminSeededCreatorRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchAdminSeededCreatorRequest.copyWith.fieldName(...)`
class _$PatchAdminSeededCreatorRequestCWProxyImpl
    implements _$PatchAdminSeededCreatorRequestCWProxy {
  const _$PatchAdminSeededCreatorRequestCWProxyImpl(this._value);

  final PatchAdminSeededCreatorRequest _value;

  @override
  PatchAdminSeededCreatorRequest avatarMediaId(String? avatarMediaId) =>
      this(avatarMediaId: avatarMediaId);

  @override
  PatchAdminSeededCreatorRequest bio(String? bio) => this(bio: bio);

  @override
  PatchAdminSeededCreatorRequest displayName(String? displayName) =>
      this(displayName: displayName);

  @override
  PatchAdminSeededCreatorRequest status(
    PatchAdminSeededCreatorRequestStatusEnum? status,
  ) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchAdminSeededCreatorRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchAdminSeededCreatorRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchAdminSeededCreatorRequest call({
    Object? avatarMediaId = const $CopyWithPlaceholder(),
    Object? bio = const $CopyWithPlaceholder(),
    Object? displayName = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return PatchAdminSeededCreatorRequest(
      avatarMediaId: avatarMediaId == const $CopyWithPlaceholder()
          ? _value.avatarMediaId
          // ignore: cast_nullable_to_non_nullable
          : avatarMediaId as String?,
      bio: bio == const $CopyWithPlaceholder()
          ? _value.bio
          // ignore: cast_nullable_to_non_nullable
          : bio as String?,
      displayName: displayName == const $CopyWithPlaceholder()
          ? _value.displayName
          // ignore: cast_nullable_to_non_nullable
          : displayName as String?,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as PatchAdminSeededCreatorRequestStatusEnum?,
    );
  }
}

extension $PatchAdminSeededCreatorRequestCopyWith
    on PatchAdminSeededCreatorRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchAdminSeededCreatorRequest.copyWith(...)` or like so:`instanceOfPatchAdminSeededCreatorRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchAdminSeededCreatorRequestCWProxy get copyWith =>
      _$PatchAdminSeededCreatorRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchAdminSeededCreatorRequest _$PatchAdminSeededCreatorRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'PatchAdminSeededCreatorRequest',
  json,
  ($checkedConvert) {
    final val = PatchAdminSeededCreatorRequest(
      avatarMediaId: $checkedConvert('avatar_media_id', (v) => v as String?),
      bio: $checkedConvert('bio', (v) => v as String?),
      displayName: $checkedConvert('display_name', (v) => v as String?),
      status: $checkedConvert(
        'status',
        (v) => $enumDecodeNullable(
          _$PatchAdminSeededCreatorRequestStatusEnumEnumMap,
          v,
          unknownValue:
              PatchAdminSeededCreatorRequestStatusEnum.unknownDefaultOpenApi,
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

Map<String, dynamic> _$PatchAdminSeededCreatorRequestToJson(
  PatchAdminSeededCreatorRequest instance,
) => <String, dynamic>{
  'avatar_media_id': ?instance.avatarMediaId,
  'bio': ?instance.bio,
  'display_name': ?instance.displayName,
  'status': ?_$PatchAdminSeededCreatorRequestStatusEnumEnumMap[instance.status],
};

const _$PatchAdminSeededCreatorRequestStatusEnumEnumMap = {
  PatchAdminSeededCreatorRequestStatusEnum.active: 'active',
  PatchAdminSeededCreatorRequestStatusEnum.retired: 'retired',
  PatchAdminSeededCreatorRequestStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
