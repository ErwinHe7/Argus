//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'open_api_document.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OpenApiDocument {
  /// Returns a new [OpenApiDocument] instance.
  OpenApiDocument({required this.openapi});

  @JsonKey(
    name: r'openapi',
    required: true,
    includeIfNull: false,
    unknownEnumValue: OpenApiDocumentOpenapiEnum.unknownDefaultOpenApi,
  )
  final OpenApiDocumentOpenapiEnum openapi;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpenApiDocument && other.openapi == openapi;

  @override
  int get hashCode => openapi.hashCode;

  factory OpenApiDocument.fromJson(Map<String, dynamic> json) =>
      _$OpenApiDocumentFromJson(json);

  Map<String, dynamic> toJson() => _$OpenApiDocumentToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum OpenApiDocumentOpenapiEnum {
  @JsonValue(r'3.0.3')
  n3period0Period3(r'3.0.3'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const OpenApiDocumentOpenapiEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
