// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_bootstrap_account.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionBootstrapAccountCWProxy {
  SessionBootstrapAccount id(String id);

  SessionBootstrapAccount status(SessionBootstrapAccountStatusEnum status);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapAccount(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapAccount(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapAccount call({
    String id,
    SessionBootstrapAccountStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionBootstrapAccount.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionBootstrapAccount.copyWith.fieldName(...)`
class _$SessionBootstrapAccountCWProxyImpl
    implements _$SessionBootstrapAccountCWProxy {
  const _$SessionBootstrapAccountCWProxyImpl(this._value);

  final SessionBootstrapAccount _value;

  @override
  SessionBootstrapAccount id(String id) => this(id: id);

  @override
  SessionBootstrapAccount status(SessionBootstrapAccountStatusEnum status) =>
      this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapAccount(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapAccount(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapAccount call({
    Object? id = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return SessionBootstrapAccount(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as SessionBootstrapAccountStatusEnum,
    );
  }
}

extension $SessionBootstrapAccountCopyWith on SessionBootstrapAccount {
  /// Returns a callable class that can be used as follows: `instanceOfSessionBootstrapAccount.copyWith(...)` or like so:`instanceOfSessionBootstrapAccount.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SessionBootstrapAccountCWProxy get copyWith =>
      _$SessionBootstrapAccountCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionBootstrapAccount _$SessionBootstrapAccountFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SessionBootstrapAccount', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['id', 'status']);
  final val = SessionBootstrapAccount(
    id: $checkedConvert('id', (v) => v as String),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(
        _$SessionBootstrapAccountStatusEnumEnumMap,
        v,
        unknownValue: SessionBootstrapAccountStatusEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
});

Map<String, dynamic> _$SessionBootstrapAccountToJson(
  SessionBootstrapAccount instance,
) => <String, dynamic>{
  'id': instance.id,
  'status': _$SessionBootstrapAccountStatusEnumEnumMap[instance.status]!,
};

const _$SessionBootstrapAccountStatusEnumEnumMap = {
  SessionBootstrapAccountStatusEnum.active: 'active',
  SessionBootstrapAccountStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
