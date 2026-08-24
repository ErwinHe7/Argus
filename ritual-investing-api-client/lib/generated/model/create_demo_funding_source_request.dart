//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_demo_funding_source_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateDemoFundingSourceRequest {
  /// Returns a new [CreateDemoFundingSourceRequest] instance.
  CreateDemoFundingSourceRequest({required this.fixtureKey});

  @JsonKey(
    name: r'fixture_key',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CreateDemoFundingSourceRequestFixtureKeyEnum.unknownDefaultOpenApi,
  )
  final CreateDemoFundingSourceRequestFixtureKeyEnum fixtureKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateDemoFundingSourceRequest && other.fixtureKey == fixtureKey;

  @override
  int get hashCode => fixtureKey.hashCode;

  factory CreateDemoFundingSourceRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateDemoFundingSourceRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateDemoFundingSourceRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateDemoFundingSourceRequestFixtureKeyEnum {
  @JsonValue(r'moon_reserve')
  moonReserve(r'moon_reserve'),
  @JsonValue(r'constellation_savings')
  constellationSavings(r'constellation_savings'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateDemoFundingSourceRequestFixtureKeyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
