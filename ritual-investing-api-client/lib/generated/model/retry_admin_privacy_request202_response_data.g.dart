// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'retry_admin_privacy_request202_response_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RetryAdminPrivacyRequest202ResponseDataCWProxy {
  RetryAdminPrivacyRequest202ResponseData outboxId(String outboxId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RetryAdminPrivacyRequest202ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RetryAdminPrivacyRequest202ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  RetryAdminPrivacyRequest202ResponseData call({String outboxId});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRetryAdminPrivacyRequest202ResponseData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRetryAdminPrivacyRequest202ResponseData.copyWith.fieldName(...)`
class _$RetryAdminPrivacyRequest202ResponseDataCWProxyImpl
    implements _$RetryAdminPrivacyRequest202ResponseDataCWProxy {
  const _$RetryAdminPrivacyRequest202ResponseDataCWProxyImpl(this._value);

  final RetryAdminPrivacyRequest202ResponseData _value;

  @override
  RetryAdminPrivacyRequest202ResponseData outboxId(String outboxId) =>
      this(outboxId: outboxId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RetryAdminPrivacyRequest202ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RetryAdminPrivacyRequest202ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  RetryAdminPrivacyRequest202ResponseData call({
    Object? outboxId = const $CopyWithPlaceholder(),
  }) {
    return RetryAdminPrivacyRequest202ResponseData(
      outboxId: outboxId == const $CopyWithPlaceholder()
          ? _value.outboxId
          // ignore: cast_nullable_to_non_nullable
          : outboxId as String,
    );
  }
}

extension $RetryAdminPrivacyRequest202ResponseDataCopyWith
    on RetryAdminPrivacyRequest202ResponseData {
  /// Returns a callable class that can be used as follows: `instanceOfRetryAdminPrivacyRequest202ResponseData.copyWith(...)` or like so:`instanceOfRetryAdminPrivacyRequest202ResponseData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RetryAdminPrivacyRequest202ResponseDataCWProxy get copyWith =>
      _$RetryAdminPrivacyRequest202ResponseDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RetryAdminPrivacyRequest202ResponseData
_$RetryAdminPrivacyRequest202ResponseDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RetryAdminPrivacyRequest202ResponseData', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['outbox_id']);
      final val = RetryAdminPrivacyRequest202ResponseData(
        outboxId: $checkedConvert('outbox_id', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'outboxId': 'outbox_id'});

Map<String, dynamic> _$RetryAdminPrivacyRequest202ResponseDataToJson(
  RetryAdminPrivacyRequest202ResponseData instance,
) => <String, dynamic>{'outbox_id': instance.outboxId};
