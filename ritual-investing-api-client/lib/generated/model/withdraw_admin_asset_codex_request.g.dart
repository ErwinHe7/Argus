// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'withdraw_admin_asset_codex_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WithdrawAdminAssetCodexRequestCWProxy {
  WithdrawAdminAssetCodexRequest reason(String reason);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WithdrawAdminAssetCodexRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WithdrawAdminAssetCodexRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  WithdrawAdminAssetCodexRequest call({String reason});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWithdrawAdminAssetCodexRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWithdrawAdminAssetCodexRequest.copyWith.fieldName(...)`
class _$WithdrawAdminAssetCodexRequestCWProxyImpl
    implements _$WithdrawAdminAssetCodexRequestCWProxy {
  const _$WithdrawAdminAssetCodexRequestCWProxyImpl(this._value);

  final WithdrawAdminAssetCodexRequest _value;

  @override
  WithdrawAdminAssetCodexRequest reason(String reason) => this(reason: reason);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WithdrawAdminAssetCodexRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WithdrawAdminAssetCodexRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  WithdrawAdminAssetCodexRequest call({
    Object? reason = const $CopyWithPlaceholder(),
  }) {
    return WithdrawAdminAssetCodexRequest(
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as String,
    );
  }
}

extension $WithdrawAdminAssetCodexRequestCopyWith
    on WithdrawAdminAssetCodexRequest {
  /// Returns a callable class that can be used as follows: `instanceOfWithdrawAdminAssetCodexRequest.copyWith(...)` or like so:`instanceOfWithdrawAdminAssetCodexRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WithdrawAdminAssetCodexRequestCWProxy get copyWith =>
      _$WithdrawAdminAssetCodexRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WithdrawAdminAssetCodexRequest _$WithdrawAdminAssetCodexRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WithdrawAdminAssetCodexRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['reason']);
  final val = WithdrawAdminAssetCodexRequest(
    reason: $checkedConvert('reason', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$WithdrawAdminAssetCodexRequestToJson(
  WithdrawAdminAssetCodexRequest instance,
) => <String, dynamic>{'reason': instance.reason};
