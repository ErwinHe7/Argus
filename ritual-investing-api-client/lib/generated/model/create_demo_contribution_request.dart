//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/positive_input_money.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_demo_contribution_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateDemoContributionRequest {
  /// Returns a new [CreateDemoContributionRequest] instance.
  CreateDemoContributionRequest({
    required this.amount,

    this.effectiveAt,

    required this.sourceId,
  });

  @JsonKey(name: r'amount', required: true, includeIfNull: false)
  final PositiveInputMoney amount;

  @JsonKey(name: r'effective_at', required: false, includeIfNull: false)
  final DateTime? effectiveAt;

  @JsonKey(name: r'source_id', required: true, includeIfNull: false)
  final String sourceId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateDemoContributionRequest &&
          other.amount == amount &&
          other.effectiveAt == effectiveAt &&
          other.sourceId == sourceId;

  @override
  int get hashCode =>
      amount.hashCode + effectiveAt.hashCode + sourceId.hashCode;

  factory CreateDemoContributionRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateDemoContributionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateDemoContributionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
