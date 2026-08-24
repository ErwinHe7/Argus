//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/positive_input_money.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_intention_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateIntentionRequest {
  /// Returns a new [CreateIntentionRequest] instance.
  CreateIntentionRequest({
    required this.portfolioId,

    required this.target,

    required this.targetDate,

    required this.title,
  });

  @JsonKey(name: r'portfolio_id', required: true, includeIfNull: false)
  final String portfolioId;

  @JsonKey(name: r'target', required: true, includeIfNull: false)
  final PositiveInputMoney target;

  @JsonKey(name: r'target_date', required: true, includeIfNull: false)
  final DateTime targetDate;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateIntentionRequest &&
          other.portfolioId == portfolioId &&
          other.target == target &&
          other.targetDate == targetDate &&
          other.title == title;

  @override
  int get hashCode =>
      portfolioId.hashCode +
      target.hashCode +
      targetDate.hashCode +
      title.hashCode;

  factory CreateIntentionRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateIntentionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateIntentionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
