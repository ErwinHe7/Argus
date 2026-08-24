// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_privacy_export202_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RequestPrivacyExport202ResponseCWProxy {
  RequestPrivacyExport202Response data(
    RequestPrivacyExport202ResponseData data,
  );

  RequestPrivacyExport202Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestPrivacyExport202Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestPrivacyExport202Response(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestPrivacyExport202Response call({
    RequestPrivacyExport202ResponseData data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRequestPrivacyExport202Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRequestPrivacyExport202Response.copyWith.fieldName(...)`
class _$RequestPrivacyExport202ResponseCWProxyImpl
    implements _$RequestPrivacyExport202ResponseCWProxy {
  const _$RequestPrivacyExport202ResponseCWProxyImpl(this._value);

  final RequestPrivacyExport202Response _value;

  @override
  RequestPrivacyExport202Response data(
    RequestPrivacyExport202ResponseData data,
  ) => this(data: data);

  @override
  RequestPrivacyExport202Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestPrivacyExport202Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestPrivacyExport202Response(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestPrivacyExport202Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return RequestPrivacyExport202Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as RequestPrivacyExport202ResponseData,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $RequestPrivacyExport202ResponseCopyWith
    on RequestPrivacyExport202Response {
  /// Returns a callable class that can be used as follows: `instanceOfRequestPrivacyExport202Response.copyWith(...)` or like so:`instanceOfRequestPrivacyExport202Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RequestPrivacyExport202ResponseCWProxy get copyWith =>
      _$RequestPrivacyExport202ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestPrivacyExport202Response _$RequestPrivacyExport202ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RequestPrivacyExport202Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = RequestPrivacyExport202Response(
    data: $checkedConvert(
      'data',
      (v) => RequestPrivacyExport202ResponseData.fromJson(
        v as Map<String, dynamic>,
      ),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$RequestPrivacyExport202ResponseToJson(
  RequestPrivacyExport202Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
