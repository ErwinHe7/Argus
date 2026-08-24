//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_rowan_script_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateRowanScriptRequest {
  /// Returns a new [CreateRowanScriptRequest] instance.
  CreateRowanScriptRequest({
    required this.allowedTokens,

    required this.bodyTemplate,

    required this.riskFooter,

    required this.scriptKey,

    required this.slug,

    required this.surface,
  });

  @JsonKey(name: r'allowed_tokens', required: true, includeIfNull: false)
  final List<String> allowedTokens;

  @JsonKey(name: r'body_template', required: true, includeIfNull: false)
  final String bodyTemplate;

  @JsonKey(name: r'risk_footer', required: true, includeIfNull: false)
  final String riskFooter;

  @JsonKey(name: r'script_key', required: true, includeIfNull: false)
  final String scriptKey;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(
    name: r'surface',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CreateRowanScriptRequestSurfaceEnum.unknownDefaultOpenApi,
  )
  final CreateRowanScriptRequestSurfaceEnum surface;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateRowanScriptRequest &&
          other.allowedTokens == allowedTokens &&
          other.bodyTemplate == bodyTemplate &&
          other.riskFooter == riskFooter &&
          other.scriptKey == scriptKey &&
          other.slug == slug &&
          other.surface == surface;

  @override
  int get hashCode =>
      allowedTokens.hashCode +
      bodyTemplate.hashCode +
      riskFooter.hashCode +
      scriptKey.hashCode +
      slug.hashCode +
      surface.hashCode;

  factory CreateRowanScriptRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateRowanScriptRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateRowanScriptRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateRowanScriptRequestSurfaceEnum {
  @JsonValue(r'ritual')
  ritual(r'ritual'),
  @JsonValue(r'intention')
  intention(r'intention'),
  @JsonValue(r'briefing')
  briefing(r'briefing'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateRowanScriptRequestSurfaceEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
