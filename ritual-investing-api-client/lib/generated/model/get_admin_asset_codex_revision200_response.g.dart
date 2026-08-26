// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_admin_asset_codex_revision200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetAdminAssetCodexRevision200ResponseCWProxy {
  GetAdminAssetCodexRevision200Response data(
    ListAdminAssetCodex200ResponseDataInnerRevision data,
  );

  GetAdminAssetCodexRevision200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAdminAssetCodexRevision200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAdminAssetCodexRevision200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAdminAssetCodexRevision200Response call({
    ListAdminAssetCodex200ResponseDataInnerRevision data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetAdminAssetCodexRevision200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetAdminAssetCodexRevision200Response.copyWith.fieldName(...)`
class _$GetAdminAssetCodexRevision200ResponseCWProxyImpl
    implements _$GetAdminAssetCodexRevision200ResponseCWProxy {
  const _$GetAdminAssetCodexRevision200ResponseCWProxyImpl(this._value);

  final GetAdminAssetCodexRevision200Response _value;

  @override
  GetAdminAssetCodexRevision200Response data(
    ListAdminAssetCodex200ResponseDataInnerRevision data,
  ) => this(data: data);

  @override
  GetAdminAssetCodexRevision200Response meta(ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAdminAssetCodexRevision200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAdminAssetCodexRevision200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAdminAssetCodexRevision200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return GetAdminAssetCodexRevision200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as ListAdminAssetCodex200ResponseDataInnerRevision,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $GetAdminAssetCodexRevision200ResponseCopyWith
    on GetAdminAssetCodexRevision200Response {
  /// Returns a callable class that can be used as follows: `instanceOfGetAdminAssetCodexRevision200Response.copyWith(...)` or like so:`instanceOfGetAdminAssetCodexRevision200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetAdminAssetCodexRevision200ResponseCWProxy get copyWith =>
      _$GetAdminAssetCodexRevision200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetAdminAssetCodexRevision200Response
_$GetAdminAssetCodexRevision200ResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GetAdminAssetCodexRevision200Response', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = GetAdminAssetCodexRevision200Response(
        data: $checkedConvert(
          'data',
          (v) => ListAdminAssetCodex200ResponseDataInnerRevision.fromJson(
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

Map<String, dynamic> _$GetAdminAssetCodexRevision200ResponseToJson(
  GetAdminAssetCodexRevision200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
