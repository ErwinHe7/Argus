// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'select_webull_account_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SelectWebullAccountRequestCWProxy {
  SelectWebullAccountRequest accountId(String accountId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SelectWebullAccountRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SelectWebullAccountRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  SelectWebullAccountRequest call({String accountId});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSelectWebullAccountRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSelectWebullAccountRequest.copyWith.fieldName(...)`
class _$SelectWebullAccountRequestCWProxyImpl
    implements _$SelectWebullAccountRequestCWProxy {
  const _$SelectWebullAccountRequestCWProxyImpl(this._value);

  final SelectWebullAccountRequest _value;

  @override
  SelectWebullAccountRequest accountId(String accountId) =>
      this(accountId: accountId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SelectWebullAccountRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SelectWebullAccountRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  SelectWebullAccountRequest call({
    Object? accountId = const $CopyWithPlaceholder(),
  }) {
    return SelectWebullAccountRequest(
      accountId: accountId == const $CopyWithPlaceholder()
          ? _value.accountId
          // ignore: cast_nullable_to_non_nullable
          : accountId as String,
    );
  }
}

extension $SelectWebullAccountRequestCopyWith on SelectWebullAccountRequest {
  /// Returns a callable class that can be used as follows: `instanceOfSelectWebullAccountRequest.copyWith(...)` or like so:`instanceOfSelectWebullAccountRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SelectWebullAccountRequestCWProxy get copyWith =>
      _$SelectWebullAccountRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SelectWebullAccountRequest _$SelectWebullAccountRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SelectWebullAccountRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['account_id']);
  final val = SelectWebullAccountRequest(
    accountId: $checkedConvert('account_id', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'accountId': 'account_id'});

Map<String, dynamic> _$SelectWebullAccountRequestToJson(
  SelectWebullAccountRequest instance,
) => <String, dynamic>{'account_id': instance.accountId};
