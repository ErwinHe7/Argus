// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_order_preview_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageOrderPreviewResponseCWProxy {
  BrokerageOrderPreviewResponse data(BrokerageOrderPreview data);

  BrokerageOrderPreviewResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrderPreviewResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrderPreviewResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrderPreviewResponse call({
    BrokerageOrderPreview data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageOrderPreviewResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageOrderPreviewResponse.copyWith.fieldName(...)`
class _$BrokerageOrderPreviewResponseCWProxyImpl
    implements _$BrokerageOrderPreviewResponseCWProxy {
  const _$BrokerageOrderPreviewResponseCWProxyImpl(this._value);

  final BrokerageOrderPreviewResponse _value;

  @override
  BrokerageOrderPreviewResponse data(BrokerageOrderPreview data) =>
      this(data: data);

  @override
  BrokerageOrderPreviewResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrderPreviewResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrderPreviewResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrderPreviewResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return BrokerageOrderPreviewResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as BrokerageOrderPreview,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $BrokerageOrderPreviewResponseCopyWith
    on BrokerageOrderPreviewResponse {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageOrderPreviewResponse.copyWith(...)` or like so:`instanceOfBrokerageOrderPreviewResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageOrderPreviewResponseCWProxy get copyWith =>
      _$BrokerageOrderPreviewResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageOrderPreviewResponse _$BrokerageOrderPreviewResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('BrokerageOrderPreviewResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = BrokerageOrderPreviewResponse(
    data: $checkedConvert(
      'data',
      (v) => BrokerageOrderPreview.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$BrokerageOrderPreviewResponseToJson(
  BrokerageOrderPreviewResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
