// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_request_collection_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PrivacyRequestCollectionResponseCWProxy {
  PrivacyRequestCollectionResponse data(List<PrivacyRequest> data);

  PrivacyRequestCollectionResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PrivacyRequestCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PrivacyRequestCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  PrivacyRequestCollectionResponse call({
    List<PrivacyRequest> data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPrivacyRequestCollectionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPrivacyRequestCollectionResponse.copyWith.fieldName(...)`
class _$PrivacyRequestCollectionResponseCWProxyImpl
    implements _$PrivacyRequestCollectionResponseCWProxy {
  const _$PrivacyRequestCollectionResponseCWProxyImpl(this._value);

  final PrivacyRequestCollectionResponse _value;

  @override
  PrivacyRequestCollectionResponse data(List<PrivacyRequest> data) =>
      this(data: data);

  @override
  PrivacyRequestCollectionResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PrivacyRequestCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PrivacyRequestCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  PrivacyRequestCollectionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return PrivacyRequestCollectionResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<PrivacyRequest>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $PrivacyRequestCollectionResponseCopyWith
    on PrivacyRequestCollectionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfPrivacyRequestCollectionResponse.copyWith(...)` or like so:`instanceOfPrivacyRequestCollectionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PrivacyRequestCollectionResponseCWProxy get copyWith =>
      _$PrivacyRequestCollectionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrivacyRequestCollectionResponse _$PrivacyRequestCollectionResponseFromJson(
  Map<String, dynamic> json,
) =>
    $checkedCreate('PrivacyRequestCollectionResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = PrivacyRequestCollectionResponse(
        data: $checkedConvert(
          'data',
          (v) => (v as List<dynamic>)
              .map((e) => PrivacyRequest.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        meta: $checkedConvert(
          'meta',
          (v) =>
              ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$PrivacyRequestCollectionResponseToJson(
  PrivacyRequestCollectionResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
