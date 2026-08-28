// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_profile.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberProfileCWProxy {
  MemberProfile avatarMediaId(String? avatarMediaId);

  MemberProfile deletionEpoch(int? deletionEpoch);

  MemberProfile displayName(String displayName);

  MemberProfile locale(String locale);

  MemberProfile updatedAt(DateTime? updatedAt);

  MemberProfile userId(String userId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberProfile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberProfile(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberProfile call({
    String? avatarMediaId,
    int? deletionEpoch,
    String displayName,
    String locale,
    DateTime? updatedAt,
    String userId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberProfile.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberProfile.copyWith.fieldName(...)`
class _$MemberProfileCWProxyImpl implements _$MemberProfileCWProxy {
  const _$MemberProfileCWProxyImpl(this._value);

  final MemberProfile _value;

  @override
  MemberProfile avatarMediaId(String? avatarMediaId) =>
      this(avatarMediaId: avatarMediaId);

  @override
  MemberProfile deletionEpoch(int? deletionEpoch) =>
      this(deletionEpoch: deletionEpoch);

  @override
  MemberProfile displayName(String displayName) =>
      this(displayName: displayName);

  @override
  MemberProfile locale(String locale) => this(locale: locale);

  @override
  MemberProfile updatedAt(DateTime? updatedAt) => this(updatedAt: updatedAt);

  @override
  MemberProfile userId(String userId) => this(userId: userId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberProfile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberProfile(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberProfile call({
    Object? avatarMediaId = const $CopyWithPlaceholder(),
    Object? deletionEpoch = const $CopyWithPlaceholder(),
    Object? displayName = const $CopyWithPlaceholder(),
    Object? locale = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
    Object? userId = const $CopyWithPlaceholder(),
  }) {
    return MemberProfile(
      avatarMediaId: avatarMediaId == const $CopyWithPlaceholder()
          ? _value.avatarMediaId
          // ignore: cast_nullable_to_non_nullable
          : avatarMediaId as String?,
      deletionEpoch: deletionEpoch == const $CopyWithPlaceholder()
          ? _value.deletionEpoch
          // ignore: cast_nullable_to_non_nullable
          : deletionEpoch as int?,
      displayName: displayName == const $CopyWithPlaceholder()
          ? _value.displayName
          // ignore: cast_nullable_to_non_nullable
          : displayName as String,
      locale: locale == const $CopyWithPlaceholder()
          ? _value.locale
          // ignore: cast_nullable_to_non_nullable
          : locale as String,
      updatedAt: updatedAt == const $CopyWithPlaceholder()
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime?,
      userId: userId == const $CopyWithPlaceholder()
          ? _value.userId
          // ignore: cast_nullable_to_non_nullable
          : userId as String,
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
    $checkedCreate(
      'MemberProfile',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'avatar_media_id',
            'deletion_epoch',
            'display_name',
            'locale',
            'updated_at',
            'user_id',
          ],
        );
        final val = MemberProfile(
          avatarMediaId: $checkedConvert(
            'avatar_media_id',
            (v) => v as String?,
          ),
          deletionEpoch: $checkedConvert(
            'deletion_epoch',
            (v) => (v as num?)?.toInt(),
          ),
          displayName: $checkedConvert('display_name', (v) => v as String),
          locale: $checkedConvert('locale', (v) => v as String),
          updatedAt: $checkedConvert(
            'updated_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          userId: $checkedConvert('user_id', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'avatarMediaId': 'avatar_media_id',
        'deletionEpoch': 'deletion_epoch',
        'displayName': 'display_name',
        'updatedAt': 'updated_at',
        'userId': 'user_id',
      },
    );

Map<String, dynamic> _$MemberProfileToJson(MemberProfile instance) =>
    <String, dynamic>{
      'avatar_media_id': instance.avatarMediaId,
      'deletion_epoch': instance.deletionEpoch,
      'display_name': instance.displayName,
      'locale': instance.locale,
      'updated_at': instance.updatedAt?.toIso8601String(),
      'user_id': instance.userId,
    };
