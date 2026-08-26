//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/positive_input_money.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_intention_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchIntentionRequest {
  /// Returns a new [PatchIntentionRequest] instance.
  PatchIntentionRequest({
    this.status,

    this.target,

    this.targetDate,

    this.title,
  });

  @JsonKey(
    name: r'status',
    required: false,
    includeIfNull: false,
    unknownEnumValue: PatchIntentionRequestStatusEnum.unknownDefaultOpenApi,
  )
  final PatchIntentionRequestStatusEnum? status;

  @JsonKey(name: r'target', required: false, includeIfNull: false)
  final PositiveInputMoney? target;

  @JsonKey(name: r'target_date', required: false, includeIfNull: false)
  final DateTime? targetDate;

  @JsonKey(name: r'title', required: false, includeIfNull: false)
  final String? title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchIntentionRequest &&
          other.status == status &&
          other.target == target &&
          other.targetDate == targetDate &&
          other.title == title;

  @override
  int get hashCode =>
      status.hashCode + target.hashCode + targetDate.hashCode + title.hashCode;

  factory PatchIntentionRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchIntentionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchIntentionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PatchIntentionRequestStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'completed')
  completed(r'completed'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PatchIntentionRequestStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
