// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_audit_event.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdminAuditEventCWProxy {
  AdminAuditEvent action(String action);

  AdminAuditEvent actorStaffId(String actorStaffId);

  AdminAuditEvent afterHash(String? afterHash);

  AdminAuditEvent beforeHash(String? beforeHash);

  AdminAuditEvent createdAt(DateTime createdAt);

  AdminAuditEvent id(String id);

  AdminAuditEvent outcome(AdminAuditEventOutcomeEnum outcome);

  AdminAuditEvent reason(String reason);

  AdminAuditEvent requestId(String requestId);

  AdminAuditEvent targetId(String? targetId);

  AdminAuditEvent targetKind(String targetKind);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminAuditEvent(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminAuditEvent(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminAuditEvent call({
    String action,
    String actorStaffId,
    String? afterHash,
    String? beforeHash,
    DateTime createdAt,
    String id,
    AdminAuditEventOutcomeEnum outcome,
    String reason,
    String requestId,
    String? targetId,
    String targetKind,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAdminAuditEvent.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAdminAuditEvent.copyWith.fieldName(...)`
class _$AdminAuditEventCWProxyImpl implements _$AdminAuditEventCWProxy {
  const _$AdminAuditEventCWProxyImpl(this._value);

  final AdminAuditEvent _value;

  @override
  AdminAuditEvent action(String action) => this(action: action);

  @override
  AdminAuditEvent actorStaffId(String actorStaffId) =>
      this(actorStaffId: actorStaffId);

  @override
  AdminAuditEvent afterHash(String? afterHash) => this(afterHash: afterHash);

  @override
  AdminAuditEvent beforeHash(String? beforeHash) =>
      this(beforeHash: beforeHash);

  @override
  AdminAuditEvent createdAt(DateTime createdAt) => this(createdAt: createdAt);

  @override
  AdminAuditEvent id(String id) => this(id: id);

  @override
  AdminAuditEvent outcome(AdminAuditEventOutcomeEnum outcome) =>
      this(outcome: outcome);

  @override
  AdminAuditEvent reason(String reason) => this(reason: reason);

  @override
  AdminAuditEvent requestId(String requestId) => this(requestId: requestId);

  @override
  AdminAuditEvent targetId(String? targetId) => this(targetId: targetId);

  @override
  AdminAuditEvent targetKind(String targetKind) => this(targetKind: targetKind);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminAuditEvent(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminAuditEvent(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminAuditEvent call({
    Object? action = const $CopyWithPlaceholder(),
    Object? actorStaffId = const $CopyWithPlaceholder(),
    Object? afterHash = const $CopyWithPlaceholder(),
    Object? beforeHash = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? outcome = const $CopyWithPlaceholder(),
    Object? reason = const $CopyWithPlaceholder(),
    Object? requestId = const $CopyWithPlaceholder(),
    Object? targetId = const $CopyWithPlaceholder(),
    Object? targetKind = const $CopyWithPlaceholder(),
  }) {
    return AdminAuditEvent(
      action: action == const $CopyWithPlaceholder()
          ? _value.action
          // ignore: cast_nullable_to_non_nullable
          : action as String,
      actorStaffId: actorStaffId == const $CopyWithPlaceholder()
          ? _value.actorStaffId
          // ignore: cast_nullable_to_non_nullable
          : actorStaffId as String,
      afterHash: afterHash == const $CopyWithPlaceholder()
          ? _value.afterHash
          // ignore: cast_nullable_to_non_nullable
          : afterHash as String?,
      beforeHash: beforeHash == const $CopyWithPlaceholder()
          ? _value.beforeHash
          // ignore: cast_nullable_to_non_nullable
          : beforeHash as String?,
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      outcome: outcome == const $CopyWithPlaceholder()
          ? _value.outcome
          // ignore: cast_nullable_to_non_nullable
          : outcome as AdminAuditEventOutcomeEnum,
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as String,
      requestId: requestId == const $CopyWithPlaceholder()
          ? _value.requestId
          // ignore: cast_nullable_to_non_nullable
          : requestId as String,
      targetId: targetId == const $CopyWithPlaceholder()
          ? _value.targetId
          // ignore: cast_nullable_to_non_nullable
          : targetId as String?,
      targetKind: targetKind == const $CopyWithPlaceholder()
          ? _value.targetKind
          // ignore: cast_nullable_to_non_nullable
          : targetKind as String,
    );
  }
}

extension $AdminAuditEventCopyWith on AdminAuditEvent {
  /// Returns a callable class that can be used as follows: `instanceOfAdminAuditEvent.copyWith(...)` or like so:`instanceOfAdminAuditEvent.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdminAuditEventCWProxy get copyWith => _$AdminAuditEventCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminAuditEvent _$AdminAuditEventFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'AdminAuditEvent',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'action',
            'actor_staff_id',
            'after_hash',
            'before_hash',
            'created_at',
            'id',
            'outcome',
            'reason',
            'request_id',
            'target_id',
            'target_kind',
          ],
        );
        final val = AdminAuditEvent(
          action: $checkedConvert('action', (v) => v as String),
          actorStaffId: $checkedConvert('actor_staff_id', (v) => v as String),
          afterHash: $checkedConvert('after_hash', (v) => v as String?),
          beforeHash: $checkedConvert('before_hash', (v) => v as String?),
          createdAt: $checkedConvert(
            'created_at',
            (v) => DateTime.parse(v as String),
          ),
          id: $checkedConvert('id', (v) => v as String),
          outcome: $checkedConvert(
            'outcome',
            (v) => $enumDecode(
              _$AdminAuditEventOutcomeEnumEnumMap,
              v,
              unknownValue: AdminAuditEventOutcomeEnum.unknownDefaultOpenApi,
            ),
          ),
          reason: $checkedConvert('reason', (v) => v as String),
          requestId: $checkedConvert('request_id', (v) => v as String),
          targetId: $checkedConvert('target_id', (v) => v as String?),
          targetKind: $checkedConvert('target_kind', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'actorStaffId': 'actor_staff_id',
        'afterHash': 'after_hash',
        'beforeHash': 'before_hash',
        'createdAt': 'created_at',
        'requestId': 'request_id',
        'targetId': 'target_id',
        'targetKind': 'target_kind',
      },
    );

Map<String, dynamic> _$AdminAuditEventToJson(AdminAuditEvent instance) =>
    <String, dynamic>{
      'action': instance.action,
      'actor_staff_id': instance.actorStaffId,
      'after_hash': instance.afterHash,
      'before_hash': instance.beforeHash,
      'created_at': instance.createdAt.toIso8601String(),
      'id': instance.id,
      'outcome': _$AdminAuditEventOutcomeEnumEnumMap[instance.outcome]!,
      'reason': instance.reason,
      'request_id': instance.requestId,
      'target_id': instance.targetId,
      'target_kind': instance.targetKind,
    };

const _$AdminAuditEventOutcomeEnumEnumMap = {
  AdminAuditEventOutcomeEnum.allowed: 'allowed',
  AdminAuditEventOutcomeEnum.denied: 'denied',
  AdminAuditEventOutcomeEnum.failed: 'failed',
  AdminAuditEventOutcomeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
