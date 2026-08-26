// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_evidence_claim201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminEvidenceClaim201ResponseCWProxy {
  CreateAdminEvidenceClaim201Response data(AdminEvidenceClaim data);

  CreateAdminEvidenceClaim201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminEvidenceClaim201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminEvidenceClaim201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminEvidenceClaim201Response call({
    AdminEvidenceClaim data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminEvidenceClaim201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminEvidenceClaim201Response.copyWith.fieldName(...)`
class _$CreateAdminEvidenceClaim201ResponseCWProxyImpl
    implements _$CreateAdminEvidenceClaim201ResponseCWProxy {
  const _$CreateAdminEvidenceClaim201ResponseCWProxyImpl(this._value);

  final CreateAdminEvidenceClaim201Response _value;

  @override
  CreateAdminEvidenceClaim201Response data(AdminEvidenceClaim data) =>
      this(data: data);

  @override
  CreateAdminEvidenceClaim201Response meta(ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminEvidenceClaim201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminEvidenceClaim201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminEvidenceClaim201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminEvidenceClaim201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as AdminEvidenceClaim,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CreateAdminEvidenceClaim201ResponseCopyWith
    on CreateAdminEvidenceClaim201Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminEvidenceClaim201Response.copyWith(...)` or like so:`instanceOfCreateAdminEvidenceClaim201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminEvidenceClaim201ResponseCWProxy get copyWith =>
      _$CreateAdminEvidenceClaim201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminEvidenceClaim201Response
_$CreateAdminEvidenceClaim201ResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CreateAdminEvidenceClaim201Response', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = CreateAdminEvidenceClaim201Response(
        data: $checkedConvert(
          'data',
          (v) => AdminEvidenceClaim.fromJson(v as Map<String, dynamic>),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CreateAdminEvidenceClaim201ResponseToJson(
  CreateAdminEvidenceClaim201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
