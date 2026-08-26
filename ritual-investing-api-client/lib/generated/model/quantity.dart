//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'quantity.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Quantity {
  /// Returns a new [Quantity] instance.
  Quantity({required this.scale, required this.value});

  // minimum: 0
  // maximum: 12
  @JsonKey(name: r'scale', required: true, includeIfNull: false)
  final int scale;

  @JsonKey(name: r'value', required: true, includeIfNull: false)
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Quantity && other.scale == scale && other.value == value;

  @override
  int get hashCode => scale.hashCode + value.hashCode;

  factory Quantity.fromJson(Map<String, dynamic> json) =>
      _$QuantityFromJson(json);

  Map<String, dynamic> toJson() => _$QuantityToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
