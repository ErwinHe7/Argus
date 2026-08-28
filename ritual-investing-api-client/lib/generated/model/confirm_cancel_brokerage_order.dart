//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'confirm_cancel_brokerage_order.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ConfirmCancelBrokerageOrder {
  /// Returns a new [ConfirmCancelBrokerageOrder] instance.
  ConfirmCancelBrokerageOrder({
    required this.confirmed,

    required this.previewId,
  });

  @JsonKey(name: r'confirmed', required: true, includeIfNull: false)
  final bool confirmed;

  @JsonKey(name: r'preview_id', required: true, includeIfNull: false)
  final String previewId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfirmCancelBrokerageOrder &&
          other.confirmed == confirmed &&
          other.previewId == previewId;

  @override
  int get hashCode => confirmed.hashCode + previewId.hashCode;

  factory ConfirmCancelBrokerageOrder.fromJson(Map<String, dynamic> json) =>
      _$ConfirmCancelBrokerageOrderFromJson(json);

  Map<String, dynamic> toJson() => _$ConfirmCancelBrokerageOrderToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
