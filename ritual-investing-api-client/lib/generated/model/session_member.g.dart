// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_member.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionMemberCWProxy {
  SessionMember createdAt(DateTime? createdAt);

  SessionMember deletionEpoch(int? deletionEpoch);

  SessionMember deletionRequestedAt(DateTime? deletionRequestedAt);

  SessionMember status(SessionMemberStatusEnum status);

  SessionMember updatedAt(DateTime? updatedAt);

  SessionMember userId(String userId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionMember(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionMember(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionMember call({
    DateTime? createdAt,
    int? deletionEpoch,
    DateTime? deletionRequestedAt,
    SessionMemberStatusEnum status,
    DateTime? updatedAt,
    String userId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionMember.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionMember.copyWith.fieldName(...)`
class _$SessionMemberCWProxyImpl implements _$SessionMemberCWProxy {
  const _$SessionMemberCWProxyImpl(this._value);

  final SessionMember _value;

  @override
  SessionMember createdAt(DateTime? createdAt) => this(createdAt: createdAt);

  @override
  SessionMember deletionEpoch(int? deletionEpoch) =>
      this(deletionEpoch: deletionEpoch);

  @override
  SessionMember deletionRequestedAt(DateTime? deletionRequestedAt) =>
      this(deletionRequestedAt: deletionRequestedAt);

  @override
  SessionMember status(SessionMemberStatusEnum status) => this(status: status);

  @override
  SessionMember updatedAt(DateTime? updatedAt) => this(updatedAt: updatedAt);

  @override
  SessionMember userId(String userId) => this(userId: userId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionMember(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionMember(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionMember call({
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? deletionEpoch = const $CopyWithPlaceholder(),
    Object? deletionRequestedAt = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
    Object? userId = const $CopyWithPlaceholder(),
  }) {
    return SessionMember(
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime?,
      deletionEpoch: deletionEpoch == const $CopyWithPlaceholder()
          ? _value.deletionEpoch
          // ignore: cast_nullable_to_non_nullable
          : deletionEpoch as int?,
      deletionRequestedAt: deletionRequestedAt == const $CopyWithPlaceholder()
          ? _value.deletionRequestedAt
          // ignore: cast_nullable_to_non_nullable
          : deletionRequestedAt as DateTime?,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as SessionMemberStatusEnum,
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

extension $SessionMemberCopyWith on SessionMember {
  /// Returns a callable class that can be used as follows: `instanceOfSessionMember.copyWith(...)` or like so:`instanceOfSessionMember.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SessionMemberCWProxy get copyWith => _$SessionMemberCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionMember _$SessionMemberFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'SessionMember',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'created_at',
            'deletion_epoch',
            'deletion_requested_at',
            'status',
            'updated_at',
            'user_id',
          ],
        );
        final val = SessionMember(
          createdAt: $checkedConvert(
            'created_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          deletionEpoch: $checkedConvert(
            'deletion_epoch',
            (v) => (v as num?)?.toInt(),
          ),
          deletionRequestedAt: $checkedConvert(
            'deletion_requested_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$SessionMemberStatusEnumEnumMap,
              v,
              unknownValue: SessionMemberStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          updatedAt: $checkedConvert(
            'updated_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          userId: $checkedConvert('user_id', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'createdAt': 'created_at',
        'deletionEpoch': 'deletion_epoch',
        'deletionRequestedAt': 'deletion_requested_at',
        'updatedAt': 'updated_at',
        'userId': 'user_id',
      },
    );

Map<String, dynamic> _$SessionMemberToJson(SessionMember instance) =>
    <String, dynamic>{
      'created_at': instance.createdAt?.toIso8601String(),
      'deletion_epoch': instance.deletionEpoch,
      'deletion_requested_at': instance.deletionRequestedAt?.toIso8601String(),
      'status': _$SessionMemberStatusEnumEnumMap[instance.status]!,
      'updated_at': instance.updatedAt?.toIso8601String(),
      'user_id': instance.userId,
    };

const _$SessionMemberStatusEnumEnumMap = {
  SessionMemberStatusEnum.active: 'active',
  SessionMemberStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
