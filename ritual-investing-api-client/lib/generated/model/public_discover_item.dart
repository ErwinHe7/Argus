//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/public_discover_item_one_of3.dart';
import 'package:ritual_investing_api_client/generated/model/public_discover_item_one_of.dart';
import 'package:ritual_investing_api_client/generated/model/demo_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/public_discover_item_one_of2.dart';
import 'package:ritual_investing_api_client/generated/model/public_discover_item_one_of1.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'public_discover_item.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PublicDiscoverItem {
  /// Returns a new [PublicDiscoverItem] instance.
  PublicDiscoverItem({
    required this.demo,

    required this.kind,

    required this.slug,

    required this.symbol,

    required this.teaser,

    required this.title,

    required this.category,

    required this.verifiedAsOf,

    required this.creatorLabel,

    required this.isFictional,
  });

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final DemoDisclosure demo;

  @JsonKey(
    name: r'kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PublicDiscoverItemKindEnum.unknownDefaultOpenApi,
  )
  final PublicDiscoverItemKindEnum kind;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'symbol', required: true, includeIfNull: false)
  final String symbol;

  @JsonKey(name: r'teaser', required: true, includeIfNull: false)
  final String teaser;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @JsonKey(
    name: r'category',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PublicDiscoverItemCategoryEnum.unknownDefaultOpenApi,
  )
  final PublicDiscoverItemCategoryEnum category;

  @JsonKey(name: r'verified_as_of', required: true, includeIfNull: false)
  final DateTime verifiedAsOf;

  @JsonKey(name: r'creator_label', required: true, includeIfNull: false)
  final String creatorLabel;

  @JsonKey(name: r'is_fictional', required: true, includeIfNull: false)
  final bool isFictional;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicDiscoverItem &&
          other.demo == demo &&
          other.kind == kind &&
          other.slug == slug &&
          other.symbol == symbol &&
          other.teaser == teaser &&
          other.title == title &&
          other.category == category &&
          other.verifiedAsOf == verifiedAsOf &&
          other.creatorLabel == creatorLabel &&
          other.isFictional == isFictional;

  @override
  int get hashCode =>
      demo.hashCode +
      kind.hashCode +
      slug.hashCode +
      symbol.hashCode +
      teaser.hashCode +
      title.hashCode +
      category.hashCode +
      verifiedAsOf.hashCode +
      creatorLabel.hashCode +
      isFictional.hashCode;

  factory PublicDiscoverItem.fromJson(Map<String, dynamic> json) =>
      _$PublicDiscoverItemFromJson(json);

  Map<String, dynamic> toJson() => _$PublicDiscoverItemToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PublicDiscoverItemKindEnum {
  @JsonValue(r'circle_template')
  circleTemplate(r'circle_template'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PublicDiscoverItemKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum PublicDiscoverItemCategoryEnum {
  @JsonValue(r'founder')
  founder(r'founder'),
  @JsonValue(r'owner')
  owner(r'owner'),
  @JsonValue(r'chief_executive')
  chiefExecutive(r'chief_executive'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PublicDiscoverItemCategoryEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
