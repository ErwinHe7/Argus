// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webull_account_selection_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WebullAccountSelectionResponseCWProxy {
  WebullAccountSelectionResponse data(WebullAccountSelection data);

  WebullAccountSelectionResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullAccountSelectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullAccountSelectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullAccountSelectionResponse call({
    WebullAccountSelection data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWebullAccountSelectionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWebullAccountSelectionResponse.copyWith.fieldName(...)`
class _$WebullAccountSelectionResponseCWProxyImpl
    implements _$WebullAccountSelectionResponseCWProxy {
  const _$WebullAccountSelectionResponseCWProxyImpl(this._value);

  final WebullAccountSelectionResponse _value;

  @override
  WebullAccountSelectionResponse data(WebullAccountSelection data) =>
      this(data: data);

  @override
  WebullAccountSelectionResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullAccountSelectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullAccountSelectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullAccountSelectionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return WebullAccountSelectionResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WebullAccountSelection,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $WebullAccountSelectionResponseCopyWith
    on WebullAccountSelectionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfWebullAccountSelectionResponse.copyWith(...)` or like so:`instanceOfWebullAccountSelectionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WebullAccountSelectionResponseCWProxy get copyWith =>
      _$WebullAccountSelectionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebullAccountSelectionResponse _$WebullAccountSelectionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WebullAccountSelectionResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = WebullAccountSelectionResponse(
    data: $checkedConvert(
      'data',
      (v) => WebullAccountSelection.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$WebullAccountSelectionResponseToJson(
  WebullAccountSelectionResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
