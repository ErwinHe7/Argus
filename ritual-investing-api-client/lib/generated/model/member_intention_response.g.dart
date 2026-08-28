// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_intention_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberIntentionResponseCWProxy {
  MemberIntentionResponse data(MemberIntention data);

  MemberIntentionResponse meta(GetAccount200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberIntentionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberIntentionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberIntentionResponse call({
    MemberIntention data,
    GetAccount200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberIntentionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberIntentionResponse.copyWith.fieldName(...)`
class _$MemberIntentionResponseCWProxyImpl
    implements _$MemberIntentionResponseCWProxy {
  const _$MemberIntentionResponseCWProxyImpl(this._value);

  final MemberIntentionResponse _value;

  @override
  MemberIntentionResponse data(MemberIntention data) => this(data: data);

  @override
  MemberIntentionResponse meta(GetAccount200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberIntentionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberIntentionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberIntentionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return MemberIntentionResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as MemberIntention,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as GetAccount200ResponseMeta,
    );
  }
}

extension $MemberIntentionResponseCopyWith on MemberIntentionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfMemberIntentionResponse.copyWith(...)` or like so:`instanceOfMemberIntentionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberIntentionResponseCWProxy get copyWith =>
      _$MemberIntentionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberIntentionResponse _$MemberIntentionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MemberIntentionResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = MemberIntentionResponse(
    data: $checkedConvert(
      'data',
      (v) => MemberIntention.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => GetAccount200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$MemberIntentionResponseToJson(
  MemberIntentionResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
