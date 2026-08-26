// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of6.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6CWProxy {
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 briefingType(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6BriefingTypeEnum
    briefingType,
  );

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 sections(
    List<
      ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
    >
    sections,
  );

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 templateKey(
    String templateKey,
  );

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 title(
    String title,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 call({
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6BriefingTypeEnum
    briefingType,
    List<
      ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
    >
    sections,
    String templateKey,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6.copyWith.fieldName(...)`
class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6CWProxyImpl
    implements
        _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6CWProxy {
  const _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6CWProxyImpl(
    this._value,
  );

  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 _value;

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 briefingType(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6BriefingTypeEnum
    briefingType,
  ) => this(briefingType: briefingType);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 sections(
    List<
      ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
    >
    sections,
  ) => this(sections: sections);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 templateKey(
    String templateKey,
  ) => this(templateKey: templateKey);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 title(
    String title,
  ) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 call({
    Object? briefingType = const $CopyWithPlaceholder(),
    Object? sections = const $CopyWithPlaceholder(),
    Object? templateKey = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6(
      briefingType: briefingType == const $CopyWithPlaceholder()
          ? _value.briefingType
          // ignore: cast_nullable_to_non_nullable
          : briefingType
                as ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6BriefingTypeEnum,
      sections: sections == const $CopyWithPlaceholder()
          ? _value.sections
          // ignore: cast_nullable_to_non_nullable
          : sections
                as List<
                  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
                >,
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

extension $ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6CopyWith
    on ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6.copyWith(...)` or like so:`instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6CWProxy
  get copyWith =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6CWProxyImpl(
        this,
      );
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6FromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'briefing_type',
        'sections',
        'template_key',
        'title',
      ],
    );
    final val = ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6(
      briefingType: $checkedConvert(
        'briefing_type',
        (v) => $enumDecode(
          _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6BriefingTypeEnumEnumMap,
          v,
          unknownValue:
              ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6BriefingTypeEnum
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

Map<String, dynamic>
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6ToJson(
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 instance,
) => <String, dynamic>{
  'briefing_type':
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6BriefingTypeEnumEnumMap[instance
          .briefingType]!,
  'sections': instance.sections.map((e) => e.toJson()).toList(),
  'template_key': instance.templateKey,
  'title': instance.title,
};

const _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6BriefingTypeEnumEnumMap = {
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6BriefingTypeEnum
          .daily:
      'daily',
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6BriefingTypeEnum
          .weekly:
      'weekly',
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6BriefingTypeEnum
          .moonCycle:
      'moon_cycle',
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6BriefingTypeEnum
          .unknownDefaultOpenApi:
      'unknown_default_open_api',
};
