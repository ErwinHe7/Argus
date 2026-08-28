// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_step_up_receipt_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberStepUpReceiptResponseCWProxy {
  MemberStepUpReceiptResponse data(MemberStepUpReceipt data);

  MemberStepUpReceiptResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberStepUpReceiptResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberStepUpReceiptResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberStepUpReceiptResponse call({
    MemberStepUpReceipt data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberStepUpReceiptResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberStepUpReceiptResponse.copyWith.fieldName(...)`
class _$MemberStepUpReceiptResponseCWProxyImpl
    implements _$MemberStepUpReceiptResponseCWProxy {
  const _$MemberStepUpReceiptResponseCWProxyImpl(this._value);

  final MemberStepUpReceiptResponse _value;

  @override
  MemberStepUpReceiptResponse data(MemberStepUpReceipt data) =>
      this(data: data);

  @override
  MemberStepUpReceiptResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberStepUpReceiptResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberStepUpReceiptResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberStepUpReceiptResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return MemberStepUpReceiptResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as MemberStepUpReceipt,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $MemberStepUpReceiptResponseCopyWith on MemberStepUpReceiptResponse {
  /// Returns a callable class that can be used as follows: `instanceOfMemberStepUpReceiptResponse.copyWith(...)` or like so:`instanceOfMemberStepUpReceiptResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberStepUpReceiptResponseCWProxy get copyWith =>
      _$MemberStepUpReceiptResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberStepUpReceiptResponse _$MemberStepUpReceiptResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MemberStepUpReceiptResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = MemberStepUpReceiptResponse(
    data: $checkedConvert(
      'data',
      (v) => MemberStepUpReceipt.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$MemberStepUpReceiptResponseToJson(
  MemberStepUpReceiptResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
