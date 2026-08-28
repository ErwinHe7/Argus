//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_admin_editorial_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateAdminEditorialRequest {
  /// Returns a new [CreateAdminEditorialRequest] instance.
  CreateAdminEditorialRequest({
    required this.kind,

    required this.payload,

    required this.slug,
  });

  @JsonKey(
    name: r'kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CreateAdminEditorialRequestKindEnum.unknownDefaultOpenApi,
  )
  final CreateAdminEditorialRequestKindEnum kind;

  @JsonKey(name: r'payload', required: true, includeIfNull: false)
  final Map<String, Object?> payload;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateAdminEditorialRequest &&
          other.kind == kind &&
          other.payload == payload &&
          other.slug == slug;

  @override
  int get hashCode => kind.hashCode + payload.hashCode + slug.hashCode;

  factory CreateAdminEditorialRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateAdminEditorialRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateAdminEditorialRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateAdminEditorialRequestKindEnum {
  @JsonValue(r'ritual')
  ritual(r'ritual'),
  @JsonValue(r'asset_codex')
  assetCodex(r'asset_codex'),
  @JsonValue(r'coven')
  coven(r'coven'),
  @JsonValue(r'grimoire')
  grimoire(r'grimoire'),
  @JsonValue(r'circle_template')
  circleTemplate(r'circle_template'),
  @JsonValue(r'rowan')
  rowan(r'rowan'),
  @JsonValue(r'briefing_template')
  briefingTemplate(r'briefing_template'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateAdminEditorialRequestKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
