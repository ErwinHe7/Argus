// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_rowan_script_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateRowanScriptRequestCWProxy {
  CreateRowanScriptRequest allowedTokens(List<String> allowedTokens);

  CreateRowanScriptRequest bodyTemplate(String bodyTemplate);

  CreateRowanScriptRequest riskFooter(String riskFooter);

  CreateRowanScriptRequest scriptKey(String scriptKey);

  CreateRowanScriptRequest slug(String slug);

  CreateRowanScriptRequest surface(CreateRowanScriptRequestSurfaceEnum surface);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateRowanScriptRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateRowanScriptRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateRowanScriptRequest call({
    List<String> allowedTokens,
    String bodyTemplate,
    String riskFooter,
    String scriptKey,
    String slug,
    CreateRowanScriptRequestSurfaceEnum surface,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateRowanScriptRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateRowanScriptRequest.copyWith.fieldName(...)`
class _$CreateRowanScriptRequestCWProxyImpl
    implements _$CreateRowanScriptRequestCWProxy {
  const _$CreateRowanScriptRequestCWProxyImpl(this._value);

  final CreateRowanScriptRequest _value;

  @override
  CreateRowanScriptRequest allowedTokens(List<String> allowedTokens) =>
      this(allowedTokens: allowedTokens);

  @override
  CreateRowanScriptRequest bodyTemplate(String bodyTemplate) =>
      this(bodyTemplate: bodyTemplate);

  @override
  CreateRowanScriptRequest riskFooter(String riskFooter) =>
      this(riskFooter: riskFooter);

  @override
  CreateRowanScriptRequest scriptKey(String scriptKey) =>
      this(scriptKey: scriptKey);

  @override
  CreateRowanScriptRequest slug(String slug) => this(slug: slug);

  @override
  CreateRowanScriptRequest surface(
    CreateRowanScriptRequestSurfaceEnum surface,
  ) => this(surface: surface);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateRowanScriptRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateRowanScriptRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateRowanScriptRequest call({
    Object? allowedTokens = const $CopyWithPlaceholder(),
    Object? bodyTemplate = const $CopyWithPlaceholder(),
    Object? riskFooter = const $CopyWithPlaceholder(),
    Object? scriptKey = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? surface = const $CopyWithPlaceholder(),
  }) {
    return CreateRowanScriptRequest(
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
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
      surface: surface == const $CopyWithPlaceholder()
          ? _value.surface
          // ignore: cast_nullable_to_non_nullable
          : surface as CreateRowanScriptRequestSurfaceEnum,
    );
  }
}

extension $CreateRowanScriptRequestCopyWith on CreateRowanScriptRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateRowanScriptRequest.copyWith(...)` or like so:`instanceOfCreateRowanScriptRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateRowanScriptRequestCWProxy get copyWith =>
      _$CreateRowanScriptRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateRowanScriptRequest _$CreateRowanScriptRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CreateRowanScriptRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'allowed_tokens',
        'body_template',
        'risk_footer',
        'script_key',
        'slug',
        'surface',
      ],
    );
    final val = CreateRowanScriptRequest(
      allowedTokens: $checkedConvert(
        'allowed_tokens',
        (v) => (v as List<dynamic>).map((e) => e as String).toList(),
      ),
      bodyTemplate: $checkedConvert('body_template', (v) => v as String),
      riskFooter: $checkedConvert('risk_footer', (v) => v as String),
      scriptKey: $checkedConvert('script_key', (v) => v as String),
      slug: $checkedConvert('slug', (v) => v as String),
      surface: $checkedConvert(
        'surface',
        (v) => $enumDecode(
          _$CreateRowanScriptRequestSurfaceEnumEnumMap,
          v,
          unknownValue:
              CreateRowanScriptRequestSurfaceEnum.unknownDefaultOpenApi,
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

Map<String, dynamic> _$CreateRowanScriptRequestToJson(
  CreateRowanScriptRequest instance,
) => <String, dynamic>{
  'allowed_tokens': instance.allowedTokens,
  'body_template': instance.bodyTemplate,
  'risk_footer': instance.riskFooter,
  'script_key': instance.scriptKey,
  'slug': instance.slug,
  'surface': _$CreateRowanScriptRequestSurfaceEnumEnumMap[instance.surface]!,
};

const _$CreateRowanScriptRequestSurfaceEnumEnumMap = {
  CreateRowanScriptRequestSurfaceEnum.ritual: 'ritual',
  CreateRowanScriptRequestSurfaceEnum.intention: 'intention',
  CreateRowanScriptRequestSurfaceEnum.briefing: 'briefing',
  CreateRowanScriptRequestSurfaceEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
