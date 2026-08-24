//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/demo_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'public_coven_teaser.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PublicCovenTeaser {
  /// Returns a new [PublicCovenTeaser] instance.
  PublicCovenTeaser({
    required this.category,

    required this.company,

    required this.demo,

    required this.slug,

    required this.teaser,

    required this.verifiedAsOf,
  });

  @JsonKey(
    name: r'category',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PublicCovenTeaserCategoryEnum.unknownDefaultOpenApi,
  )
  final PublicCovenTeaserCategoryEnum category;

  @JsonKey(name: r'company', required: true, includeIfNull: false)
  final String company;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final DemoDisclosure demo;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'teaser', required: true, includeIfNull: false)
  final String teaser;

  @JsonKey(name: r'verified_as_of', required: true, includeIfNull: false)
  final DateTime verifiedAsOf;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicCovenTeaser &&
          other.category == category &&
          other.company == company &&
          other.demo == demo &&
          other.slug == slug &&
          other.teaser == teaser &&
          other.verifiedAsOf == verifiedAsOf;

  @override
  int get hashCode =>
      category.hashCode +
      company.hashCode +
      demo.hashCode +
      slug.hashCode +
      teaser.hashCode +
      verifiedAsOf.hashCode;

  factory PublicCovenTeaser.fromJson(Map<String, dynamic> json) =>
      _$PublicCovenTeaserFromJson(json);

  Map<String, dynamic> toJson() => _$PublicCovenTeaserToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PublicCovenTeaserCategoryEnum {
  @JsonValue(r'founder')
  founder(r'founder'),
  @JsonValue(r'owner')
  owner(r'owner'),
  @JsonValue(r'chief_executive')
  chiefExecutive(r'chief_executive'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PublicCovenTeaserCategoryEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
