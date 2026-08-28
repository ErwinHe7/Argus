// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hypothetical_future_mirror_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HypotheticalFutureMirrorResponseCWProxy {
  HypotheticalFutureMirrorResponse data(HypotheticalFutureMirror data);

  HypotheticalFutureMirrorResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HypotheticalFutureMirrorResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HypotheticalFutureMirrorResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  HypotheticalFutureMirrorResponse call({
    HypotheticalFutureMirror data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfHypotheticalFutureMirrorResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfHypotheticalFutureMirrorResponse.copyWith.fieldName(...)`
class _$HypotheticalFutureMirrorResponseCWProxyImpl
    implements _$HypotheticalFutureMirrorResponseCWProxy {
  const _$HypotheticalFutureMirrorResponseCWProxyImpl(this._value);

  final HypotheticalFutureMirrorResponse _value;

  @override
  HypotheticalFutureMirrorResponse data(HypotheticalFutureMirror data) =>
      this(data: data);

  @override
  HypotheticalFutureMirrorResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HypotheticalFutureMirrorResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HypotheticalFutureMirrorResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  HypotheticalFutureMirrorResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return HypotheticalFutureMirrorResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as HypotheticalFutureMirror,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $HypotheticalFutureMirrorResponseCopyWith
    on HypotheticalFutureMirrorResponse {
  /// Returns a callable class that can be used as follows: `instanceOfHypotheticalFutureMirrorResponse.copyWith(...)` or like so:`instanceOfHypotheticalFutureMirrorResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HypotheticalFutureMirrorResponseCWProxy get copyWith =>
      _$HypotheticalFutureMirrorResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HypotheticalFutureMirrorResponse _$HypotheticalFutureMirrorResponseFromJson(
  Map<String, dynamic> json,
) =>
    $checkedCreate('HypotheticalFutureMirrorResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = HypotheticalFutureMirrorResponse(
        data: $checkedConvert(
          'data',
          (v) => HypotheticalFutureMirror.fromJson(v as Map<String, dynamic>),
        ),
        meta: $checkedConvert(
          'meta',
          (v) =>
              ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$HypotheticalFutureMirrorResponseToJson(
  HypotheticalFutureMirrorResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
