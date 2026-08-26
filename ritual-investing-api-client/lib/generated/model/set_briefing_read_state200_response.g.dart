// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_briefing_read_state200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SetBriefingReadState200ResponseCWProxy {
  SetBriefingReadState200Response data(ListBriefings200ResponseDataInner data);

  SetBriefingReadState200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SetBriefingReadState200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SetBriefingReadState200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  SetBriefingReadState200Response call({
    ListBriefings200ResponseDataInner data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSetBriefingReadState200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSetBriefingReadState200Response.copyWith.fieldName(...)`
class _$SetBriefingReadState200ResponseCWProxyImpl
    implements _$SetBriefingReadState200ResponseCWProxy {
  const _$SetBriefingReadState200ResponseCWProxyImpl(this._value);

  final SetBriefingReadState200Response _value;

  @override
  SetBriefingReadState200Response data(
    ListBriefings200ResponseDataInner data,
  ) => this(data: data);

  @override
  SetBriefingReadState200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SetBriefingReadState200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SetBriefingReadState200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  SetBriefingReadState200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return SetBriefingReadState200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as ListBriefings200ResponseDataInner,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $SetBriefingReadState200ResponseCopyWith
    on SetBriefingReadState200Response {
  /// Returns a callable class that can be used as follows: `instanceOfSetBriefingReadState200Response.copyWith(...)` or like so:`instanceOfSetBriefingReadState200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SetBriefingReadState200ResponseCWProxy get copyWith =>
      _$SetBriefingReadState200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SetBriefingReadState200Response _$SetBriefingReadState200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SetBriefingReadState200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = SetBriefingReadState200Response(
    data: $checkedConvert(
      'data',
      (v) =>
          ListBriefings200ResponseDataInner.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$SetBriefingReadState200ResponseToJson(
  SetBriefingReadState200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
