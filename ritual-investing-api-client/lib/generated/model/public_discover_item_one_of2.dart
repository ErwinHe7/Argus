//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/demo_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'public_discover_item_one_of2.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PublicDiscoverItemOneOf2 {
  /// Returns a new [PublicDiscoverItemOneOf2] instance.
  PublicDiscoverItemOneOf2({
    required this.demo,

    required this.kind,

    required this.slug,

    required this.teaser,

    required this.title,
  });

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final DemoDisclosure demo;

  @JsonKey(
    name: r'kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PublicDiscoverItemOneOf2KindEnum.unknownDefaultOpenApi,
  )
  final PublicDiscoverItemOneOf2KindEnum kind;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'teaser', required: true, includeIfNull: false)
  final String teaser;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicDiscoverItemOneOf2 &&
          other.demo == demo &&
          other.kind == kind &&
          other.slug == slug &&
          other.teaser == teaser &&
          other.title == title;

  @override
  int get hashCode =>
      demo.hashCode +
      kind.hashCode +
      slug.hashCode +
      teaser.hashCode +
      title.hashCode;

  factory PublicDiscoverItemOneOf2.fromJson(Map<String, dynamic> json) =>
      _$PublicDiscoverItemOneOf2FromJson(json);

  Map<String, dynamic> toJson() => _$PublicDiscoverItemOneOf2ToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PublicDiscoverItemOneOf2KindEnum {
  @JsonValue(r'grimoire')
  grimoire(r'grimoire'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PublicDiscoverItemOneOf2KindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
