// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'confirm_cancel_brokerage_order.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ConfirmCancelBrokerageOrderCWProxy {
  ConfirmCancelBrokerageOrder confirmed(bool confirmed);

  ConfirmCancelBrokerageOrder previewId(String previewId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ConfirmCancelBrokerageOrder(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ConfirmCancelBrokerageOrder(...).copyWith(id: 12, name: "My name")
  /// ````
  ConfirmCancelBrokerageOrder call({bool confirmed, String previewId});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfConfirmCancelBrokerageOrder.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfConfirmCancelBrokerageOrder.copyWith.fieldName(...)`
class _$ConfirmCancelBrokerageOrderCWProxyImpl
    implements _$ConfirmCancelBrokerageOrderCWProxy {
  const _$ConfirmCancelBrokerageOrderCWProxyImpl(this._value);

  final ConfirmCancelBrokerageOrder _value;

  @override
  ConfirmCancelBrokerageOrder confirmed(bool confirmed) =>
      this(confirmed: confirmed);

  @override
  ConfirmCancelBrokerageOrder previewId(String previewId) =>
      this(previewId: previewId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ConfirmCancelBrokerageOrder(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ConfirmCancelBrokerageOrder(...).copyWith(id: 12, name: "My name")
  /// ````
  ConfirmCancelBrokerageOrder call({
    Object? confirmed = const $CopyWithPlaceholder(),
    Object? previewId = const $CopyWithPlaceholder(),
  }) {
    return ConfirmCancelBrokerageOrder(
      confirmed: confirmed == const $CopyWithPlaceholder()
          ? _value.confirmed
          // ignore: cast_nullable_to_non_nullable
          : confirmed as bool,
      previewId: previewId == const $CopyWithPlaceholder()
          ? _value.previewId
          // ignore: cast_nullable_to_non_nullable
          : previewId as String,
    );
  }
}

extension $ConfirmCancelBrokerageOrderCopyWith on ConfirmCancelBrokerageOrder {
  /// Returns a callable class that can be used as follows: `instanceOfConfirmCancelBrokerageOrder.copyWith(...)` or like so:`instanceOfConfirmCancelBrokerageOrder.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ConfirmCancelBrokerageOrderCWProxy get copyWith =>
      _$ConfirmCancelBrokerageOrderCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfirmCancelBrokerageOrder _$ConfirmCancelBrokerageOrderFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ConfirmCancelBrokerageOrder', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['confirmed', 'preview_id']);
  final val = ConfirmCancelBrokerageOrder(
    confirmed: $checkedConvert('confirmed', (v) => v as bool),
    previewId: $checkedConvert('preview_id', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'previewId': 'preview_id'});

Map<String, dynamic> _$ConfirmCancelBrokerageOrderToJson(
  ConfirmCancelBrokerageOrder instance,
) => <String, dynamic>{
  'confirmed': instance.confirmed,
  'preview_id': instance.previewId,
};
