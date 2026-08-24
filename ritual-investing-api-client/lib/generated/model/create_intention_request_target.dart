//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_intention_request_target.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateIntentionRequestTarget {
  /// Returns a new [CreateIntentionRequestTarget] instance.
  CreateIntentionRequestTarget({
    required this.currency,

    required this.minorUnits,
  });

  @JsonKey(
    name: r'currency',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CreateIntentionRequestTargetCurrencyEnum.unknownDefaultOpenApi,
  )
  final CreateIntentionRequestTargetCurrencyEnum currency;

  // minimum: 0
  // maximum: 1000000000
  @JsonKey(name: r'minor_units', required: true, includeIfNull: false)
  final int minorUnits;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateIntentionRequestTarget &&
          other.currency == currency &&
          other.minorUnits == minorUnits;

  @override
  int get hashCode => currency.hashCode + minorUnits.hashCode;

  factory CreateIntentionRequestTarget.fromJson(Map<String, dynamic> json) =>
      _$CreateIntentionRequestTargetFromJson(json);

  Map<String, dynamic> toJson() => _$CreateIntentionRequestTargetToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateIntentionRequestTargetCurrencyEnum {
  @JsonValue(r'USD')
  USD(r'USD'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateIntentionRequestTargetCurrencyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
