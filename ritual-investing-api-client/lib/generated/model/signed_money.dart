//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'signed_money.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SignedMoney {
  /// Returns a new [SignedMoney] instance.
  SignedMoney({required this.currency, required this.minorUnits});

  @JsonKey(
    name: r'currency',
    required: true,
    includeIfNull: false,
    unknownEnumValue: SignedMoneyCurrencyEnum.unknownDefaultOpenApi,
  )
  final SignedMoneyCurrencyEnum currency;

  // minimum: -9007199254740991
  // maximum: 9007199254740991
  @JsonKey(name: r'minor_units', required: true, includeIfNull: false)
  final int minorUnits;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignedMoney &&
          other.currency == currency &&
          other.minorUnits == minorUnits;

  @override
  int get hashCode => currency.hashCode + minorUnits.hashCode;

  factory SignedMoney.fromJson(Map<String, dynamic> json) =>
      _$SignedMoneyFromJson(json);

  Map<String, dynamic> toJson() => _$SignedMoneyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum SignedMoneyCurrencyEnum {
  @JsonValue(r'USD')
  USD(r'USD'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SignedMoneyCurrencyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
