// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_notification.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberNotificationCWProxy {
  MemberNotification body(String body);

  MemberNotification createdAt(DateTime createdAt);

  MemberNotification deepLink(String? deepLink);

  MemberNotification deletionEpoch(int? deletionEpoch);

  MemberNotification id(String id);

  MemberNotification kind(String kind);

  MemberNotification readAt(DateTime? readAt);

  MemberNotification scheduledAt(DateTime? scheduledAt);

  MemberNotification title(String title);

  MemberNotification userId(String userId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberNotification(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberNotification(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberNotification call({
    String body,
    DateTime createdAt,
    String? deepLink,
    int? deletionEpoch,
    String id,
    String kind,
    DateTime? readAt,
    DateTime? scheduledAt,
    String title,
    String userId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberNotification.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberNotification.copyWith.fieldName(...)`
class _$MemberNotificationCWProxyImpl implements _$MemberNotificationCWProxy {
  const _$MemberNotificationCWProxyImpl(this._value);

  final MemberNotification _value;

  @override
  MemberNotification body(String body) => this(body: body);

  @override
  MemberNotification createdAt(DateTime createdAt) =>
      this(createdAt: createdAt);

  @override
  MemberNotification deepLink(String? deepLink) => this(deepLink: deepLink);

  @override
  MemberNotification deletionEpoch(int? deletionEpoch) =>
      this(deletionEpoch: deletionEpoch);

  @override
  MemberNotification id(String id) => this(id: id);

  @override
  MemberNotification kind(String kind) => this(kind: kind);

  @override
  MemberNotification readAt(DateTime? readAt) => this(readAt: readAt);

  @override
  MemberNotification scheduledAt(DateTime? scheduledAt) =>
      this(scheduledAt: scheduledAt);

  @override
  MemberNotification title(String title) => this(title: title);

  @override
  MemberNotification userId(String userId) => this(userId: userId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberNotification(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberNotification(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberNotification call({
    Object? body = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? deepLink = const $CopyWithPlaceholder(),
    Object? deletionEpoch = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
    Object? readAt = const $CopyWithPlaceholder(),
    Object? scheduledAt = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? userId = const $CopyWithPlaceholder(),
  }) {
    return MemberNotification(
      body: body == const $CopyWithPlaceholder()
          ? _value.body
          // ignore: cast_nullable_to_non_nullable
          : body as String,
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
      deepLink: deepLink == const $CopyWithPlaceholder()
          ? _value.deepLink
          // ignore: cast_nullable_to_non_nullable
          : deepLink as String?,
      deletionEpoch: deletionEpoch == const $CopyWithPlaceholder()
          ? _value.deletionEpoch
          // ignore: cast_nullable_to_non_nullable
          : deletionEpoch as int?,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as String,
      readAt: readAt == const $CopyWithPlaceholder()
          ? _value.readAt
          // ignore: cast_nullable_to_non_nullable
          : readAt as DateTime?,
      scheduledAt: scheduledAt == const $CopyWithPlaceholder()
          ? _value.scheduledAt
          // ignore: cast_nullable_to_non_nullable
          : scheduledAt as DateTime?,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      userId: userId == const $CopyWithPlaceholder()
          ? _value.userId
          // ignore: cast_nullable_to_non_nullable
          : userId as String,
    );
  }
}

extension $MemberNotificationCopyWith on MemberNotification {
  /// Returns a callable class that can be used as follows: `instanceOfMemberNotification.copyWith(...)` or like so:`instanceOfMemberNotification.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberNotificationCWProxy get copyWith =>
      _$MemberNotificationCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberNotification _$MemberNotificationFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'MemberNotification',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'body',
            'created_at',
            'deep_link',
            'deletion_epoch',
            'id',
            'kind',
            'read_at',
            'scheduled_at',
            'title',
            'user_id',
          ],
        );
        final val = MemberNotification(
          body: $checkedConvert('body', (v) => v as String),
          createdAt: $checkedConvert(
            'created_at',
            (v) => DateTime.parse(v as String),
          ),
          deepLink: $checkedConvert('deep_link', (v) => v as String?),
          deletionEpoch: $checkedConvert(
            'deletion_epoch',
            (v) => (v as num?)?.toInt(),
          ),
          id: $checkedConvert('id', (v) => v as String),
          kind: $checkedConvert('kind', (v) => v as String),
          readAt: $checkedConvert(
            'read_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          scheduledAt: $checkedConvert(
            'scheduled_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          title: $checkedConvert('title', (v) => v as String),
          userId: $checkedConvert('user_id', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'createdAt': 'created_at',
        'deepLink': 'deep_link',
        'deletionEpoch': 'deletion_epoch',
        'readAt': 'read_at',
        'scheduledAt': 'scheduled_at',
        'userId': 'user_id',
      },
    );

Map<String, dynamic> _$MemberNotificationToJson(MemberNotification instance) =>
    <String, dynamic>{
      'body': instance.body,
      'created_at': instance.createdAt.toIso8601String(),
      'deep_link': instance.deepLink,
      'deletion_epoch': instance.deletionEpoch,
      'id': instance.id,
      'kind': instance.kind,
      'read_at': instance.readAt?.toIso8601String(),
      'scheduled_at': instance.scheduledAt?.toIso8601String(),
      'title': instance.title,
      'user_id': instance.userId,
    };
