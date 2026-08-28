// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_order_command.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageOrderCommandCWProxy {
  BrokerageOrderCommand accountId(String accountId);

  BrokerageOrderCommand ambiguous(bool ambiguous);

  BrokerageOrderCommand createdAt(DateTime createdAt);

  BrokerageOrderCommand id(String id);

  BrokerageOrderCommand operation(BrokerageOrderCommandOperationEnum operation);

  BrokerageOrderCommand orderId(String? orderId);

  BrokerageOrderCommand state(BrokerageOrderCommandStateEnum state);

  BrokerageOrderCommand targetOrderId(String? targetOrderId);

  BrokerageOrderCommand updatedAt(DateTime updatedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrderCommand(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrderCommand(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrderCommand call({
    String accountId,
    bool ambiguous,
    DateTime createdAt,
    String id,
    BrokerageOrderCommandOperationEnum operation,
    String? orderId,
    BrokerageOrderCommandStateEnum state,
    String? targetOrderId,
    DateTime updatedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageOrderCommand.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageOrderCommand.copyWith.fieldName(...)`
class _$BrokerageOrderCommandCWProxyImpl
    implements _$BrokerageOrderCommandCWProxy {
  const _$BrokerageOrderCommandCWProxyImpl(this._value);

  final BrokerageOrderCommand _value;

  @override
  BrokerageOrderCommand accountId(String accountId) =>
      this(accountId: accountId);

  @override
  BrokerageOrderCommand ambiguous(bool ambiguous) => this(ambiguous: ambiguous);

  @override
  BrokerageOrderCommand createdAt(DateTime createdAt) =>
      this(createdAt: createdAt);

  @override
  BrokerageOrderCommand id(String id) => this(id: id);

  @override
  BrokerageOrderCommand operation(
    BrokerageOrderCommandOperationEnum operation,
  ) => this(operation: operation);

  @override
  BrokerageOrderCommand orderId(String? orderId) => this(orderId: orderId);

  @override
  BrokerageOrderCommand state(BrokerageOrderCommandStateEnum state) =>
      this(state: state);

  @override
  BrokerageOrderCommand targetOrderId(String? targetOrderId) =>
      this(targetOrderId: targetOrderId);

  @override
  BrokerageOrderCommand updatedAt(DateTime updatedAt) =>
      this(updatedAt: updatedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrderCommand(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrderCommand(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrderCommand call({
    Object? accountId = const $CopyWithPlaceholder(),
    Object? ambiguous = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? operation = const $CopyWithPlaceholder(),
    Object? orderId = const $CopyWithPlaceholder(),
    Object? state = const $CopyWithPlaceholder(),
    Object? targetOrderId = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
  }) {
    return BrokerageOrderCommand(
      accountId: accountId == const $CopyWithPlaceholder()
          ? _value.accountId
          // ignore: cast_nullable_to_non_nullable
          : accountId as String,
      ambiguous: ambiguous == const $CopyWithPlaceholder()
          ? _value.ambiguous
          // ignore: cast_nullable_to_non_nullable
          : ambiguous as bool,
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      operation: operation == const $CopyWithPlaceholder()
          ? _value.operation
          // ignore: cast_nullable_to_non_nullable
          : operation as BrokerageOrderCommandOperationEnum,
      orderId: orderId == const $CopyWithPlaceholder()
          ? _value.orderId
          // ignore: cast_nullable_to_non_nullable
          : orderId as String?,
      state: state == const $CopyWithPlaceholder()
          ? _value.state
          // ignore: cast_nullable_to_non_nullable
          : state as BrokerageOrderCommandStateEnum,
      targetOrderId: targetOrderId == const $CopyWithPlaceholder()
          ? _value.targetOrderId
          // ignore: cast_nullable_to_non_nullable
          : targetOrderId as String?,
      updatedAt: updatedAt == const $CopyWithPlaceholder()
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime,
    );
  }
}

extension $BrokerageOrderCommandCopyWith on BrokerageOrderCommand {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageOrderCommand.copyWith(...)` or like so:`instanceOfBrokerageOrderCommand.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageOrderCommandCWProxy get copyWith =>
      _$BrokerageOrderCommandCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageOrderCommand _$BrokerageOrderCommandFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'BrokerageOrderCommand',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'account_id',
        'ambiguous',
        'created_at',
        'id',
        'operation',
        'order_id',
        'state',
        'target_order_id',
        'updated_at',
      ],
    );
    final val = BrokerageOrderCommand(
      accountId: $checkedConvert('account_id', (v) => v as String),
      ambiguous: $checkedConvert('ambiguous', (v) => v as bool),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
      id: $checkedConvert('id', (v) => v as String),
      operation: $checkedConvert(
        'operation',
        (v) => $enumDecode(
          _$BrokerageOrderCommandOperationEnumEnumMap,
          v,
          unknownValue:
              BrokerageOrderCommandOperationEnum.unknownDefaultOpenApi,
        ),
      ),
      orderId: $checkedConvert('order_id', (v) => v as String?),
      state: $checkedConvert(
        'state',
        (v) => $enumDecode(
          _$BrokerageOrderCommandStateEnumEnumMap,
          v,
          unknownValue: BrokerageOrderCommandStateEnum.unknownDefaultOpenApi,
        ),
      ),
      targetOrderId: $checkedConvert('target_order_id', (v) => v as String?),
      updatedAt: $checkedConvert(
        'updated_at',
        (v) => DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'accountId': 'account_id',
    'createdAt': 'created_at',
    'orderId': 'order_id',
    'targetOrderId': 'target_order_id',
    'updatedAt': 'updated_at',
  },
);

Map<String, dynamic> _$BrokerageOrderCommandToJson(
  BrokerageOrderCommand instance,
) => <String, dynamic>{
  'account_id': instance.accountId,
  'ambiguous': instance.ambiguous,
  'created_at': instance.createdAt.toIso8601String(),
  'id': instance.id,
  'operation': _$BrokerageOrderCommandOperationEnumEnumMap[instance.operation]!,
  'order_id': instance.orderId,
  'state': _$BrokerageOrderCommandStateEnumEnumMap[instance.state]!,
  'target_order_id': instance.targetOrderId,
  'updated_at': instance.updatedAt.toIso8601String(),
};

const _$BrokerageOrderCommandOperationEnumEnumMap = {
  BrokerageOrderCommandOperationEnum.place: 'place',
  BrokerageOrderCommandOperationEnum.modify: 'modify',
  BrokerageOrderCommandOperationEnum.cancel: 'cancel',
  BrokerageOrderCommandOperationEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$BrokerageOrderCommandStateEnumEnumMap = {
  BrokerageOrderCommandStateEnum.dispatching: 'dispatching',
  BrokerageOrderCommandStateEnum.accepted: 'accepted',
  BrokerageOrderCommandStateEnum.ambiguous: 'ambiguous',
  BrokerageOrderCommandStateEnum.reconciling: 'reconciling',
  BrokerageOrderCommandStateEnum.resolved: 'resolved',
  BrokerageOrderCommandStateEnum.failed: 'failed',
  BrokerageOrderCommandStateEnum.manualReview: 'manual_review',
  BrokerageOrderCommandStateEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
