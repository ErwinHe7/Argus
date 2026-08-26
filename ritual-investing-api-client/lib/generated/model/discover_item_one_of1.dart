//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/coven_summary.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'discover_item_one_of1.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DiscoverItemOneOf1 {
  /// Returns a new [DiscoverItemOneOf1] instance.
  DiscoverItemOneOf1({required this.coven, required this.kind});

  @JsonKey(name: r'coven', required: true, includeIfNull: false)
  final CovenSummary coven;

  @JsonKey(
    name: r'kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DiscoverItemOneOf1KindEnum.unknownDefaultOpenApi,
  )
  final DiscoverItemOneOf1KindEnum kind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoverItemOneOf1 && other.coven == coven && other.kind == kind;

  @override
  int get hashCode => coven.hashCode + kind.hashCode;

  factory DiscoverItemOneOf1.fromJson(Map<String, dynamic> json) =>
      _$DiscoverItemOneOf1FromJson(json);

  Map<String, dynamic> toJson() => _$DiscoverItemOneOf1ToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum DiscoverItemOneOf1KindEnum {
  @JsonValue(r'coven')
  coven(r'coven'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DiscoverItemOneOf1KindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
