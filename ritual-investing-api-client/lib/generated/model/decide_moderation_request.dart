//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'decide_moderation_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DecideModerationRequest {
  /// Returns a new [DecideModerationRequest] instance.
  DecideModerationRequest({required this.status});

  @JsonKey(name: r'status', required: true, includeIfNull: false)
  final String status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecideModerationRequest && other.status == status;

  @override
  int get hashCode => status.hashCode;

  factory DecideModerationRequest.fromJson(Map<String, dynamic> json) =>
      _$DecideModerationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$DecideModerationRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
