// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_editorial_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminEditorialRequestCWProxy {
  CreateAdminEditorialRequest kind(CreateAdminEditorialRequestKindEnum kind);

  CreateAdminEditorialRequest payload(Map<String, Object?> payload);

  CreateAdminEditorialRequest slug(String slug);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminEditorialRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminEditorialRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminEditorialRequest call({
    CreateAdminEditorialRequestKindEnum kind,
    Map<String, Object?> payload,
    String slug,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminEditorialRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminEditorialRequest.copyWith.fieldName(...)`
class _$CreateAdminEditorialRequestCWProxyImpl
    implements _$CreateAdminEditorialRequestCWProxy {
  const _$CreateAdminEditorialRequestCWProxyImpl(this._value);

  final CreateAdminEditorialRequest _value;

  @override
  CreateAdminEditorialRequest kind(CreateAdminEditorialRequestKindEnum kind) =>
      this(kind: kind);

  @override
  CreateAdminEditorialRequest payload(Map<String, Object?> payload) =>
      this(payload: payload);

  @override
  CreateAdminEditorialRequest slug(String slug) => this(slug: slug);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminEditorialRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminEditorialRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminEditorialRequest call({
    Object? kind = const $CopyWithPlaceholder(),
    Object? payload = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminEditorialRequest(
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as CreateAdminEditorialRequestKindEnum,
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload as Map<String, Object?>,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
    );
  }
}

extension $CreateAdminEditorialRequestCopyWith on CreateAdminEditorialRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminEditorialRequest.copyWith(...)` or like so:`instanceOfCreateAdminEditorialRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminEditorialRequestCWProxy get copyWith =>
      _$CreateAdminEditorialRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminEditorialRequest _$CreateAdminEditorialRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateAdminEditorialRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['kind', 'payload', 'slug']);
  final val = CreateAdminEditorialRequest(
    kind: $checkedConvert(
      'kind',
      (v) => $enumDecode(
        _$CreateAdminEditorialRequestKindEnumEnumMap,
        v,
        unknownValue: CreateAdminEditorialRequestKindEnum.unknownDefaultOpenApi,
      ),
    ),
    payload: $checkedConvert('payload', (v) => v as Map<String, dynamic>),
    slug: $checkedConvert('slug', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$CreateAdminEditorialRequestToJson(
  CreateAdminEditorialRequest instance,
) => <String, dynamic>{
  'kind': _$CreateAdminEditorialRequestKindEnumEnumMap[instance.kind]!,
  'payload': instance.payload,
  'slug': instance.slug,
};

const _$CreateAdminEditorialRequestKindEnumEnumMap = {
  CreateAdminEditorialRequestKindEnum.ritual: 'ritual',
  CreateAdminEditorialRequestKindEnum.assetCodex: 'asset_codex',
  CreateAdminEditorialRequestKindEnum.coven: 'coven',
  CreateAdminEditorialRequestKindEnum.grimoire: 'grimoire',
  CreateAdminEditorialRequestKindEnum.circleTemplate: 'circle_template',
  CreateAdminEditorialRequestKindEnum.rowan: 'rowan',
  CreateAdminEditorialRequestKindEnum.briefingTemplate: 'briefing_template',
  CreateAdminEditorialRequestKindEnum.starpathLesson: 'starpath_lesson',
  CreateAdminEditorialRequestKindEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
