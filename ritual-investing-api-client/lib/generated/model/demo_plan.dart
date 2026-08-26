//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/simulation_demo_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'demo_plan.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DemoPlan {
  /// Returns a new [DemoPlan] instance.
  DemoPlan({
    required this.code,

    required this.demo,

    required this.displayName,

    required this.featureCodes,

    required this.priceCopy,
  });

  @JsonKey(
    name: r'code',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DemoPlanCodeEnum.unknownDefaultOpenApi,
  )
  final DemoPlanCodeEnum code;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final SimulationDemoDisclosure demo;

  @JsonKey(name: r'display_name', required: true, includeIfNull: false)
  final String displayName;

  @JsonKey(name: r'feature_codes', required: true, includeIfNull: false)
  final List<String> featureCodes;

  @JsonKey(name: r'price_copy', required: true, includeIfNull: false)
  final String priceCopy;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DemoPlan &&
          other.code == code &&
          other.demo == demo &&
          other.displayName == displayName &&
          other.featureCodes == featureCodes &&
          other.priceCopy == priceCopy;

  @override
  int get hashCode =>
      code.hashCode +
      demo.hashCode +
      displayName.hashCode +
      featureCodes.hashCode +
      priceCopy.hashCode;

  factory DemoPlan.fromJson(Map<String, dynamic> json) =>
      _$DemoPlanFromJson(json);

  Map<String, dynamic> toJson() => _$DemoPlanToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum DemoPlanCodeEnum {
  @JsonValue(r'free')
  free(r'free'),
  @JsonValue(r'premium_demo')
  premiumDemo(r'premium_demo'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DemoPlanCodeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
