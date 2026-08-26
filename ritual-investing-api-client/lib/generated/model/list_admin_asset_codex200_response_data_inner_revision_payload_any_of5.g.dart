// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of5.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5CWProxy {
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 allowedTokens(
    List<String> allowedTokens,
  );

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 bodyTemplate(
    String bodyTemplate,
  );

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 riskFooter(
    String riskFooter,
  );

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 scriptKey(
    String scriptKey,
  );

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 surface(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5SurfaceEnum
    surface,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 call({
    List<String> allowedTokens,
    String bodyTemplate,
    String riskFooter,
    String scriptKey,
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5SurfaceEnum
    surface,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5.copyWith.fieldName(...)`
class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5CWProxyImpl
    implements
        _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5CWProxy {
  const _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5CWProxyImpl(
    this._value,
  );

  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 _value;

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 allowedTokens(
    List<String> allowedTokens,
  ) => this(allowedTokens: allowedTokens);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 bodyTemplate(
    String bodyTemplate,
  ) => this(bodyTemplate: bodyTemplate);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 riskFooter(
    String riskFooter,
  ) => this(riskFooter: riskFooter);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 scriptKey(
    String scriptKey,
  ) => this(scriptKey: scriptKey);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 surface(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5SurfaceEnum
    surface,
  ) => this(surface: surface);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 call({
    Object? allowedTokens = const $CopyWithPlaceholder(),
    Object? bodyTemplate = const $CopyWithPlaceholder(),
    Object? riskFooter = const $CopyWithPlaceholder(),
    Object? scriptKey = const $CopyWithPlaceholder(),
    Object? surface = const $CopyWithPlaceholder(),
  }) {
    return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5(
      allowedTokens: allowedTokens == const $CopyWithPlaceholder()
          ? _value.allowedTokens
          // ignore: cast_nullable_to_non_nullable
          : allowedTokens as List<String>,
      bodyTemplate: bodyTemplate == const $CopyWithPlaceholder()
          ? _value.bodyTemplate
          // ignore: cast_nullable_to_non_nullable
          : bodyTemplate as String,
      riskFooter: riskFooter == const $CopyWithPlaceholder()
          ? _value.riskFooter
          // ignore: cast_nullable_to_non_nullable
          : riskFooter as String,
      scriptKey: scriptKey == const $CopyWithPlaceholder()
          ? _value.scriptKey
          // ignore: cast_nullable_to_non_nullable
          : scriptKey as String,
      surface: surface == const $CopyWithPlaceholder()
          ? _value.surface
          // ignore: cast_nullable_to_non_nullable
          : surface
                as ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5SurfaceEnum,
    );
  }
}

extension $ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5CopyWith
    on ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5.copyWith(...)` or like so:`instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5CWProxy
  get copyWith =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5CWProxyImpl(
        this,
      );
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5FromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'allowed_tokens',
        'body_template',
        'risk_footer',
        'script_key',
        'surface',
      ],
    );
    final val = ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5(
      allowedTokens: $checkedConvert(
        'allowed_tokens',
        (v) => (v as List<dynamic>).map((e) => e as String).toList(),
      ),
      bodyTemplate: $checkedConvert('body_template', (v) => v as String),
      riskFooter: $checkedConvert('risk_footer', (v) => v as String),
      scriptKey: $checkedConvert('script_key', (v) => v as String),
      surface: $checkedConvert(
        'surface',
        (v) => $enumDecode(
          _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5SurfaceEnumEnumMap,
          v,
          unknownValue:
              ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5SurfaceEnum
                  .unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'allowedTokens': 'allowed_tokens',
    'bodyTemplate': 'body_template',
    'riskFooter': 'risk_footer',
    'scriptKey': 'script_key',
  },
);

Map<String, dynamic>
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5ToJson(
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 instance,
) => <String, dynamic>{
  'allowed_tokens': instance.allowedTokens,
  'body_template': instance.bodyTemplate,
  'risk_footer': instance.riskFooter,
  'script_key': instance.scriptKey,
  'surface':
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5SurfaceEnumEnumMap[instance
          .surface]!,
};

const _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5SurfaceEnumEnumMap =
    {
      ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5SurfaceEnum
              .ritual:
          'ritual',
      ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5SurfaceEnum
              .intention:
          'intention',
      ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5SurfaceEnum
              .briefing:
          'briefing',
      ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5SurfaceEnum
              .unknownDefaultOpenApi:
          'unknown_default_open_api',
    };
