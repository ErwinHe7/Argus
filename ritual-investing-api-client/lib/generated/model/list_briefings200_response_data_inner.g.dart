// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_briefings200_response_data_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListBriefings200ResponseDataInnerCWProxy {
  ListBriefings200ResponseDataInner briefingType(
    ListBriefings200ResponseDataInnerBriefingTypeEnum briefingType,
  );

  ListBriefings200ResponseDataInner generatedAt(DateTime generatedAt);

  ListBriefings200ResponseDataInner generation(int generation);

  ListBriefings200ResponseDataInner id(String id);

  ListBriefings200ResponseDataInner periodEnd(DateTime periodEnd);

  ListBriefings200ResponseDataInner periodStart(DateTime periodStart);

  ListBriefings200ResponseDataInner readAt(DateTime? readAt);

  ListBriefings200ResponseDataInner sourceSequence(int sourceSequence);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListBriefings200ResponseDataInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListBriefings200ResponseDataInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListBriefings200ResponseDataInner call({
    ListBriefings200ResponseDataInnerBriefingTypeEnum briefingType,
    DateTime generatedAt,
    int generation,
    String id,
    DateTime periodEnd,
    DateTime periodStart,
    DateTime? readAt,
    int sourceSequence,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListBriefings200ResponseDataInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListBriefings200ResponseDataInner.copyWith.fieldName(...)`
class _$ListBriefings200ResponseDataInnerCWProxyImpl
    implements _$ListBriefings200ResponseDataInnerCWProxy {
  const _$ListBriefings200ResponseDataInnerCWProxyImpl(this._value);

  final ListBriefings200ResponseDataInner _value;

  @override
  ListBriefings200ResponseDataInner briefingType(
    ListBriefings200ResponseDataInnerBriefingTypeEnum briefingType,
  ) => this(briefingType: briefingType);

  @override
  ListBriefings200ResponseDataInner generatedAt(DateTime generatedAt) =>
      this(generatedAt: generatedAt);

  @override
  ListBriefings200ResponseDataInner generation(int generation) =>
      this(generation: generation);

  @override
  ListBriefings200ResponseDataInner id(String id) => this(id: id);

  @override
  ListBriefings200ResponseDataInner periodEnd(DateTime periodEnd) =>
      this(periodEnd: periodEnd);

  @override
  ListBriefings200ResponseDataInner periodStart(DateTime periodStart) =>
      this(periodStart: periodStart);

  @override
  ListBriefings200ResponseDataInner readAt(DateTime? readAt) =>
      this(readAt: readAt);

  @override
  ListBriefings200ResponseDataInner sourceSequence(int sourceSequence) =>
      this(sourceSequence: sourceSequence);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListBriefings200ResponseDataInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListBriefings200ResponseDataInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListBriefings200ResponseDataInner call({
    Object? briefingType = const $CopyWithPlaceholder(),
    Object? generatedAt = const $CopyWithPlaceholder(),
    Object? generation = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? periodEnd = const $CopyWithPlaceholder(),
    Object? periodStart = const $CopyWithPlaceholder(),
    Object? readAt = const $CopyWithPlaceholder(),
    Object? sourceSequence = const $CopyWithPlaceholder(),
  }) {
    return ListBriefings200ResponseDataInner(
      briefingType: briefingType == const $CopyWithPlaceholder()
          ? _value.briefingType
          // ignore: cast_nullable_to_non_nullable
          : briefingType as ListBriefings200ResponseDataInnerBriefingTypeEnum,
      generatedAt: generatedAt == const $CopyWithPlaceholder()
          ? _value.generatedAt
          // ignore: cast_nullable_to_non_nullable
          : generatedAt as DateTime,
      generation: generation == const $CopyWithPlaceholder()
          ? _value.generation
          // ignore: cast_nullable_to_non_nullable
          : generation as int,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      periodEnd: periodEnd == const $CopyWithPlaceholder()
          ? _value.periodEnd
          // ignore: cast_nullable_to_non_nullable
          : periodEnd as DateTime,
      periodStart: periodStart == const $CopyWithPlaceholder()
          ? _value.periodStart
          // ignore: cast_nullable_to_non_nullable
          : periodStart as DateTime,
      readAt: readAt == const $CopyWithPlaceholder()
          ? _value.readAt
          // ignore: cast_nullable_to_non_nullable
          : readAt as DateTime?,
      sourceSequence: sourceSequence == const $CopyWithPlaceholder()
          ? _value.sourceSequence
          // ignore: cast_nullable_to_non_nullable
          : sourceSequence as int,
    );
  }
}

extension $ListBriefings200ResponseDataInnerCopyWith
    on ListBriefings200ResponseDataInner {
  /// Returns a callable class that can be used as follows: `instanceOfListBriefings200ResponseDataInner.copyWith(...)` or like so:`instanceOfListBriefings200ResponseDataInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListBriefings200ResponseDataInnerCWProxy get copyWith =>
      _$ListBriefings200ResponseDataInnerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListBriefings200ResponseDataInner _$ListBriefings200ResponseDataInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'ListBriefings200ResponseDataInner',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'briefing_type',
        'generated_at',
        'generation',
        'id',
        'period_end',
        'period_start',
        'read_at',
        'source_sequence',
      ],
    );
    final val = ListBriefings200ResponseDataInner(
      briefingType: $checkedConvert(
        'briefing_type',
        (v) => $enumDecode(
          _$ListBriefings200ResponseDataInnerBriefingTypeEnumEnumMap,
          v,
          unknownValue: ListBriefings200ResponseDataInnerBriefingTypeEnum
              .unknownDefaultOpenApi,
        ),
      ),
      generatedAt: $checkedConvert(
        'generated_at',
        (v) => DateTime.parse(v as String),
      ),
      generation: $checkedConvert('generation', (v) => (v as num).toInt()),
      id: $checkedConvert('id', (v) => v as String),
      periodEnd: $checkedConvert(
        'period_end',
        (v) => DateTime.parse(v as String),
      ),
      periodStart: $checkedConvert(
        'period_start',
        (v) => DateTime.parse(v as String),
      ),
      readAt: $checkedConvert(
        'read_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      sourceSequence: $checkedConvert(
        'source_sequence',
        (v) => (v as num).toInt(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'briefingType': 'briefing_type',
    'generatedAt': 'generated_at',
    'periodEnd': 'period_end',
    'periodStart': 'period_start',
    'readAt': 'read_at',
    'sourceSequence': 'source_sequence',
  },
);

Map<String, dynamic> _$ListBriefings200ResponseDataInnerToJson(
  ListBriefings200ResponseDataInner instance,
) => <String, dynamic>{
  'briefing_type':
      _$ListBriefings200ResponseDataInnerBriefingTypeEnumEnumMap[instance
          .briefingType]!,
  'generated_at': instance.generatedAt.toIso8601String(),
  'generation': instance.generation,
  'id': instance.id,
  'period_end': instance.periodEnd.toIso8601String(),
  'period_start': instance.periodStart.toIso8601String(),
  'read_at': instance.readAt?.toIso8601String(),
  'source_sequence': instance.sourceSequence,
};

const _$ListBriefings200ResponseDataInnerBriefingTypeEnumEnumMap = {
  ListBriefings200ResponseDataInnerBriefingTypeEnum.daily: 'daily',
  ListBriefings200ResponseDataInnerBriefingTypeEnum.weekly: 'weekly',
  ListBriefings200ResponseDataInnerBriefingTypeEnum.moonCycle: 'moon_cycle',
  ListBriefings200ResponseDataInnerBriefingTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
