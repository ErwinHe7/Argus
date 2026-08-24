//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/quantity.dart';
import 'package:ritual_investing_api_client/generated/model/money.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'simulated_order_fill.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SimulatedOrderFill {
  /// Returns a new [SimulatedOrderFill] instance.
  SimulatedOrderFill({
    required this.filledAt,

    required this.price,

    required this.quantity,
  });

  @JsonKey(name: r'filled_at', required: true, includeIfNull: false)
  final DateTime filledAt;

  @JsonKey(name: r'price', required: true, includeIfNull: false)
  final Money price;

  @JsonKey(name: r'quantity', required: true, includeIfNull: false)
  final Quantity quantity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimulatedOrderFill &&
          other.filledAt == filledAt &&
          other.price == price &&
          other.quantity == quantity;

  @override
  int get hashCode => filledAt.hashCode + price.hashCode + quantity.hashCode;

  factory SimulatedOrderFill.fromJson(Map<String, dynamic> json) =>
      _$SimulatedOrderFillFromJson(json);

  Map<String, dynamic> toJson() => _$SimulatedOrderFillToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
