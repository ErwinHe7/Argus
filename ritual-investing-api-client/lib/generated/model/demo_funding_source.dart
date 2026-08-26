//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/simulation_demo_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'demo_funding_source.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DemoFundingSource {
  /// Returns a new [DemoFundingSource] instance.
  DemoFundingSource({
    required this.demo,

    required this.displayLabel,

    required this.fictionalLast4,

    required this.fixtureKey,

    required this.id,

    required this.status,
  });

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final SimulationDemoDisclosure demo;

  @JsonKey(name: r'display_label', required: true, includeIfNull: false)
  final String displayLabel;

  @JsonKey(name: r'fictional_last4', required: true, includeIfNull: false)
  final String fictionalLast4;

  @JsonKey(
    name: r'fixture_key',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DemoFundingSourceFixtureKeyEnum.unknownDefaultOpenApi,
  )
  final DemoFundingSourceFixtureKeyEnum fixtureKey;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DemoFundingSourceStatusEnum.unknownDefaultOpenApi,
  )
  final DemoFundingSourceStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DemoFundingSource &&
          other.demo == demo &&
          other.displayLabel == displayLabel &&
          other.fictionalLast4 == fictionalLast4 &&
          other.fixtureKey == fixtureKey &&
          other.id == id &&
          other.status == status;

  @override
  int get hashCode =>
      demo.hashCode +
      displayLabel.hashCode +
      fictionalLast4.hashCode +
      fixtureKey.hashCode +
      id.hashCode +
      status.hashCode;

  factory DemoFundingSource.fromJson(Map<String, dynamic> json) =>
      _$DemoFundingSourceFromJson(json);

  Map<String, dynamic> toJson() => _$DemoFundingSourceToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum DemoFundingSourceFixtureKeyEnum {
  @JsonValue(r'moon_reserve')
  moonReserve(r'moon_reserve'),
  @JsonValue(r'constellation_savings')
  constellationSavings(r'constellation_savings'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DemoFundingSourceFixtureKeyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum DemoFundingSourceStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'inactive')
  inactive(r'inactive'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DemoFundingSourceStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
