//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/demo_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'public_discover_item_one_of3.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PublicDiscoverItemOneOf3 {
  /// Returns a new [PublicDiscoverItemOneOf3] instance.
  PublicDiscoverItemOneOf3({
    required this.creatorLabel,

    required this.demo,

    required this.isFictional,

    required this.kind,

    required this.slug,

    required this.teaser,

    required this.title,
  });

  @JsonKey(name: r'creator_label', required: true, includeIfNull: false)
  final String creatorLabel;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final DemoDisclosure demo;

  @JsonKey(name: r'is_fictional', required: true, includeIfNull: false)
  final bool isFictional;

  @JsonKey(
    name: r'kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PublicDiscoverItemOneOf3KindEnum.unknownDefaultOpenApi,
  )
  final PublicDiscoverItemOneOf3KindEnum kind;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'teaser', required: true, includeIfNull: false)
  final String teaser;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicDiscoverItemOneOf3 &&
          other.creatorLabel == creatorLabel &&
          other.demo == demo &&
          other.isFictional == isFictional &&
          other.kind == kind &&
          other.slug == slug &&
          other.teaser == teaser &&
          other.title == title;

  @override
  int get hashCode =>
      creatorLabel.hashCode +
      demo.hashCode +
      isFictional.hashCode +
      kind.hashCode +
      slug.hashCode +
      teaser.hashCode +
      title.hashCode;

  factory PublicDiscoverItemOneOf3.fromJson(Map<String, dynamic> json) =>
      _$PublicDiscoverItemOneOf3FromJson(json);

  Map<String, dynamic> toJson() => _$PublicDiscoverItemOneOf3ToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PublicDiscoverItemOneOf3KindEnum {
  @JsonValue(r'circle_template')
  circleTemplate(r'circle_template'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PublicDiscoverItemOneOf3KindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
