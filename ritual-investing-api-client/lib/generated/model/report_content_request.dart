//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'report_content_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ReportContentRequest {
  /// Returns a new [ReportContentRequest] instance.
  ReportContentRequest({
    this.details,

    required this.reasonCode,

    required this.targetId,

    required this.targetKind,
  });

  @JsonKey(name: r'details', required: false, includeIfNull: false)
  final String? details;

  @JsonKey(name: r'reasonCode', required: true, includeIfNull: false)
  final String reasonCode;

  @JsonKey(name: r'targetId', required: true, includeIfNull: false)
  final String targetId;

  @JsonKey(name: r'targetKind', required: true, includeIfNull: false)
  final String targetKind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportContentRequest &&
          other.details == details &&
          other.reasonCode == reasonCode &&
          other.targetId == targetId &&
          other.targetKind == targetKind;

  @override
  int get hashCode =>
      details.hashCode +
      reasonCode.hashCode +
      targetId.hashCode +
      targetKind.hashCode;

  factory ReportContentRequest.fromJson(Map<String, dynamic> json) =>
      _$ReportContentRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ReportContentRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
