//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_content_report_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateContentReportRequest {
  /// Returns a new [CreateContentReportRequest] instance.
  CreateContentReportRequest({
    this.detail,

    required this.reasonCode,

    required this.targetId,

    required this.targetKind,
  });

  @JsonKey(name: r'detail', required: false, includeIfNull: false)
  final String? detail;

  @JsonKey(
    name: r'reason_code',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CreateContentReportRequestReasonCodeEnum.unknownDefaultOpenApi,
  )
  final CreateContentReportRequestReasonCodeEnum reasonCode;

  @JsonKey(name: r'target_id', required: true, includeIfNull: false)
  final String targetId;

  @JsonKey(
    name: r'target_kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CreateContentReportRequestTargetKindEnum.unknownDefaultOpenApi,
  )
  final CreateContentReportRequestTargetKindEnum targetKind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateContentReportRequest &&
          other.detail == detail &&
          other.reasonCode == reasonCode &&
          other.targetId == targetId &&
          other.targetKind == targetKind;

  @override
  int get hashCode =>
      detail.hashCode +
      reasonCode.hashCode +
      targetId.hashCode +
      targetKind.hashCode;

  factory CreateContentReportRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateContentReportRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateContentReportRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateContentReportRequestReasonCodeEnum {
  @JsonValue(r'incorrect')
  incorrect(r'incorrect'),
  @JsonValue(r'unsafe')
  unsafe(r'unsafe'),
  @JsonValue(r'spam')
  spam(r'spam'),
  @JsonValue(r'rights')
  rights(r'rights'),
  @JsonValue(r'other')
  other(r'other'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateContentReportRequestReasonCodeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CreateContentReportRequestTargetKindEnum {
  @JsonValue(r'ritual')
  ritual(r'ritual'),
  @JsonValue(r'codex')
  codex(r'codex'),
  @JsonValue(r'coven')
  coven(r'coven'),
  @JsonValue(r'grimoire')
  grimoire(r'grimoire'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateContentReportRequestTargetKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
