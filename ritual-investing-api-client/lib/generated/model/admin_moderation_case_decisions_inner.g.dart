// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_moderation_case_decisions_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdminModerationCaseDecisionsInnerCWProxy {
  AdminModerationCaseDecisionsInner decidedAt(DateTime decidedAt);

  AdminModerationCaseDecisionsInner outcome(String outcome);

  AdminModerationCaseDecisionsInner reason(String reason);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminModerationCaseDecisionsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminModerationCaseDecisionsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminModerationCaseDecisionsInner call({
    DateTime decidedAt,
    String outcome,
    String reason,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAdminModerationCaseDecisionsInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAdminModerationCaseDecisionsInner.copyWith.fieldName(...)`
class _$AdminModerationCaseDecisionsInnerCWProxyImpl
    implements _$AdminModerationCaseDecisionsInnerCWProxy {
  const _$AdminModerationCaseDecisionsInnerCWProxyImpl(this._value);

  final AdminModerationCaseDecisionsInner _value;

  @override
  AdminModerationCaseDecisionsInner decidedAt(DateTime decidedAt) =>
      this(decidedAt: decidedAt);

  @override
  AdminModerationCaseDecisionsInner outcome(String outcome) =>
      this(outcome: outcome);

  @override
  AdminModerationCaseDecisionsInner reason(String reason) =>
      this(reason: reason);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminModerationCaseDecisionsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminModerationCaseDecisionsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminModerationCaseDecisionsInner call({
    Object? decidedAt = const $CopyWithPlaceholder(),
    Object? outcome = const $CopyWithPlaceholder(),
    Object? reason = const $CopyWithPlaceholder(),
  }) {
    return AdminModerationCaseDecisionsInner(
      decidedAt: decidedAt == const $CopyWithPlaceholder()
          ? _value.decidedAt
          // ignore: cast_nullable_to_non_nullable
          : decidedAt as DateTime,
      outcome: outcome == const $CopyWithPlaceholder()
          ? _value.outcome
          // ignore: cast_nullable_to_non_nullable
          : outcome as String,
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as String,
    );
  }
}

extension $AdminModerationCaseDecisionsInnerCopyWith
    on AdminModerationCaseDecisionsInner {
  /// Returns a callable class that can be used as follows: `instanceOfAdminModerationCaseDecisionsInner.copyWith(...)` or like so:`instanceOfAdminModerationCaseDecisionsInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdminModerationCaseDecisionsInnerCWProxy get copyWith =>
      _$AdminModerationCaseDecisionsInnerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminModerationCaseDecisionsInner _$AdminModerationCaseDecisionsInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AdminModerationCaseDecisionsInner', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['decided_at', 'outcome', 'reason']);
  final val = AdminModerationCaseDecisionsInner(
    decidedAt: $checkedConvert(
      'decided_at',
      (v) => DateTime.parse(v as String),
    ),
    outcome: $checkedConvert('outcome', (v) => v as String),
    reason: $checkedConvert('reason', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'decidedAt': 'decided_at'});

Map<String, dynamic> _$AdminModerationCaseDecisionsInnerToJson(
  AdminModerationCaseDecisionsInner instance,
) => <String, dynamic>{
  'decided_at': instance.decidedAt.toIso8601String(),
  'outcome': instance.outcome,
  'reason': instance.reason,
};
