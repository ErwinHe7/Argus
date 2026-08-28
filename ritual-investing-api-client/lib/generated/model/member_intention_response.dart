//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/get_account200_response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/member_intention.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'member_intention_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemberIntentionResponse {
  /// Returns a new [MemberIntentionResponse] instance.
  MemberIntentionResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final MemberIntention data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final GetAccount200ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberIntentionResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory MemberIntentionResponse.fromJson(Map<String, dynamic> json) =>
      _$MemberIntentionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MemberIntentionResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
