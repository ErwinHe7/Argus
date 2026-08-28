//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'scenario_money.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ScenarioMoney {
  /// Returns a new [ScenarioMoney] instance.
  ScenarioMoney({required this.currency, required this.minorUnits});

  @JsonKey(name: r'currency', required: true, includeIfNull: false)
  final String currency;

  @JsonKey(name: r'minor_units', required: true, includeIfNull: false)
  final String minorUnits;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScenarioMoney &&
          other.currency == currency &&
          other.minorUnits == minorUnits;

  @override
  int get hashCode => currency.hashCode + minorUnits.hashCode;

  factory ScenarioMoney.fromJson(Map<String, dynamic> json) =>
      _$ScenarioMoneyFromJson(json);

  Map<String, dynamic> toJson() => _$ScenarioMoneyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
