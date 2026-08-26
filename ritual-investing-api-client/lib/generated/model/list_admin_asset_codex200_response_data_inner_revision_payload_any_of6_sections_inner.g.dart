// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of6_sections_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInnerCWProxy {
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
  body(String body);

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
  heading(String heading);

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
  sectionType(String sectionType);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
  call({String body, String heading, String sectionType});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner.copyWith.fieldName(...)`
class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInnerCWProxyImpl
    implements
        _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInnerCWProxy {
  const _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInnerCWProxyImpl(
    this._value,
  );

  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
  _value;

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
  body(String body) => this(body: body);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
  heading(String heading) => this(heading: heading);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
  sectionType(String sectionType) => this(sectionType: sectionType);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
  call({
    Object? body = const $CopyWithPlaceholder(),
    Object? heading = const $CopyWithPlaceholder(),
    Object? sectionType = const $CopyWithPlaceholder(),
  }) {
    return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner(
      body: body == const $CopyWithPlaceholder()
          ? _value.body
          // ignore: cast_nullable_to_non_nullable
          : body as String,
      heading: heading == const $CopyWithPlaceholder()
          ? _value.heading
          // ignore: cast_nullable_to_non_nullable
          : heading as String,
      sectionType: sectionType == const $CopyWithPlaceholder()
          ? _value.sectionType
          // ignore: cast_nullable_to_non_nullable
          : sectionType as String,
    );
  }
}

extension $ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInnerCopyWith
    on ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner.copyWith(...)` or like so:`instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInnerCWProxy
  get copyWith =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInnerCWProxyImpl(
        this,
      );
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['body', 'heading', 'section_type']);
    final val =
        ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner(
          body: $checkedConvert('body', (v) => v as String),
          heading: $checkedConvert('heading', (v) => v as String),
          sectionType: $checkedConvert('section_type', (v) => v as String),
        );
    return val;
  },
  fieldKeyMap: const {'sectionType': 'section_type'},
);

Map<String, dynamic>
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInnerToJson(
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
  instance,
) => <String, dynamic>{
  'body': instance.body,
  'heading': instance.heading,
  'section_type': instance.sectionType,
};
