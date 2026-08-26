//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'set_briefing_read_state_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SetBriefingReadStateRequest {
  /// Returns a new [SetBriefingReadStateRequest] instance.
  SetBriefingReadStateRequest({required this.read});

  @JsonKey(name: r'read', required: true, includeIfNull: false)
  final bool read;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetBriefingReadStateRequest && other.read == read;

  @override
  int get hashCode => read.hashCode;

  factory SetBriefingReadStateRequest.fromJson(Map<String, dynamic> json) =>
      _$SetBriefingReadStateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SetBriefingReadStateRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
