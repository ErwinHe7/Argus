//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/grimoire_summary.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'discover_item_one_of2.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DiscoverItemOneOf2 {
  /// Returns a new [DiscoverItemOneOf2] instance.
  DiscoverItemOneOf2({required this.grimoire, required this.kind});

  @JsonKey(name: r'grimoire', required: true, includeIfNull: false)
  final GrimoireSummary grimoire;

  @JsonKey(
    name: r'kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DiscoverItemOneOf2KindEnum.unknownDefaultOpenApi,
  )
  final DiscoverItemOneOf2KindEnum kind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoverItemOneOf2 &&
          other.grimoire == grimoire &&
          other.kind == kind;

  @override
  int get hashCode => grimoire.hashCode + kind.hashCode;

  factory DiscoverItemOneOf2.fromJson(Map<String, dynamic> json) =>
      _$DiscoverItemOneOf2FromJson(json);

  Map<String, dynamic> toJson() => _$DiscoverItemOneOf2ToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum DiscoverItemOneOf2KindEnum {
  @JsonValue(r'grimoire')
  grimoire(r'grimoire'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DiscoverItemOneOf2KindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
