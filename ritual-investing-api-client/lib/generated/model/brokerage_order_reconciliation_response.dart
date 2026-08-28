//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/get_account200_response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_order_reconciliation.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_order_reconciliation_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokerageOrderReconciliationResponse {
  /// Returns a new [BrokerageOrderReconciliationResponse] instance.
  BrokerageOrderReconciliationResponse({
    required this.data,

    required this.meta,
  });

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final BrokerageOrderReconciliation data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final GetAccount200ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokerageOrderReconciliationResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory BrokerageOrderReconciliationResponse.fromJson(
    Map<String, dynamic> json,
  ) => _$BrokerageOrderReconciliationResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$BrokerageOrderReconciliationResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
