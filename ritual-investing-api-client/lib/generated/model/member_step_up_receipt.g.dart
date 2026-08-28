// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_step_up_receipt.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberStepUpReceiptCWProxy {
  MemberStepUpReceipt action(MemberStepUpReceiptActionEnum action);

  MemberStepUpReceipt expiresAt(DateTime expiresAt);

  MemberStepUpReceipt receipt(String receipt);

  MemberStepUpReceipt sessionId(String sessionId);

  MemberStepUpReceipt userId(String userId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberStepUpReceipt(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberStepUpReceipt(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberStepUpReceipt call({
    MemberStepUpReceiptActionEnum action,
    DateTime expiresAt,
    String receipt,
    String sessionId,
    String userId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberStepUpReceipt.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberStepUpReceipt.copyWith.fieldName(...)`
class _$MemberStepUpReceiptCWProxyImpl implements _$MemberStepUpReceiptCWProxy {
  const _$MemberStepUpReceiptCWProxyImpl(this._value);

  final MemberStepUpReceipt _value;

  @override
  MemberStepUpReceipt action(MemberStepUpReceiptActionEnum action) =>
      this(action: action);

  @override
  MemberStepUpReceipt expiresAt(DateTime expiresAt) =>
      this(expiresAt: expiresAt);

  @override
  MemberStepUpReceipt receipt(String receipt) => this(receipt: receipt);

  @override
  MemberStepUpReceipt sessionId(String sessionId) => this(sessionId: sessionId);

  @override
  MemberStepUpReceipt userId(String userId) => this(userId: userId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberStepUpReceipt(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberStepUpReceipt(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberStepUpReceipt call({
    Object? action = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? receipt = const $CopyWithPlaceholder(),
    Object? sessionId = const $CopyWithPlaceholder(),
    Object? userId = const $CopyWithPlaceholder(),
  }) {
    return MemberStepUpReceipt(
      action: action == const $CopyWithPlaceholder()
          ? _value.action
          // ignore: cast_nullable_to_non_nullable
          : action as MemberStepUpReceiptActionEnum,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime,
      receipt: receipt == const $CopyWithPlaceholder()
          ? _value.receipt
          // ignore: cast_nullable_to_non_nullable
          : receipt as String,
      sessionId: sessionId == const $CopyWithPlaceholder()
          ? _value.sessionId
          // ignore: cast_nullable_to_non_nullable
          : sessionId as String,
      userId: userId == const $CopyWithPlaceholder()
          ? _value.userId
          // ignore: cast_nullable_to_non_nullable
          : userId as String,
    );
  }
}

extension $MemberStepUpReceiptCopyWith on MemberStepUpReceipt {
  /// Returns a callable class that can be used as follows: `instanceOfMemberStepUpReceipt.copyWith(...)` or like so:`instanceOfMemberStepUpReceipt.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberStepUpReceiptCWProxy get copyWith =>
      _$MemberStepUpReceiptCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberStepUpReceipt _$MemberStepUpReceiptFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'MemberStepUpReceipt',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'action',
            'expires_at',
            'receipt',
            'session_id',
            'user_id',
          ],
        );
        final val = MemberStepUpReceipt(
          action: $checkedConvert(
            'action',
            (v) => $enumDecode(
              _$MemberStepUpReceiptActionEnumEnumMap,
              v,
              unknownValue: MemberStepUpReceiptActionEnum.unknownDefaultOpenApi,
            ),
          ),
          expiresAt: $checkedConvert(
            'expires_at',
            (v) => DateTime.parse(v as String),
          ),
          receipt: $checkedConvert('receipt', (v) => v as String),
          sessionId: $checkedConvert('session_id', (v) => v as String),
          userId: $checkedConvert('user_id', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'expiresAt': 'expires_at',
        'sessionId': 'session_id',
        'userId': 'user_id',
      },
    );

Map<String, dynamic> _$MemberStepUpReceiptToJson(
  MemberStepUpReceipt instance,
) => <String, dynamic>{
  'action': _$MemberStepUpReceiptActionEnumEnumMap[instance.action]!,
  'expires_at': instance.expiresAt.toIso8601String(),
  'receipt': instance.receipt,
  'session_id': instance.sessionId,
  'user_id': instance.userId,
};

const _$MemberStepUpReceiptActionEnumEnumMap = {
  MemberStepUpReceiptActionEnum.webullDisconnect: 'webull_disconnect',
  MemberStepUpReceiptActionEnum.argusDelete: 'argus_delete',
  MemberStepUpReceiptActionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
