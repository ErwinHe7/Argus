// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_intention_page_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberIntentionPageResponseCWProxy {
  MemberIntentionPageResponse data(MemberIntentionPage data);

  MemberIntentionPageResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberIntentionPageResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberIntentionPageResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberIntentionPageResponse call({
    MemberIntentionPage data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberIntentionPageResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberIntentionPageResponse.copyWith.fieldName(...)`
class _$MemberIntentionPageResponseCWProxyImpl
    implements _$MemberIntentionPageResponseCWProxy {
  const _$MemberIntentionPageResponseCWProxyImpl(this._value);

  final MemberIntentionPageResponse _value;

  @override
  MemberIntentionPageResponse data(MemberIntentionPage data) =>
      this(data: data);

  @override
  MemberIntentionPageResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberIntentionPageResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberIntentionPageResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberIntentionPageResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return MemberIntentionPageResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as MemberIntentionPage,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $MemberIntentionPageResponseCopyWith on MemberIntentionPageResponse {
  /// Returns a callable class that can be used as follows: `instanceOfMemberIntentionPageResponse.copyWith(...)` or like so:`instanceOfMemberIntentionPageResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberIntentionPageResponseCWProxy get copyWith =>
      _$MemberIntentionPageResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberIntentionPageResponse _$MemberIntentionPageResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MemberIntentionPageResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = MemberIntentionPageResponse(
    data: $checkedConvert(
      'data',
      (v) => MemberIntentionPage.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$MemberIntentionPageResponseToJson(
  MemberIntentionPageResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
