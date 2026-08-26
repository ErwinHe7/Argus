// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'consent_receipt_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ConsentReceiptResponseCWProxy {
  ConsentReceiptResponse data(ConsentReceipt data);

  ConsentReceiptResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ConsentReceiptResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ConsentReceiptResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  ConsentReceiptResponse call({ConsentReceipt data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfConsentReceiptResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfConsentReceiptResponse.copyWith.fieldName(...)`
class _$ConsentReceiptResponseCWProxyImpl
    implements _$ConsentReceiptResponseCWProxy {
  const _$ConsentReceiptResponseCWProxyImpl(this._value);

  final ConsentReceiptResponse _value;

  @override
  ConsentReceiptResponse data(ConsentReceipt data) => this(data: data);

  @override
  ConsentReceiptResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ConsentReceiptResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ConsentReceiptResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  ConsentReceiptResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ConsentReceiptResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as ConsentReceipt,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $ConsentReceiptResponseCopyWith on ConsentReceiptResponse {
  /// Returns a callable class that can be used as follows: `instanceOfConsentReceiptResponse.copyWith(...)` or like so:`instanceOfConsentReceiptResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ConsentReceiptResponseCWProxy get copyWith =>
      _$ConsentReceiptResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConsentReceiptResponse _$ConsentReceiptResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ConsentReceiptResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ConsentReceiptResponse(
    data: $checkedConvert(
      'data',
      (v) => ConsentReceipt.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ConsentReceiptResponseToJson(
  ConsentReceiptResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
