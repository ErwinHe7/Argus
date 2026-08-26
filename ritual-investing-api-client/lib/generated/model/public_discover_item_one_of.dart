//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/demo_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'public_discover_item_one_of.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PublicDiscoverItemOneOf {
  /// Returns a new [PublicDiscoverItemOneOf] instance.
  PublicDiscoverItemOneOf({
    required this.demo,

    required this.kind,

    required this.slug,

    required this.symbol,

    required this.teaser,

    required this.title,
  });

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final DemoDisclosure demo;

  @JsonKey(
    name: r'kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PublicDiscoverItemOneOfKindEnum.unknownDefaultOpenApi,
  )
  final PublicDiscoverItemOneOfKindEnum kind;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'symbol', required: true, includeIfNull: false)
  final String symbol;

  @JsonKey(name: r'teaser', required: true, includeIfNull: false)
  final String teaser;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicDiscoverItemOneOf &&
          other.demo == demo &&
          other.kind == kind &&
          other.slug == slug &&
          other.symbol == symbol &&
          other.teaser == teaser &&
          other.title == title;

  @override
  int get hashCode =>
      demo.hashCode +
      kind.hashCode +
      slug.hashCode +
      symbol.hashCode +
      teaser.hashCode +
      title.hashCode;

  factory PublicDiscoverItemOneOf.fromJson(Map<String, dynamic> json) =>
      _$PublicDiscoverItemOneOfFromJson(json);

  Map<String, dynamic> toJson() => _$PublicDiscoverItemOneOfToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PublicDiscoverItemOneOfKindEnum {
  @JsonValue(r'asset')
  asset(r'asset'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PublicDiscoverItemOneOfKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
