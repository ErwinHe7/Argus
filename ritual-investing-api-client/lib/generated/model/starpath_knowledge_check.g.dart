// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'starpath_knowledge_check.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$StarpathKnowledgeCheckCWProxy {
  StarpathKnowledgeCheck id(String id);

  StarpathKnowledgeCheck options(List<StarpathKnowledgeCheckOption> options);

  StarpathKnowledgeCheck prompt(String prompt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathKnowledgeCheck(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathKnowledgeCheck(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathKnowledgeCheck call({
    String id,
    List<StarpathKnowledgeCheckOption> options,
    String prompt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfStarpathKnowledgeCheck.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfStarpathKnowledgeCheck.copyWith.fieldName(...)`
class _$StarpathKnowledgeCheckCWProxyImpl
    implements _$StarpathKnowledgeCheckCWProxy {
  const _$StarpathKnowledgeCheckCWProxyImpl(this._value);

  final StarpathKnowledgeCheck _value;

  @override
  StarpathKnowledgeCheck id(String id) => this(id: id);

  @override
  StarpathKnowledgeCheck options(List<StarpathKnowledgeCheckOption> options) =>
      this(options: options);

  @override
  StarpathKnowledgeCheck prompt(String prompt) => this(prompt: prompt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathKnowledgeCheck(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathKnowledgeCheck(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathKnowledgeCheck call({
    Object? id = const $CopyWithPlaceholder(),
    Object? options = const $CopyWithPlaceholder(),
    Object? prompt = const $CopyWithPlaceholder(),
  }) {
    return StarpathKnowledgeCheck(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      options: options == const $CopyWithPlaceholder()
          ? _value.options
          // ignore: cast_nullable_to_non_nullable
          : options as List<StarpathKnowledgeCheckOption>,
      prompt: prompt == const $CopyWithPlaceholder()
          ? _value.prompt
          // ignore: cast_nullable_to_non_nullable
          : prompt as String,
    );
  }
}

extension $StarpathKnowledgeCheckCopyWith on StarpathKnowledgeCheck {
  /// Returns a callable class that can be used as follows: `instanceOfStarpathKnowledgeCheck.copyWith(...)` or like so:`instanceOfStarpathKnowledgeCheck.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$StarpathKnowledgeCheckCWProxy get copyWith =>
      _$StarpathKnowledgeCheckCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StarpathKnowledgeCheck _$StarpathKnowledgeCheckFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('StarpathKnowledgeCheck', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['id', 'options', 'prompt']);
  final val = StarpathKnowledgeCheck(
    id: $checkedConvert('id', (v) => v as String),
    options: $checkedConvert(
      'options',
      (v) => (v as List<dynamic>)
          .map(
            (e) => StarpathKnowledgeCheckOption.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    ),
    prompt: $checkedConvert('prompt', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$StarpathKnowledgeCheckToJson(
  StarpathKnowledgeCheck instance,
) => <String, dynamic>{
  'id': instance.id,
  'options': instance.options.map((e) => e.toJson()).toList(),
  'prompt': instance.prompt,
};
