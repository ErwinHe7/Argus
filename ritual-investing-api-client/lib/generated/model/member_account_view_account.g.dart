// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_account_view_account.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberAccountViewAccountCWProxy {
  MemberAccountViewAccount id(String id);

  MemberAccountViewAccount status(MemberAccountViewAccountStatusEnum status);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberAccountViewAccount(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberAccountViewAccount(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberAccountViewAccount call({
    String id,
    MemberAccountViewAccountStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberAccountViewAccount.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberAccountViewAccount.copyWith.fieldName(...)`
class _$MemberAccountViewAccountCWProxyImpl
    implements _$MemberAccountViewAccountCWProxy {
  const _$MemberAccountViewAccountCWProxyImpl(this._value);

  final MemberAccountViewAccount _value;

  @override
  MemberAccountViewAccount id(String id) => this(id: id);

  @override
  MemberAccountViewAccount status(MemberAccountViewAccountStatusEnum status) =>
      this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberAccountViewAccount(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberAccountViewAccount(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberAccountViewAccount call({
    Object? id = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return MemberAccountViewAccount(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as MemberAccountViewAccountStatusEnum,
    );
  }
}

extension $MemberAccountViewAccountCopyWith on MemberAccountViewAccount {
  /// Returns a callable class that can be used as follows: `instanceOfMemberAccountViewAccount.copyWith(...)` or like so:`instanceOfMemberAccountViewAccount.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberAccountViewAccountCWProxy get copyWith =>
      _$MemberAccountViewAccountCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberAccountViewAccount _$MemberAccountViewAccountFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MemberAccountViewAccount', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['id', 'status']);
  final val = MemberAccountViewAccount(
    id: $checkedConvert('id', (v) => v as String),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(
        _$MemberAccountViewAccountStatusEnumEnumMap,
        v,
        unknownValue: MemberAccountViewAccountStatusEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
});

Map<String, dynamic> _$MemberAccountViewAccountToJson(
  MemberAccountViewAccount instance,
) => <String, dynamic>{
  'id': instance.id,
  'status': _$MemberAccountViewAccountStatusEnumEnumMap[instance.status]!,
};

const _$MemberAccountViewAccountStatusEnumEnumMap = {
  MemberAccountViewAccountStatusEnum.active: 'active',
  MemberAccountViewAccountStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
