//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/starpath_knowledge_check.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'starpath_recall.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StarpathRecall {
  /// Returns a new [StarpathRecall] instance.
  StarpathRecall({
    required this.id,

    required this.knowledgeCheck,

    required this.lessonId,

    required this.prompt,

    required this.questionId,

    required this.revisionId,

    required this.status,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'knowledge_check', required: true, includeIfNull: false)
  final StarpathKnowledgeCheck knowledgeCheck;

  @JsonKey(name: r'lesson_id', required: true, includeIfNull: false)
  final String lessonId;

  @JsonKey(name: r'prompt', required: true, includeIfNull: false)
  final String prompt;

  @JsonKey(name: r'question_id', required: true, includeIfNull: false)
  final String questionId;

  @JsonKey(name: r'revision_id', required: true, includeIfNull: false)
  final String revisionId;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: StarpathRecallStatusEnum.unknownDefaultOpenApi,
  )
  final StarpathRecallStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarpathRecall &&
          other.id == id &&
          other.knowledgeCheck == knowledgeCheck &&
          other.lessonId == lessonId &&
          other.prompt == prompt &&
          other.questionId == questionId &&
          other.revisionId == revisionId &&
          other.status == status;

  @override
  int get hashCode =>
      id.hashCode +
      knowledgeCheck.hashCode +
      lessonId.hashCode +
      prompt.hashCode +
      questionId.hashCode +
      revisionId.hashCode +
      status.hashCode;

  factory StarpathRecall.fromJson(Map<String, dynamic> json) =>
      _$StarpathRecallFromJson(json);

  Map<String, dynamic> toJson() => _$StarpathRecallToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum StarpathRecallStatusEnum {
  @JsonValue(r'presented')
  presented(r'presented'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const StarpathRecallStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
