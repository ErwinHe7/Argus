// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'answer_starpath_question.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AnswerStarpathQuestionCWProxy {
  AnswerStarpathQuestion attemptKind(
    AnswerStarpathQuestionAttemptKindEnum? attemptKind,
  );

  AnswerStarpathQuestion manifestId(String manifestId);

  AnswerStarpathQuestion optionId(String optionId);

  AnswerStarpathQuestion questionId(String questionId);

  AnswerStarpathQuestion revisionId(String revisionId);

  AnswerStarpathQuestion sessionId(String sessionId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AnswerStarpathQuestion(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AnswerStarpathQuestion(...).copyWith(id: 12, name: "My name")
  /// ````
  AnswerStarpathQuestion call({
    AnswerStarpathQuestionAttemptKindEnum? attemptKind,
    String manifestId,
    String optionId,
    String questionId,
    String revisionId,
    String sessionId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAnswerStarpathQuestion.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAnswerStarpathQuestion.copyWith.fieldName(...)`
class _$AnswerStarpathQuestionCWProxyImpl
    implements _$AnswerStarpathQuestionCWProxy {
  const _$AnswerStarpathQuestionCWProxyImpl(this._value);

  final AnswerStarpathQuestion _value;

  @override
  AnswerStarpathQuestion attemptKind(
    AnswerStarpathQuestionAttemptKindEnum? attemptKind,
  ) => this(attemptKind: attemptKind);

  @override
  AnswerStarpathQuestion manifestId(String manifestId) =>
      this(manifestId: manifestId);

  @override
  AnswerStarpathQuestion optionId(String optionId) => this(optionId: optionId);

  @override
  AnswerStarpathQuestion questionId(String questionId) =>
      this(questionId: questionId);

  @override
  AnswerStarpathQuestion revisionId(String revisionId) =>
      this(revisionId: revisionId);

  @override
  AnswerStarpathQuestion sessionId(String sessionId) =>
      this(sessionId: sessionId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AnswerStarpathQuestion(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AnswerStarpathQuestion(...).copyWith(id: 12, name: "My name")
  /// ````
  AnswerStarpathQuestion call({
    Object? attemptKind = const $CopyWithPlaceholder(),
    Object? manifestId = const $CopyWithPlaceholder(),
    Object? optionId = const $CopyWithPlaceholder(),
    Object? questionId = const $CopyWithPlaceholder(),
    Object? revisionId = const $CopyWithPlaceholder(),
    Object? sessionId = const $CopyWithPlaceholder(),
  }) {
    return AnswerStarpathQuestion(
      attemptKind: attemptKind == const $CopyWithPlaceholder()
          ? _value.attemptKind
          // ignore: cast_nullable_to_non_nullable
          : attemptKind as AnswerStarpathQuestionAttemptKindEnum?,
      manifestId: manifestId == const $CopyWithPlaceholder()
          ? _value.manifestId
          // ignore: cast_nullable_to_non_nullable
          : manifestId as String,
      optionId: optionId == const $CopyWithPlaceholder()
          ? _value.optionId
          // ignore: cast_nullable_to_non_nullable
          : optionId as String,
      questionId: questionId == const $CopyWithPlaceholder()
          ? _value.questionId
          // ignore: cast_nullable_to_non_nullable
          : questionId as String,
      revisionId: revisionId == const $CopyWithPlaceholder()
          ? _value.revisionId
          // ignore: cast_nullable_to_non_nullable
          : revisionId as String,
      sessionId: sessionId == const $CopyWithPlaceholder()
          ? _value.sessionId
          // ignore: cast_nullable_to_non_nullable
          : sessionId as String,
    );
  }
}

extension $AnswerStarpathQuestionCopyWith on AnswerStarpathQuestion {
  /// Returns a callable class that can be used as follows: `instanceOfAnswerStarpathQuestion.copyWith(...)` or like so:`instanceOfAnswerStarpathQuestion.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AnswerStarpathQuestionCWProxy get copyWith =>
      _$AnswerStarpathQuestionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnswerStarpathQuestion _$AnswerStarpathQuestionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'AnswerStarpathQuestion',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'manifest_id',
        'option_id',
        'question_id',
        'revision_id',
        'session_id',
      ],
    );
    final val = AnswerStarpathQuestion(
      attemptKind: $checkedConvert(
        'attempt_kind',
        (v) => $enumDecodeNullable(
          _$AnswerStarpathQuestionAttemptKindEnumEnumMap,
          v,
          unknownValue:
              AnswerStarpathQuestionAttemptKindEnum.unknownDefaultOpenApi,
        ),
      ),
      manifestId: $checkedConvert('manifest_id', (v) => v as String),
      optionId: $checkedConvert('option_id', (v) => v as String),
      questionId: $checkedConvert('question_id', (v) => v as String),
      revisionId: $checkedConvert('revision_id', (v) => v as String),
      sessionId: $checkedConvert('session_id', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'attemptKind': 'attempt_kind',
    'manifestId': 'manifest_id',
    'optionId': 'option_id',
    'questionId': 'question_id',
    'revisionId': 'revision_id',
    'sessionId': 'session_id',
  },
);

Map<String, dynamic> _$AnswerStarpathQuestionToJson(
  AnswerStarpathQuestion instance,
) => <String, dynamic>{
  'attempt_kind':
      ?_$AnswerStarpathQuestionAttemptKindEnumEnumMap[instance.attemptKind],
  'manifest_id': instance.manifestId,
  'option_id': instance.optionId,
  'question_id': instance.questionId,
  'revision_id': instance.revisionId,
  'session_id': instance.sessionId,
};

const _$AnswerStarpathQuestionAttemptKindEnumEnumMap = {
  AnswerStarpathQuestionAttemptKindEnum.node: 'node',
  AnswerStarpathQuestionAttemptKindEnum.recall: 'recall',
  AnswerStarpathQuestionAttemptKindEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
