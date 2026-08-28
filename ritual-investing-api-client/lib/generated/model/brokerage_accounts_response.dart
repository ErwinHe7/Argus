//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/brokerage_account.dart';
import 'package:ritual_investing_api_client/generated/model/get_account200_response_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_accounts_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokerageAccountsResponse {
  /// Returns a new [BrokerageAccountsResponse] instance.
  BrokerageAccountsResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final List<BrokerageAccount> data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final GetAccount200ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokerageAccountsResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory BrokerageAccountsResponse.fromJson(Map<String, dynamic> json) =>
      _$BrokerageAccountsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$BrokerageAccountsResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
