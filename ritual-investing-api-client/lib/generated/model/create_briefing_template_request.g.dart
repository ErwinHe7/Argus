// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_briefing_template_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateBriefingTemplateRequestCWProxy {
  CreateBriefingTemplateRequest briefingType(
    CreateBriefingTemplateRequestBriefingTypeEnum briefingType,
  );

  CreateBriefingTemplateRequest sections(
    List<
      ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
    >
    sections,
  );

  CreateBriefingTemplateRequest slug(String slug);

  CreateBriefingTemplateRequest templateKey(String templateKey);

  CreateBriefingTemplateRequest title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateBriefingTemplateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateBriefingTemplateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateBriefingTemplateRequest call({
    CreateBriefingTemplateRequestBriefingTypeEnum briefingType,
    List<
      ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
    >
    sections,
    String slug,
    String templateKey,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateBriefingTemplateRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateBriefingTemplateRequest.copyWith.fieldName(...)`
class _$CreateBriefingTemplateRequestCWProxyImpl
    implements _$CreateBriefingTemplateRequestCWProxy {
  const _$CreateBriefingTemplateRequestCWProxyImpl(this._value);

  final CreateBriefingTemplateRequest _value;

  @override
  CreateBriefingTemplateRequest briefingType(
    CreateBriefingTemplateRequestBriefingTypeEnum briefingType,
  ) => this(briefingType: briefingType);

  @override
  CreateBriefingTemplateRequest sections(
    List<
      ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
    >
    sections,
  ) => this(sections: sections);

  @override
  CreateBriefingTemplateRequest slug(String slug) => this(slug: slug);

  @override
  CreateBriefingTemplateRequest templateKey(String templateKey) =>
      this(templateKey: templateKey);

  @override
  CreateBriefingTemplateRequest title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateBriefingTemplateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateBriefingTemplateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateBriefingTemplateRequest call({
    Object? briefingType = const $CopyWithPlaceholder(),
    Object? sections = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? templateKey = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return CreateBriefingTemplateRequest(
      briefingType: briefingType == const $CopyWithPlaceholder()
          ? _value.briefingType
          // ignore: cast_nullable_to_non_nullable
          : briefingType as CreateBriefingTemplateRequestBriefingTypeEnum,
      sections: sections == const $CopyWithPlaceholder()
          ? _value.sections
          // ignore: cast_nullable_to_non_nullable
          : sections
                as List<
                  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
                >,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
      templateKey: templateKey == const $CopyWithPlaceholder()
          ? _value.templateKey
          // ignore: cast_nullable_to_non_nullable
          : templateKey as String,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
    );
  }
}

extension $CreateBriefingTemplateRequestCopyWith
    on CreateBriefingTemplateRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateBriefingTemplateRequest.copyWith(...)` or like so:`instanceOfCreateBriefingTemplateRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateBriefingTemplateRequestCWProxy get copyWith =>
      _$CreateBriefingTemplateRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateBriefingTemplateRequest _$CreateBriefingTemplateRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CreateBriefingTemplateRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'briefing_type',
        'sections',
        'slug',
        'template_key',
        'title',
      ],
    );
    final val = CreateBriefingTemplateRequest(
      briefingType: $checkedConvert(
        'briefing_type',
        (v) => $enumDecode(
          _$CreateBriefingTemplateRequestBriefingTypeEnumEnumMap,
          v,
          unknownValue: CreateBriefingTemplateRequestBriefingTypeEnum
              .unknownDefaultOpenApi,
        ),
      ),
      sections: $checkedConvert(
        'sections',
        (v) => (v as List<dynamic>)
            .map(
              (e) =>
                  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner.fromJson(
                    e as Map<String, dynamic>,
                  ),
            )
            .toList(),
      ),
      slug: $checkedConvert('slug', (v) => v as String),
      templateKey: $checkedConvert('template_key', (v) => v as String),
      title: $checkedConvert('title', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'briefingType': 'briefing_type',
    'templateKey': 'template_key',
  },
);

Map<String, dynamic> _$CreateBriefingTemplateRequestToJson(
  CreateBriefingTemplateRequest instance,
) => <String, dynamic>{
  'briefing_type':
      _$CreateBriefingTemplateRequestBriefingTypeEnumEnumMap[instance
          .briefingType]!,
  'sections': instance.sections.map((e) => e.toJson()).toList(),
  'slug': instance.slug,
  'template_key': instance.templateKey,
  'title': instance.title,
};

const _$CreateBriefingTemplateRequestBriefingTypeEnumEnumMap = {
  CreateBriefingTemplateRequestBriefingTypeEnum.daily: 'daily',
  CreateBriefingTemplateRequestBriefingTypeEnum.weekly: 'weekly',
  CreateBriefingTemplateRequestBriefingTypeEnum.moonCycle: 'moon_cycle',
  CreateBriefingTemplateRequestBriefingTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
