// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'starpath_answer_feedback.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$StarpathAnswerFeedbackCWProxy {
  StarpathAnswerFeedback explanation(String explanation);

  StarpathAnswerFeedback isCorrect(bool isCorrect);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathAnswerFeedback(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathAnswerFeedback(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathAnswerFeedback call({String explanation, bool isCorrect});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfStarpathAnswerFeedback.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfStarpathAnswerFeedback.copyWith.fieldName(...)`
class _$StarpathAnswerFeedbackCWProxyImpl
    implements _$StarpathAnswerFeedbackCWProxy {
  const _$StarpathAnswerFeedbackCWProxyImpl(this._value);

  final StarpathAnswerFeedback _value;

  @override
  StarpathAnswerFeedback explanation(String explanation) =>
      this(explanation: explanation);

  @override
  StarpathAnswerFeedback isCorrect(bool isCorrect) =>
      this(isCorrect: isCorrect);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathAnswerFeedback(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathAnswerFeedback(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathAnswerFeedback call({
    Object? explanation = const $CopyWithPlaceholder(),
    Object? isCorrect = const $CopyWithPlaceholder(),
  }) {
    return StarpathAnswerFeedback(
      explanation: explanation == const $CopyWithPlaceholder()
          ? _value.explanation
          // ignore: cast_nullable_to_non_nullable
          : explanation as String,
      isCorrect: isCorrect == const $CopyWithPlaceholder()
          ? _value.isCorrect
          // ignore: cast_nullable_to_non_nullable
          : isCorrect as bool,
    );
  }
}

extension $StarpathAnswerFeedbackCopyWith on StarpathAnswerFeedback {
  /// Returns a callable class that can be used as follows: `instanceOfStarpathAnswerFeedback.copyWith(...)` or like so:`instanceOfStarpathAnswerFeedback.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$StarpathAnswerFeedbackCWProxy get copyWith =>
      _$StarpathAnswerFeedbackCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StarpathAnswerFeedback _$StarpathAnswerFeedbackFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('StarpathAnswerFeedback', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['explanation', 'is_correct']);
  final val = StarpathAnswerFeedback(
    explanation: $checkedConvert('explanation', (v) => v as String),
    isCorrect: $checkedConvert('is_correct', (v) => v as bool),
  );
  return val;
}, fieldKeyMap: const {'isCorrect': 'is_correct'});

Map<String, dynamic> _$StarpathAnswerFeedbackToJson(
  StarpathAnswerFeedback instance,
) => <String, dynamic>{
  'explanation': instance.explanation,
  'is_correct': instance.isCorrect,
};
