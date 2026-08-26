//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/circle_template_summary.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'discover_item_one_of3.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DiscoverItemOneOf3 {
  /// Returns a new [DiscoverItemOneOf3] instance.
  DiscoverItemOneOf3({required this.circleTemplate, required this.kind});

  @JsonKey(name: r'circle_template', required: true, includeIfNull: false)
  final CircleTemplateSummary circleTemplate;

  @JsonKey(
    name: r'kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DiscoverItemOneOf3KindEnum.unknownDefaultOpenApi,
  )
  final DiscoverItemOneOf3KindEnum kind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoverItemOneOf3 &&
          other.circleTemplate == circleTemplate &&
          other.kind == kind;

  @override
  int get hashCode => circleTemplate.hashCode + kind.hashCode;

  factory DiscoverItemOneOf3.fromJson(Map<String, dynamic> json) =>
      _$DiscoverItemOneOf3FromJson(json);

  Map<String, dynamic> toJson() => _$DiscoverItemOneOf3ToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum DiscoverItemOneOf3KindEnum {
  @JsonValue(r'circle_template')
  circleTemplate(r'circle_template'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DiscoverItemOneOf3KindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
