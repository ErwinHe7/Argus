//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'redeem_webull_completion_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RedeemWebullCompletionRequest {
  /// Returns a new [RedeemWebullCompletionRequest] instance.
  RedeemWebullCompletionRequest({required this.completion});

  @JsonKey(name: r'completion', required: true, includeIfNull: false)
  final String completion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RedeemWebullCompletionRequest && other.completion == completion;

  @override
  int get hashCode => completion.hashCode;

  factory RedeemWebullCompletionRequest.fromJson(Map<String, dynamic> json) =>
      _$RedeemWebullCompletionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RedeemWebullCompletionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
