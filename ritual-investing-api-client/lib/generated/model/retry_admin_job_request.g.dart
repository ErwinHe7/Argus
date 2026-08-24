// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'retry_admin_job_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RetryAdminJobRequestCWProxy {
  RetryAdminJobRequest reason(String reason);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RetryAdminJobRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RetryAdminJobRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RetryAdminJobRequest call({String reason});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRetryAdminJobRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRetryAdminJobRequest.copyWith.fieldName(...)`
class _$RetryAdminJobRequestCWProxyImpl
    implements _$RetryAdminJobRequestCWProxy {
  const _$RetryAdminJobRequestCWProxyImpl(this._value);

  final RetryAdminJobRequest _value;

  @override
  RetryAdminJobRequest reason(String reason) => this(reason: reason);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RetryAdminJobRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RetryAdminJobRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RetryAdminJobRequest call({Object? reason = const $CopyWithPlaceholder()}) {
    return RetryAdminJobRequest(
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as String,
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
  $checkKeys(json, requiredKeys: const ['reason']);
  final val = RetryAdminJobRequest(
    reason: $checkedConvert('reason', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$RetryAdminJobRequestToJson(
  RetryAdminJobRequest instance,
) => <String, dynamic>{'reason': instance.reason};
