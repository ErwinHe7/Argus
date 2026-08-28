//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'modify_brokerage_order_intent.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ModifyBrokerageOrderIntent {
  /// Returns a new [ModifyBrokerageOrderIntent] instance.
  ModifyBrokerageOrderIntent({
    required this.limitPrice,

    required this.quantity,
  });

  @JsonKey(name: r'limit_price', required: true, includeIfNull: true)
  final String? limitPrice;

  @JsonKey(name: r'quantity', required: true, includeIfNull: false)
  final String quantity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModifyBrokerageOrderIntent &&
          other.limitPrice == limitPrice &&
          other.quantity == quantity;

  @override
  int get hashCode =>
      (limitPrice == null ? 0 : limitPrice.hashCode) + quantity.hashCode;

  factory ModifyBrokerageOrderIntent.fromJson(Map<String, dynamic> json) =>
      _$ModifyBrokerageOrderIntentFromJson(json);

  Map<String, dynamic> toJson() => _$ModifyBrokerageOrderIntentToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
