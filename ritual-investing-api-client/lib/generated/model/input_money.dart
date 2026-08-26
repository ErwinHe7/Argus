//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'input_money.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class InputMoney {
  /// Returns a new [InputMoney] instance.
  InputMoney({required this.currency, required this.minorUnits});

  @JsonKey(
    name: r'currency',
    required: true,
    includeIfNull: false,
    unknownEnumValue: InputMoneyCurrencyEnum.unknownDefaultOpenApi,
  )
  final InputMoneyCurrencyEnum currency;

  // minimum: 0
  // maximum: 1000000000
  @JsonKey(name: r'minor_units', required: true, includeIfNull: false)
  final int minorUnits;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InputMoney &&
          other.currency == currency &&
          other.minorUnits == minorUnits;

  @override
  int get hashCode => currency.hashCode + minorUnits.hashCode;

  factory InputMoney.fromJson(Map<String, dynamic> json) =>
      _$InputMoneyFromJson(json);

  Map<String, dynamic> toJson() => _$InputMoneyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum InputMoneyCurrencyEnum {
  @JsonValue(r'USD')
  USD(r'USD'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const InputMoneyCurrencyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
