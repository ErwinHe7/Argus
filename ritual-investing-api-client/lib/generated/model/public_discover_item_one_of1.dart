//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/demo_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'public_discover_item_one_of1.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PublicDiscoverItemOneOf1 {
  /// Returns a new [PublicDiscoverItemOneOf1] instance.
  PublicDiscoverItemOneOf1({
    required this.category,

    required this.demo,

    required this.kind,

    required this.slug,

    required this.teaser,

    required this.title,

    required this.verifiedAsOf,
  });

  @JsonKey(
    name: r'category',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        PublicDiscoverItemOneOf1CategoryEnum.unknownDefaultOpenApi,
  )
  final PublicDiscoverItemOneOf1CategoryEnum category;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final DemoDisclosure demo;

  @JsonKey(
    name: r'kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PublicDiscoverItemOneOf1KindEnum.unknownDefaultOpenApi,
  )
  final PublicDiscoverItemOneOf1KindEnum kind;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'teaser', required: true, includeIfNull: false)
  final String teaser;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @JsonKey(name: r'verified_as_of', required: true, includeIfNull: false)
  final DateTime verifiedAsOf;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicDiscoverItemOneOf1 &&
          other.category == category &&
          other.demo == demo &&
          other.kind == kind &&
          other.slug == slug &&
          other.teaser == teaser &&
          other.title == title &&
          other.verifiedAsOf == verifiedAsOf;

  @override
  int get hashCode =>
      category.hashCode +
      demo.hashCode +
      kind.hashCode +
      slug.hashCode +
      teaser.hashCode +
      title.hashCode +
      verifiedAsOf.hashCode;

  factory PublicDiscoverItemOneOf1.fromJson(Map<String, dynamic> json) =>
      _$PublicDiscoverItemOneOf1FromJson(json);

  Map<String, dynamic> toJson() => _$PublicDiscoverItemOneOf1ToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PublicDiscoverItemOneOf1CategoryEnum {
  @JsonValue(r'founder')
  founder(r'founder'),
  @JsonValue(r'owner')
  owner(r'owner'),
  @JsonValue(r'chief_executive')
  chiefExecutive(r'chief_executive'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PublicDiscoverItemOneOf1CategoryEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum PublicDiscoverItemOneOf1KindEnum {
  @JsonValue(r'coven')
  coven(r'coven'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PublicDiscoverItemOneOf1KindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
