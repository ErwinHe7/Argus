//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/get_account200_response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_positions_projection.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_positions_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokeragePositionsResponse {
  /// Returns a new [BrokeragePositionsResponse] instance.
  BrokeragePositionsResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final BrokeragePositionsProjection data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final GetAccount200ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokeragePositionsResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory BrokeragePositionsResponse.fromJson(Map<String, dynamic> json) =>
      _$BrokeragePositionsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$BrokeragePositionsResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
