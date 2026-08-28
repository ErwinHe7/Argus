//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/modify_brokerage_order_intent.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'confirm_modify_brokerage_order.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ConfirmModifyBrokerageOrder {
  /// Returns a new [ConfirmModifyBrokerageOrder] instance.
  ConfirmModifyBrokerageOrder({
    required this.confirmed,

    required this.intent,

    required this.previewId,
  });

  @JsonKey(name: r'confirmed', required: true, includeIfNull: false)
  final bool confirmed;

  @JsonKey(name: r'intent', required: true, includeIfNull: false)
  final ModifyBrokerageOrderIntent intent;

  @JsonKey(name: r'preview_id', required: true, includeIfNull: false)
  final String previewId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfirmModifyBrokerageOrder &&
          other.confirmed == confirmed &&
          other.intent == intent &&
          other.previewId == previewId;

  @override
  int get hashCode => confirmed.hashCode + intent.hashCode + previewId.hashCode;

  factory ConfirmModifyBrokerageOrder.fromJson(Map<String, dynamic> json) =>
      _$ConfirmModifyBrokerageOrderFromJson(json);

  Map<String, dynamic> toJson() => _$ConfirmModifyBrokerageOrderToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
