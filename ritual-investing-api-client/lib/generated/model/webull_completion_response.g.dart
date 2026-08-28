// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webull_completion_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WebullCompletionResponseCWProxy {
  WebullCompletionResponse data(WebullCompletion data);

  WebullCompletionResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullCompletionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullCompletionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullCompletionResponse call({
    WebullCompletion data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWebullCompletionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWebullCompletionResponse.copyWith.fieldName(...)`
class _$WebullCompletionResponseCWProxyImpl
    implements _$WebullCompletionResponseCWProxy {
  const _$WebullCompletionResponseCWProxyImpl(this._value);

  final WebullCompletionResponse _value;

  @override
  WebullCompletionResponse data(WebullCompletion data) => this(data: data);

  @override
  WebullCompletionResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullCompletionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullCompletionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullCompletionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return WebullCompletionResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WebullCompletion,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $WebullCompletionResponseCopyWith on WebullCompletionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfWebullCompletionResponse.copyWith(...)` or like so:`instanceOfWebullCompletionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WebullCompletionResponseCWProxy get copyWith =>
      _$WebullCompletionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebullCompletionResponse _$WebullCompletionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WebullCompletionResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = WebullCompletionResponse(
    data: $checkedConvert(
      'data',
      (v) => WebullCompletion.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$WebullCompletionResponseToJson(
  WebullCompletionResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
