// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_privacy_requests200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminPrivacyRequests200ResponseCWProxy {
  ListAdminPrivacyRequests200Response data(
    List<ListAdminPrivacyRequests200ResponseDataInner> data,
  );

  ListAdminPrivacyRequests200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminPrivacyRequests200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminPrivacyRequests200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminPrivacyRequests200Response call({
    List<ListAdminPrivacyRequests200ResponseDataInner> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminPrivacyRequests200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminPrivacyRequests200Response.copyWith.fieldName(...)`
class _$ListAdminPrivacyRequests200ResponseCWProxyImpl
    implements _$ListAdminPrivacyRequests200ResponseCWProxy {
  const _$ListAdminPrivacyRequests200ResponseCWProxyImpl(this._value);

  final ListAdminPrivacyRequests200Response _value;

  @override
  ListAdminPrivacyRequests200Response data(
    List<ListAdminPrivacyRequests200ResponseDataInner> data,
  ) => this(data: data);

  @override
  ListAdminPrivacyRequests200Response meta(CollectionMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminPrivacyRequests200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminPrivacyRequests200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminPrivacyRequests200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListAdminPrivacyRequests200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<ListAdminPrivacyRequests200ResponseDataInner>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListAdminPrivacyRequests200ResponseCopyWith
    on ListAdminPrivacyRequests200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminPrivacyRequests200Response.copyWith(...)` or like so:`instanceOfListAdminPrivacyRequests200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminPrivacyRequests200ResponseCWProxy get copyWith =>
      _$ListAdminPrivacyRequests200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminPrivacyRequests200Response
_$ListAdminPrivacyRequests200ResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ListAdminPrivacyRequests200Response', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = ListAdminPrivacyRequests200Response(
        data: $checkedConvert(
          'data',
          (v) => (v as List<dynamic>)
              .map(
                (e) => ListAdminPrivacyRequests200ResponseDataInner.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList(),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ListAdminPrivacyRequests200ResponseToJson(
  ListAdminPrivacyRequests200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
