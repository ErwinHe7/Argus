// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'starpath_recall.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$StarpathRecallCWProxy {
  StarpathRecall id(String id);

  StarpathRecall knowledgeCheck(StarpathKnowledgeCheck knowledgeCheck);

  StarpathRecall lessonId(String lessonId);

  StarpathRecall prompt(String prompt);

  StarpathRecall questionId(String questionId);

  StarpathRecall revisionId(String revisionId);

  StarpathRecall status(StarpathRecallStatusEnum status);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathRecall(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathRecall(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathRecall call({
    String id,
    StarpathKnowledgeCheck knowledgeCheck,
    String lessonId,
    String prompt,
    String questionId,
    String revisionId,
    StarpathRecallStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfStarpathRecall.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfStarpathRecall.copyWith.fieldName(...)`
class _$StarpathRecallCWProxyImpl implements _$StarpathRecallCWProxy {
  const _$StarpathRecallCWProxyImpl(this._value);

  final StarpathRecall _value;

  @override
  StarpathRecall id(String id) => this(id: id);

  @override
  StarpathRecall knowledgeCheck(StarpathKnowledgeCheck knowledgeCheck) =>
      this(knowledgeCheck: knowledgeCheck);

  @override
  StarpathRecall lessonId(String lessonId) => this(lessonId: lessonId);

  @override
  StarpathRecall prompt(String prompt) => this(prompt: prompt);

  @override
  StarpathRecall questionId(String questionId) => this(questionId: questionId);

  @override
  StarpathRecall revisionId(String revisionId) => this(revisionId: revisionId);

  @override
  StarpathRecall status(StarpathRecallStatusEnum status) =>
      this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathRecall(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathRecall(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathRecall call({
    Object? id = const $CopyWithPlaceholder(),
    Object? knowledgeCheck = const $CopyWithPlaceholder(),
    Object? lessonId = const $CopyWithPlaceholder(),
    Object? prompt = const $CopyWithPlaceholder(),
    Object? questionId = const $CopyWithPlaceholder(),
    Object? revisionId = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return StarpathRecall(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      knowledgeCheck: knowledgeCheck == const $CopyWithPlaceholder()
          ? _value.knowledgeCheck
          // ignore: cast_nullable_to_non_nullable
          : knowledgeCheck as StarpathKnowledgeCheck,
      lessonId: lessonId == const $CopyWithPlaceholder()
          ? _value.lessonId
          // ignore: cast_nullable_to_non_nullable
          : lessonId as String,
      prompt: prompt == const $CopyWithPlaceholder()
          ? _value.prompt
          // ignore: cast_nullable_to_non_nullable
          : prompt as String,
      questionId: questionId == const $CopyWithPlaceholder()
          ? _value.questionId
          // ignore: cast_nullable_to_non_nullable
          : questionId as String,
      revisionId: revisionId == const $CopyWithPlaceholder()
          ? _value.revisionId
          // ignore: cast_nullable_to_non_nullable
          : revisionId as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as StarpathRecallStatusEnum,
    );
  }
}

extension $StarpathRecallCopyWith on StarpathRecall {
  /// Returns a callable class that can be used as follows: `instanceOfStarpathRecall.copyWith(...)` or like so:`instanceOfStarpathRecall.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$StarpathRecallCWProxy get copyWith => _$StarpathRecallCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StarpathRecall _$StarpathRecallFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'StarpathRecall',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'id',
            'knowledge_check',
            'lesson_id',
            'prompt',
            'question_id',
            'revision_id',
            'status',
          ],
        );
        final val = StarpathRecall(
          id: $checkedConvert('id', (v) => v as String),
          knowledgeCheck: $checkedConvert(
            'knowledge_check',
            (v) => StarpathKnowledgeCheck.fromJson(v as Map<String, dynamic>),
          ),
          lessonId: $checkedConvert('lesson_id', (v) => v as String),
          prompt: $checkedConvert('prompt', (v) => v as String),
          questionId: $checkedConvert('question_id', (v) => v as String),
          revisionId: $checkedConvert('revision_id', (v) => v as String),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$StarpathRecallStatusEnumEnumMap,
              v,
              unknownValue: StarpathRecallStatusEnum.unknownDefaultOpenApi,
            ),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'knowledgeCheck': 'knowledge_check',
        'lessonId': 'lesson_id',
        'questionId': 'question_id',
        'revisionId': 'revision_id',
      },
    );

Map<String, dynamic> _$StarpathRecallToJson(StarpathRecall instance) =>
    <String, dynamic>{
      'id': instance.id,
      'knowledge_check': instance.knowledgeCheck.toJson(),
      'lesson_id': instance.lessonId,
      'prompt': instance.prompt,
      'question_id': instance.questionId,
      'revision_id': instance.revisionId,
      'status': _$StarpathRecallStatusEnumEnumMap[instance.status]!,
    };

const _$StarpathRecallStatusEnumEnumMap = {
  StarpathRecallStatusEnum.presented: 'presented',
  StarpathRecallStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
