//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'starpath_answer_feedback.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StarpathAnswerFeedback {
  /// Returns a new [StarpathAnswerFeedback] instance.
  StarpathAnswerFeedback({required this.explanation, required this.isCorrect});

  @JsonKey(name: r'explanation', required: true, includeIfNull: false)
  final String explanation;

  @JsonKey(name: r'is_correct', required: true, includeIfNull: false)
  final bool isCorrect;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarpathAnswerFeedback &&
          other.explanation == explanation &&
          other.isCorrect == isCorrect;

  @override
  int get hashCode => explanation.hashCode + isCorrect.hashCode;

  factory StarpathAnswerFeedback.fromJson(Map<String, dynamic> json) =>
      _$StarpathAnswerFeedbackFromJson(json);

  Map<String, dynamic> toJson() => _$StarpathAnswerFeedbackToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
