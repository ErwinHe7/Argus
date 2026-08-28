// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'confirm_place_brokerage_order.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ConfirmPlaceBrokerageOrderCWProxy {
  ConfirmPlaceBrokerageOrder confirmed(bool confirmed);

  ConfirmPlaceBrokerageOrder intent(PlaceBrokerageOrderIntent intent);

  ConfirmPlaceBrokerageOrder previewId(String previewId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ConfirmPlaceBrokerageOrder(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ConfirmPlaceBrokerageOrder(...).copyWith(id: 12, name: "My name")
  /// ````
  ConfirmPlaceBrokerageOrder call({
    bool confirmed,
    PlaceBrokerageOrderIntent intent,
    String previewId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfConfirmPlaceBrokerageOrder.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfConfirmPlaceBrokerageOrder.copyWith.fieldName(...)`
class _$ConfirmPlaceBrokerageOrderCWProxyImpl
    implements _$ConfirmPlaceBrokerageOrderCWProxy {
  const _$ConfirmPlaceBrokerageOrderCWProxyImpl(this._value);

  final ConfirmPlaceBrokerageOrder _value;

  @override
  ConfirmPlaceBrokerageOrder confirmed(bool confirmed) =>
      this(confirmed: confirmed);

  @override
  ConfirmPlaceBrokerageOrder intent(PlaceBrokerageOrderIntent intent) =>
      this(intent: intent);

  @override
  ConfirmPlaceBrokerageOrder previewId(String previewId) =>
      this(previewId: previewId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ConfirmPlaceBrokerageOrder(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ConfirmPlaceBrokerageOrder(...).copyWith(id: 12, name: "My name")
  /// ````
  ConfirmPlaceBrokerageOrder call({
    Object? confirmed = const $CopyWithPlaceholder(),
    Object? intent = const $CopyWithPlaceholder(),
    Object? previewId = const $CopyWithPlaceholder(),
  }) {
    return ConfirmPlaceBrokerageOrder(
      confirmed: confirmed == const $CopyWithPlaceholder()
          ? _value.confirmed
          // ignore: cast_nullable_to_non_nullable
          : confirmed as bool,
      intent: intent == const $CopyWithPlaceholder()
          ? _value.intent
          // ignore: cast_nullable_to_non_nullable
          : intent as PlaceBrokerageOrderIntent,
      previewId: previewId == const $CopyWithPlaceholder()
          ? _value.previewId
          // ignore: cast_nullable_to_non_nullable
          : previewId as String,
    );
  }
}

extension $ConfirmPlaceBrokerageOrderCopyWith on ConfirmPlaceBrokerageOrder {
  /// Returns a callable class that can be used as follows: `instanceOfConfirmPlaceBrokerageOrder.copyWith(...)` or like so:`instanceOfConfirmPlaceBrokerageOrder.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ConfirmPlaceBrokerageOrderCWProxy get copyWith =>
      _$ConfirmPlaceBrokerageOrderCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfirmPlaceBrokerageOrder _$ConfirmPlaceBrokerageOrderFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ConfirmPlaceBrokerageOrder', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['confirmed', 'intent', 'preview_id']);
  final val = ConfirmPlaceBrokerageOrder(
    confirmed: $checkedConvert('confirmed', (v) => v as bool),
    intent: $checkedConvert(
      'intent',
      (v) => PlaceBrokerageOrderIntent.fromJson(v as Map<String, dynamic>),
    ),
    previewId: $checkedConvert('preview_id', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'previewId': 'preview_id'});

Map<String, dynamic> _$ConfirmPlaceBrokerageOrderToJson(
  ConfirmPlaceBrokerageOrder instance,
) => <String, dynamic>{
  'confirmed': instance.confirmed,
  'intent': instance.intent.toJson(),
  'preview_id': instance.previewId,
};
