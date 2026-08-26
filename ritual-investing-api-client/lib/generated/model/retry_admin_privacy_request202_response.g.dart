// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'retry_admin_privacy_request202_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RetryAdminPrivacyRequest202ResponseCWProxy {
  RetryAdminPrivacyRequest202Response data(
    RetryAdminPrivacyRequest202ResponseData data,
  );

  RetryAdminPrivacyRequest202Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RetryAdminPrivacyRequest202Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RetryAdminPrivacyRequest202Response(...).copyWith(id: 12, name: "My name")
  /// ````
  RetryAdminPrivacyRequest202Response call({
    RetryAdminPrivacyRequest202ResponseData data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRetryAdminPrivacyRequest202Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRetryAdminPrivacyRequest202Response.copyWith.fieldName(...)`
class _$RetryAdminPrivacyRequest202ResponseCWProxyImpl
    implements _$RetryAdminPrivacyRequest202ResponseCWProxy {
  const _$RetryAdminPrivacyRequest202ResponseCWProxyImpl(this._value);

  final RetryAdminPrivacyRequest202Response _value;

  @override
  RetryAdminPrivacyRequest202Response data(
    RetryAdminPrivacyRequest202ResponseData data,
  ) => this(data: data);

  @override
  RetryAdminPrivacyRequest202Response meta(ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RetryAdminPrivacyRequest202Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RetryAdminPrivacyRequest202Response(...).copyWith(id: 12, name: "My name")
  /// ````
  RetryAdminPrivacyRequest202Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return RetryAdminPrivacyRequest202Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as RetryAdminPrivacyRequest202ResponseData,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $RetryAdminPrivacyRequest202ResponseCopyWith
    on RetryAdminPrivacyRequest202Response {
  /// Returns a callable class that can be used as follows: `instanceOfRetryAdminPrivacyRequest202Response.copyWith(...)` or like so:`instanceOfRetryAdminPrivacyRequest202Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RetryAdminPrivacyRequest202ResponseCWProxy get copyWith =>
      _$RetryAdminPrivacyRequest202ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RetryAdminPrivacyRequest202Response
_$RetryAdminPrivacyRequest202ResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RetryAdminPrivacyRequest202Response', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = RetryAdminPrivacyRequest202Response(
        data: $checkedConvert(
          'data',
          (v) => RetryAdminPrivacyRequest202ResponseData.fromJson(
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

Map<String, dynamic> _$RetryAdminPrivacyRequest202ResponseToJson(
  RetryAdminPrivacyRequest202Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
