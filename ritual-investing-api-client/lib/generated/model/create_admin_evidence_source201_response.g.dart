// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_evidence_source201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminEvidenceSource201ResponseCWProxy {
  CreateAdminEvidenceSource201Response data(AdminEvidenceSource data);

  CreateAdminEvidenceSource201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminEvidenceSource201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminEvidenceSource201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminEvidenceSource201Response call({
    AdminEvidenceSource data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminEvidenceSource201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminEvidenceSource201Response.copyWith.fieldName(...)`
class _$CreateAdminEvidenceSource201ResponseCWProxyImpl
    implements _$CreateAdminEvidenceSource201ResponseCWProxy {
  const _$CreateAdminEvidenceSource201ResponseCWProxyImpl(this._value);

  final CreateAdminEvidenceSource201Response _value;

  @override
  CreateAdminEvidenceSource201Response data(AdminEvidenceSource data) =>
      this(data: data);

  @override
  CreateAdminEvidenceSource201Response meta(ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminEvidenceSource201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminEvidenceSource201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminEvidenceSource201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminEvidenceSource201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as AdminEvidenceSource,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CreateAdminEvidenceSource201ResponseCopyWith
    on CreateAdminEvidenceSource201Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminEvidenceSource201Response.copyWith(...)` or like so:`instanceOfCreateAdminEvidenceSource201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminEvidenceSource201ResponseCWProxy get copyWith =>
      _$CreateAdminEvidenceSource201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminEvidenceSource201Response
_$CreateAdminEvidenceSource201ResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CreateAdminEvidenceSource201Response', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = CreateAdminEvidenceSource201Response(
        data: $checkedConvert(
          'data',
          (v) => AdminEvidenceSource.fromJson(v as Map<String, dynamic>),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CreateAdminEvidenceSource201ResponseToJson(
  CreateAdminEvidenceSource201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
