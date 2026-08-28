// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_order_reconciliation.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageOrderReconciliationCWProxy {
  BrokerageOrderReconciliation attempts(int attempts);

  BrokerageOrderReconciliation command(BrokerageOrderCommand command);

  BrokerageOrderReconciliation egressStartedAt(DateTime egressStartedAt);

  BrokerageOrderReconciliation lastErrorCode(String? lastErrorCode);

  BrokerageOrderReconciliation nextAttemptAt(DateTime? nextAttemptAt);

  BrokerageOrderReconciliation status(
    BrokerageOrderReconciliationStatusEnum? status,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrderReconciliation(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrderReconciliation(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrderReconciliation call({
    int attempts,
    BrokerageOrderCommand command,
    DateTime egressStartedAt,
    String? lastErrorCode,
    DateTime? nextAttemptAt,
    BrokerageOrderReconciliationStatusEnum? status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageOrderReconciliation.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageOrderReconciliation.copyWith.fieldName(...)`
class _$BrokerageOrderReconciliationCWProxyImpl
    implements _$BrokerageOrderReconciliationCWProxy {
  const _$BrokerageOrderReconciliationCWProxyImpl(this._value);

  final BrokerageOrderReconciliation _value;

  @override
  BrokerageOrderReconciliation attempts(int attempts) =>
      this(attempts: attempts);

  @override
  BrokerageOrderReconciliation command(BrokerageOrderCommand command) =>
      this(command: command);

  @override
  BrokerageOrderReconciliation egressStartedAt(DateTime egressStartedAt) =>
      this(egressStartedAt: egressStartedAt);

  @override
  BrokerageOrderReconciliation lastErrorCode(String? lastErrorCode) =>
      this(lastErrorCode: lastErrorCode);

  @override
  BrokerageOrderReconciliation nextAttemptAt(DateTime? nextAttemptAt) =>
      this(nextAttemptAt: nextAttemptAt);

  @override
  BrokerageOrderReconciliation status(
    BrokerageOrderReconciliationStatusEnum? status,
  ) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrderReconciliation(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrderReconciliation(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrderReconciliation call({
    Object? attempts = const $CopyWithPlaceholder(),
    Object? command = const $CopyWithPlaceholder(),
    Object? egressStartedAt = const $CopyWithPlaceholder(),
    Object? lastErrorCode = const $CopyWithPlaceholder(),
    Object? nextAttemptAt = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return BrokerageOrderReconciliation(
      attempts: attempts == const $CopyWithPlaceholder()
          ? _value.attempts
          // ignore: cast_nullable_to_non_nullable
          : attempts as int,
      command: command == const $CopyWithPlaceholder()
          ? _value.command
          // ignore: cast_nullable_to_non_nullable
          : command as BrokerageOrderCommand,
      egressStartedAt: egressStartedAt == const $CopyWithPlaceholder()
          ? _value.egressStartedAt
          // ignore: cast_nullable_to_non_nullable
          : egressStartedAt as DateTime,
      lastErrorCode: lastErrorCode == const $CopyWithPlaceholder()
          ? _value.lastErrorCode
          // ignore: cast_nullable_to_non_nullable
          : lastErrorCode as String?,
      nextAttemptAt: nextAttemptAt == const $CopyWithPlaceholder()
          ? _value.nextAttemptAt
          // ignore: cast_nullable_to_non_nullable
          : nextAttemptAt as DateTime?,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as BrokerageOrderReconciliationStatusEnum?,
    );
  }
}

extension $BrokerageOrderReconciliationCopyWith
    on BrokerageOrderReconciliation {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageOrderReconciliation.copyWith(...)` or like so:`instanceOfBrokerageOrderReconciliation.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageOrderReconciliationCWProxy get copyWith =>
      _$BrokerageOrderReconciliationCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageOrderReconciliation _$BrokerageOrderReconciliationFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'BrokerageOrderReconciliation',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'attempts',
        'command',
        'egress_started_at',
        'last_error_code',
        'next_attempt_at',
        'status',
      ],
    );
    final val = BrokerageOrderReconciliation(
      attempts: $checkedConvert('attempts', (v) => (v as num).toInt()),
      command: $checkedConvert(
        'command',
        (v) => BrokerageOrderCommand.fromJson(v as Map<String, dynamic>),
      ),
      egressStartedAt: $checkedConvert(
        'egress_started_at',
        (v) => DateTime.parse(v as String),
      ),
      lastErrorCode: $checkedConvert('last_error_code', (v) => v as String?),
      nextAttemptAt: $checkedConvert(
        'next_attempt_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      status: $checkedConvert(
        'status',
        (v) => $enumDecodeNullable(
          _$BrokerageOrderReconciliationStatusEnumEnumMap,
          v,
          unknownValue:
              BrokerageOrderReconciliationStatusEnum.unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'egressStartedAt': 'egress_started_at',
    'lastErrorCode': 'last_error_code',
    'nextAttemptAt': 'next_attempt_at',
  },
);

Map<String, dynamic> _$BrokerageOrderReconciliationToJson(
  BrokerageOrderReconciliation instance,
) => <String, dynamic>{
  'attempts': instance.attempts,
  'command': instance.command.toJson(),
  'egress_started_at': instance.egressStartedAt.toIso8601String(),
  'last_error_code': instance.lastErrorCode,
  'next_attempt_at': instance.nextAttemptAt?.toIso8601String(),
  'status': _$BrokerageOrderReconciliationStatusEnumEnumMap[instance.status],
};

const _$BrokerageOrderReconciliationStatusEnumEnumMap = {
  BrokerageOrderReconciliationStatusEnum.pending: 'pending',
  BrokerageOrderReconciliationStatusEnum.running: 'running',
  BrokerageOrderReconciliationStatusEnum.resolved: 'resolved',
  BrokerageOrderReconciliationStatusEnum.manualReview: 'manual_review',
  BrokerageOrderReconciliationStatusEnum.exhausted: 'exhausted',
  BrokerageOrderReconciliationStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
