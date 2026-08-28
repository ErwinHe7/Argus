// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'confirm_modify_brokerage_order.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ConfirmModifyBrokerageOrderCWProxy {
  ConfirmModifyBrokerageOrder confirmed(bool confirmed);

  ConfirmModifyBrokerageOrder intent(ModifyBrokerageOrderIntent intent);

  ConfirmModifyBrokerageOrder previewId(String previewId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ConfirmModifyBrokerageOrder(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ConfirmModifyBrokerageOrder(...).copyWith(id: 12, name: "My name")
  /// ````
  ConfirmModifyBrokerageOrder call({
    bool confirmed,
    ModifyBrokerageOrderIntent intent,
    String previewId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfConfirmModifyBrokerageOrder.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfConfirmModifyBrokerageOrder.copyWith.fieldName(...)`
class _$ConfirmModifyBrokerageOrderCWProxyImpl
    implements _$ConfirmModifyBrokerageOrderCWProxy {
  const _$ConfirmModifyBrokerageOrderCWProxyImpl(this._value);

  final ConfirmModifyBrokerageOrder _value;

  @override
  ConfirmModifyBrokerageOrder confirmed(bool confirmed) =>
      this(confirmed: confirmed);

  @override
  ConfirmModifyBrokerageOrder intent(ModifyBrokerageOrderIntent intent) =>
      this(intent: intent);

  @override
  ConfirmModifyBrokerageOrder previewId(String previewId) =>
      this(previewId: previewId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ConfirmModifyBrokerageOrder(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ConfirmModifyBrokerageOrder(...).copyWith(id: 12, name: "My name")
  /// ````
  ConfirmModifyBrokerageOrder call({
    Object? confirmed = const $CopyWithPlaceholder(),
    Object? intent = const $CopyWithPlaceholder(),
    Object? previewId = const $CopyWithPlaceholder(),
  }) {
    return ConfirmModifyBrokerageOrder(
      confirmed: confirmed == const $CopyWithPlaceholder()
          ? _value.confirmed
          // ignore: cast_nullable_to_non_nullable
          : confirmed as bool,
      intent: intent == const $CopyWithPlaceholder()
          ? _value.intent
          // ignore: cast_nullable_to_non_nullable
          : intent as ModifyBrokerageOrderIntent,
      previewId: previewId == const $CopyWithPlaceholder()
          ? _value.previewId
          // ignore: cast_nullable_to_non_nullable
          : previewId as String,
    );
  }
}

extension $ConfirmModifyBrokerageOrderCopyWith on ConfirmModifyBrokerageOrder {
  /// Returns a callable class that can be used as follows: `instanceOfConfirmModifyBrokerageOrder.copyWith(...)` or like so:`instanceOfConfirmModifyBrokerageOrder.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ConfirmModifyBrokerageOrderCWProxy get copyWith =>
      _$ConfirmModifyBrokerageOrderCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfirmModifyBrokerageOrder _$ConfirmModifyBrokerageOrderFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ConfirmModifyBrokerageOrder', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['confirmed', 'intent', 'preview_id']);
  final val = ConfirmModifyBrokerageOrder(
    confirmed: $checkedConvert('confirmed', (v) => v as bool),
    intent: $checkedConvert(
      'intent',
      (v) => ModifyBrokerageOrderIntent.fromJson(v as Map<String, dynamic>),
    ),
    previewId: $checkedConvert('preview_id', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'previewId': 'preview_id'});

Map<String, dynamic> _$ConfirmModifyBrokerageOrderToJson(
  ConfirmModifyBrokerageOrder instance,
) => <String, dynamic>{
  'confirmed': instance.confirmed,
  'intent': instance.intent.toJson(),
  'preview_id': instance.previewId,
};
