//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of5.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 {
  /// Returns a new [ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5] instance.
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5({
    required this.allowedTokens,

    required this.bodyTemplate,

    required this.riskFooter,

    required this.scriptKey,

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

  @JsonKey(
    name: r'surface',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5SurfaceEnum
            .unknownDefaultOpenApi,
  )
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5SurfaceEnum
  surface;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 &&
          other.allowedTokens == allowedTokens &&
          other.bodyTemplate == bodyTemplate &&
          other.riskFooter == riskFooter &&
          other.scriptKey == scriptKey &&
          other.surface == surface;

  @override
  int get hashCode =>
      allowedTokens.hashCode +
      bodyTemplate.hashCode +
      riskFooter.hashCode +
      scriptKey.hashCode +
      surface.hashCode;

  factory ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5.fromJson(
    Map<String, dynamic> json,
  ) => _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5FromJson(
    json,
  );

  Map<String, dynamic> toJson() =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5ToJson(
        this,
      );

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5SurfaceEnum {
  @JsonValue(r'ritual')
  ritual(r'ritual'),
  @JsonValue(r'intention')
  intention(r'intention'),
  @JsonValue(r'briefing')
  briefing(r'briefing'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5SurfaceEnum(
    this.value,
  );

  final String value;

  @override
  String toString() => value;
}
