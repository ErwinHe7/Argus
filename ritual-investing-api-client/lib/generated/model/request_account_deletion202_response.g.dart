// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_account_deletion202_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RequestAccountDeletion202ResponseCWProxy {
  RequestAccountDeletion202Response data(
    RequestAccountDeletion202ResponseData data,
  );

  RequestAccountDeletion202Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestAccountDeletion202Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestAccountDeletion202Response(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestAccountDeletion202Response call({
    RequestAccountDeletion202ResponseData data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRequestAccountDeletion202Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRequestAccountDeletion202Response.copyWith.fieldName(...)`
class _$RequestAccountDeletion202ResponseCWProxyImpl
    implements _$RequestAccountDeletion202ResponseCWProxy {
  const _$RequestAccountDeletion202ResponseCWProxyImpl(this._value);

  final RequestAccountDeletion202Response _value;

  @override
  RequestAccountDeletion202Response data(
    RequestAccountDeletion202ResponseData data,
  ) => this(data: data);

  @override
  RequestAccountDeletion202Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestAccountDeletion202Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestAccountDeletion202Response(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestAccountDeletion202Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return RequestAccountDeletion202Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as RequestAccountDeletion202ResponseData,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $RequestAccountDeletion202ResponseCopyWith
    on RequestAccountDeletion202Response {
  /// Returns a callable class that can be used as follows: `instanceOfRequestAccountDeletion202Response.copyWith(...)` or like so:`instanceOfRequestAccountDeletion202Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RequestAccountDeletion202ResponseCWProxy get copyWith =>
      _$RequestAccountDeletion202ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestAccountDeletion202Response _$RequestAccountDeletion202ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RequestAccountDeletion202Response', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = RequestAccountDeletion202Response(
    data: $checkedConvert(
      'data',
      (v) => RequestAccountDeletion202ResponseData.fromJson(
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

Map<String, dynamic> _$RequestAccountDeletion202ResponseToJson(
  RequestAccountDeletion202Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
