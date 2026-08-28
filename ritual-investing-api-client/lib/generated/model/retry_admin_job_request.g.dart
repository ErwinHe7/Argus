// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'retry_admin_job_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RetryAdminJobRequestCWProxy {
  RetryAdminJobRequest stepUpReceipt(String stepUpReceipt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RetryAdminJobRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RetryAdminJobRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RetryAdminJobRequest call({String stepUpReceipt});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRetryAdminJobRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRetryAdminJobRequest.copyWith.fieldName(...)`
class _$RetryAdminJobRequestCWProxyImpl
    implements _$RetryAdminJobRequestCWProxy {
  const _$RetryAdminJobRequestCWProxyImpl(this._value);

  final RetryAdminJobRequest _value;

  @override
  RetryAdminJobRequest stepUpReceipt(String stepUpReceipt) =>
      this(stepUpReceipt: stepUpReceipt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RetryAdminJobRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RetryAdminJobRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RetryAdminJobRequest call({
    Object? stepUpReceipt = const $CopyWithPlaceholder(),
  }) {
    return RetryAdminJobRequest(
      stepUpReceipt: stepUpReceipt == const $CopyWithPlaceholder()
          ? _value.stepUpReceipt
          // ignore: cast_nullable_to_non_nullable
          : stepUpReceipt as String,
    );
  }
}

extension $RetryAdminJobRequestCopyWith on RetryAdminJobRequest {
  /// Returns a callable class that can be used as follows: `instanceOfRetryAdminJobRequest.copyWith(...)` or like so:`instanceOfRetryAdminJobRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RetryAdminJobRequestCWProxy get copyWith =>
      _$RetryAdminJobRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RetryAdminJobRequest _$RetryAdminJobRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RetryAdminJobRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['step_up_receipt']);
  final val = RetryAdminJobRequest(
    stepUpReceipt: $checkedConvert('step_up_receipt', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'stepUpReceipt': 'step_up_receipt'});

Map<String, dynamic> _$RetryAdminJobRequestToJson(
  RetryAdminJobRequest instance,
) => <String, dynamic>{'step_up_receipt': instance.stepUpReceipt};
