//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/brokerage_order_detail.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_audit200_response_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_order_detail_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokerageOrderDetailResponse {
  /// Returns a new [BrokerageOrderDetailResponse] instance.
  BrokerageOrderDetailResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final BrokerageOrderDetail data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ListAdminAudit200ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokerageOrderDetailResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory BrokerageOrderDetailResponse.fromJson(Map<String, dynamic> json) =>
      _$BrokerageOrderDetailResponseFromJson(json);

  Map<String, dynamic> toJson() => _$BrokerageOrderDetailResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
