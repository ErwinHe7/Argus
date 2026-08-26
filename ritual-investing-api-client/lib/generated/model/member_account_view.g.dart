// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_account_view.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberAccountViewCWProxy {
  MemberAccountView account(MemberAccountViewAccount account);

  MemberAccountView profile(MemberProfile profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberAccountView(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberAccountView(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberAccountView call({
    MemberAccountViewAccount account,
    MemberProfile profile,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberAccountView.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberAccountView.copyWith.fieldName(...)`
class _$MemberAccountViewCWProxyImpl implements _$MemberAccountViewCWProxy {
  const _$MemberAccountViewCWProxyImpl(this._value);

  final MemberAccountView _value;

  @override
  MemberAccountView account(MemberAccountViewAccount account) =>
      this(account: account);

  @override
  MemberAccountView profile(MemberProfile profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberAccountView(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberAccountView(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberAccountView call({
    Object? account = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return MemberAccountView(
      account: account == const $CopyWithPlaceholder()
          ? _value.account
          // ignore: cast_nullable_to_non_nullable
          : account as MemberAccountViewAccount,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as MemberProfile,
    );
  }
}

extension $MemberAccountViewCopyWith on MemberAccountView {
  /// Returns a callable class that can be used as follows: `instanceOfMemberAccountView.copyWith(...)` or like so:`instanceOfMemberAccountView.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberAccountViewCWProxy get copyWith =>
      _$MemberAccountViewCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberAccountView _$MemberAccountViewFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MemberAccountView', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['account', 'profile']);
      final val = MemberAccountView(
        account: $checkedConvert(
          'account',
          (v) => MemberAccountViewAccount.fromJson(v as Map<String, dynamic>),
        ),
        profile: $checkedConvert(
          'profile',
          (v) => MemberProfile.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$MemberAccountViewToJson(MemberAccountView instance) =>
    <String, dynamic>{
      'account': instance.account.toJson(),
      'profile': instance.profile.toJson(),
    };
