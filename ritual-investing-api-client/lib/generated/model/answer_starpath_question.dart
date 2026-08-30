//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'answer_starpath_question.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AnswerStarpathQuestion {
  /// Returns a new [AnswerStarpathQuestion] instance.
  AnswerStarpathQuestion({
    this.attemptKind,

    required this.manifestId,

    required this.optionId,

    required this.questionId,

    required this.revisionId,

    required this.sessionId,
  });

  @JsonKey(
    name: r'attempt_kind',
    required: false,
    includeIfNull: false,
    unknownEnumValue:
        AnswerStarpathQuestionAttemptKindEnum.unknownDefaultOpenApi,
  )
  final AnswerStarpathQuestionAttemptKindEnum? attemptKind;

  @JsonKey(name: r'manifest_id', required: true, includeIfNull: false)
  final String manifestId;

  @JsonKey(name: r'option_id', required: true, includeIfNull: false)
  final String optionId;

  @JsonKey(name: r'question_id', required: true, includeIfNull: false)
  final String questionId;

  @JsonKey(name: r'revision_id', required: true, includeIfNull: false)
  final String revisionId;

  @JsonKey(name: r'session_id', required: true, includeIfNull: false)
  final String sessionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnswerStarpathQuestion &&
          other.attemptKind == attemptKind &&
          other.manifestId == manifestId &&
          other.optionId == optionId &&
          other.questionId == questionId &&
          other.revisionId == revisionId &&
          other.sessionId == sessionId;

  @override
  int get hashCode =>
      attemptKind.hashCode +
      manifestId.hashCode +
      optionId.hashCode +
      questionId.hashCode +
      revisionId.hashCode +
      sessionId.hashCode;

  factory AnswerStarpathQuestion.fromJson(Map<String, dynamic> json) =>
      _$AnswerStarpathQuestionFromJson(json);

  Map<String, dynamic> toJson() => _$AnswerStarpathQuestionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AnswerStarpathQuestionAttemptKindEnum {
  @JsonValue(r'node')
  node(r'node'),
  @JsonValue(r'recall')
  recall(r'recall'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AnswerStarpathQuestionAttemptKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
