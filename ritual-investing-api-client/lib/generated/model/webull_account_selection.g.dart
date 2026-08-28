// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webull_account_selection.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WebullAccountSelectionCWProxy {
  WebullAccountSelection accountId(String accountId);

  WebullAccountSelection selected(bool selected);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullAccountSelection(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullAccountSelection(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullAccountSelection call({String accountId, bool selected});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWebullAccountSelection.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWebullAccountSelection.copyWith.fieldName(...)`
class _$WebullAccountSelectionCWProxyImpl
    implements _$WebullAccountSelectionCWProxy {
  const _$WebullAccountSelectionCWProxyImpl(this._value);

  final WebullAccountSelection _value;

  @override
  WebullAccountSelection accountId(String accountId) =>
      this(accountId: accountId);

  @override
  WebullAccountSelection selected(bool selected) => this(selected: selected);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullAccountSelection(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullAccountSelection(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullAccountSelection call({
    Object? accountId = const $CopyWithPlaceholder(),
    Object? selected = const $CopyWithPlaceholder(),
  }) {
    return WebullAccountSelection(
      accountId: accountId == const $CopyWithPlaceholder()
          ? _value.accountId
          // ignore: cast_nullable_to_non_nullable
          : accountId as String,
      selected: selected == const $CopyWithPlaceholder()
          ? _value.selected
          // ignore: cast_nullable_to_non_nullable
          : selected as bool,
    );
  }
}

extension $WebullAccountSelectionCopyWith on WebullAccountSelection {
  /// Returns a callable class that can be used as follows: `instanceOfWebullAccountSelection.copyWith(...)` or like so:`instanceOfWebullAccountSelection.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WebullAccountSelectionCWProxy get copyWith =>
      _$WebullAccountSelectionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebullAccountSelection _$WebullAccountSelectionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WebullAccountSelection', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['account_id', 'selected']);
  final val = WebullAccountSelection(
    accountId: $checkedConvert('account_id', (v) => v as String),
    selected: $checkedConvert('selected', (v) => v as bool),
  );
  return val;
}, fieldKeyMap: const {'accountId': 'account_id'});

Map<String, dynamic> _$WebullAccountSelectionToJson(
  WebullAccountSelection instance,
) => <String, dynamic>{
  'account_id': instance.accountId,
  'selected': instance.selected,
};
