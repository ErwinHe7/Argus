//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/create_portfolio_request_target_allocation_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_portfolio_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreatePortfolioRequest {
  /// Returns a new [CreatePortfolioRequest] instance.
  CreatePortfolioRequest({
    required this.currency,

    required this.name,

    this.targetAllocation,
  });

  @JsonKey(
    name: r'currency',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CreatePortfolioRequestCurrencyEnum.unknownDefaultOpenApi,
  )
  final CreatePortfolioRequestCurrencyEnum currency;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'target_allocation', required: false, includeIfNull: false)
  final List<CreatePortfolioRequestTargetAllocationInner>? targetAllocation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatePortfolioRequest &&
          other.currency == currency &&
          other.name == name &&
          other.targetAllocation == targetAllocation;

  @override
  int get hashCode =>
      currency.hashCode + name.hashCode + targetAllocation.hashCode;

  factory CreatePortfolioRequest.fromJson(Map<String, dynamic> json) =>
      _$CreatePortfolioRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreatePortfolioRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreatePortfolioRequestCurrencyEnum {
  @JsonValue(r'USD')
  USD(r'USD'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreatePortfolioRequestCurrencyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
