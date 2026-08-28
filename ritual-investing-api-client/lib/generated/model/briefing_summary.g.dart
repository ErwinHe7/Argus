// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'briefing_summary.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BriefingSummaryCWProxy {
  BriefingSummary briefingType(BriefingSummaryBriefingTypeEnum briefingType);

  BriefingSummary generatedAt(DateTime generatedAt);

  BriefingSummary generation(int generation);

  BriefingSummary id(String id);

  BriefingSummary periodEnd(DateTime periodEnd);

  BriefingSummary periodStart(DateTime periodStart);

  BriefingSummary readAt(DateTime? readAt);

  BriefingSummary sourceSequence(int sourceSequence);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BriefingSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BriefingSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  BriefingSummary call({
    BriefingSummaryBriefingTypeEnum briefingType,
    DateTime generatedAt,
    int generation,
    String id,
    DateTime periodEnd,
    DateTime periodStart,
    DateTime? readAt,
    int sourceSequence,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBriefingSummary.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBriefingSummary.copyWith.fieldName(...)`
class _$BriefingSummaryCWProxyImpl implements _$BriefingSummaryCWProxy {
  const _$BriefingSummaryCWProxyImpl(this._value);

  final BriefingSummary _value;

  @override
  BriefingSummary briefingType(BriefingSummaryBriefingTypeEnum briefingType) =>
      this(briefingType: briefingType);

  @override
  BriefingSummary generatedAt(DateTime generatedAt) =>
      this(generatedAt: generatedAt);

  @override
  BriefingSummary generation(int generation) => this(generation: generation);

  @override
  BriefingSummary id(String id) => this(id: id);

  @override
  BriefingSummary periodEnd(DateTime periodEnd) => this(periodEnd: periodEnd);

  @override
  BriefingSummary periodStart(DateTime periodStart) =>
      this(periodStart: periodStart);

  @override
  BriefingSummary readAt(DateTime? readAt) => this(readAt: readAt);

  @override
  BriefingSummary sourceSequence(int sourceSequence) =>
      this(sourceSequence: sourceSequence);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BriefingSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BriefingSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  BriefingSummary call({
    Object? briefingType = const $CopyWithPlaceholder(),
    Object? generatedAt = const $CopyWithPlaceholder(),
    Object? generation = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? periodEnd = const $CopyWithPlaceholder(),
    Object? periodStart = const $CopyWithPlaceholder(),
    Object? readAt = const $CopyWithPlaceholder(),
    Object? sourceSequence = const $CopyWithPlaceholder(),
  }) {
    return BriefingSummary(
      briefingType: briefingType == const $CopyWithPlaceholder()
          ? _value.briefingType
          // ignore: cast_nullable_to_non_nullable
          : briefingType as BriefingSummaryBriefingTypeEnum,
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

extension $BriefingSummaryCopyWith on BriefingSummary {
  /// Returns a callable class that can be used as follows: `instanceOfBriefingSummary.copyWith(...)` or like so:`instanceOfBriefingSummary.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BriefingSummaryCWProxy get copyWith => _$BriefingSummaryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BriefingSummary _$BriefingSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'BriefingSummary',
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
        final val = BriefingSummary(
          briefingType: $checkedConvert(
            'briefing_type',
            (v) => $enumDecode(
              _$BriefingSummaryBriefingTypeEnumEnumMap,
              v,
              unknownValue:
                  BriefingSummaryBriefingTypeEnum.unknownDefaultOpenApi,
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

Map<String, dynamic> _$BriefingSummaryToJson(BriefingSummary instance) =>
    <String, dynamic>{
      'briefing_type':
          _$BriefingSummaryBriefingTypeEnumEnumMap[instance.briefingType]!,
      'generated_at': instance.generatedAt.toIso8601String(),
      'generation': instance.generation,
      'id': instance.id,
      'period_end': instance.periodEnd.toIso8601String(),
      'period_start': instance.periodStart.toIso8601String(),
      'read_at': instance.readAt?.toIso8601String(),
      'source_sequence': instance.sourceSequence,
    };

const _$BriefingSummaryBriefingTypeEnumEnumMap = {
  BriefingSummaryBriefingTypeEnum.daily: 'daily',
  BriefingSummaryBriefingTypeEnum.weekly: 'weekly',
  BriefingSummaryBriefingTypeEnum.moonCycle: 'moon_cycle',
  BriefingSummaryBriefingTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
