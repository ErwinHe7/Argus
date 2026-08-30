// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'starpath_knowledge_check_option.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$StarpathKnowledgeCheckOptionCWProxy {
  StarpathKnowledgeCheckOption id(String id);

  StarpathKnowledgeCheckOption label(String label);

  StarpathKnowledgeCheckOption ordinal(int ordinal);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathKnowledgeCheckOption(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathKnowledgeCheckOption(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathKnowledgeCheckOption call({String id, String label, int ordinal});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfStarpathKnowledgeCheckOption.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfStarpathKnowledgeCheckOption.copyWith.fieldName(...)`
class _$StarpathKnowledgeCheckOptionCWProxyImpl
    implements _$StarpathKnowledgeCheckOptionCWProxy {
  const _$StarpathKnowledgeCheckOptionCWProxyImpl(this._value);

  final StarpathKnowledgeCheckOption _value;

  @override
  StarpathKnowledgeCheckOption id(String id) => this(id: id);

  @override
  StarpathKnowledgeCheckOption label(String label) => this(label: label);

  @override
  StarpathKnowledgeCheckOption ordinal(int ordinal) => this(ordinal: ordinal);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathKnowledgeCheckOption(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathKnowledgeCheckOption(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathKnowledgeCheckOption call({
    Object? id = const $CopyWithPlaceholder(),
    Object? label = const $CopyWithPlaceholder(),
    Object? ordinal = const $CopyWithPlaceholder(),
  }) {
    return StarpathKnowledgeCheckOption(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      label: label == const $CopyWithPlaceholder()
          ? _value.label
          // ignore: cast_nullable_to_non_nullable
          : label as String,
      ordinal: ordinal == const $CopyWithPlaceholder()
          ? _value.ordinal
          // ignore: cast_nullable_to_non_nullable
          : ordinal as int,
    );
  }
}

extension $StarpathKnowledgeCheckOptionCopyWith
    on StarpathKnowledgeCheckOption {
  /// Returns a callable class that can be used as follows: `instanceOfStarpathKnowledgeCheckOption.copyWith(...)` or like so:`instanceOfStarpathKnowledgeCheckOption.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$StarpathKnowledgeCheckOptionCWProxy get copyWith =>
      _$StarpathKnowledgeCheckOptionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StarpathKnowledgeCheckOption _$StarpathKnowledgeCheckOptionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('StarpathKnowledgeCheckOption', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['id', 'label', 'ordinal']);
  final val = StarpathKnowledgeCheckOption(
    id: $checkedConvert('id', (v) => v as String),
    label: $checkedConvert('label', (v) => v as String),
    ordinal: $checkedConvert('ordinal', (v) => (v as num).toInt()),
  );
  return val;
});

Map<String, dynamic> _$StarpathKnowledgeCheckOptionToJson(
  StarpathKnowledgeCheckOption instance,
) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'ordinal': instance.ordinal,
};
