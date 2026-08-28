// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'briefing_detail.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BriefingDetailCWProxy {
  BriefingDetail briefingType(BriefingDetailBriefingTypeEnum briefingType);

  BriefingDetail generatedAt(DateTime generatedAt);

  BriefingDetail generation(int generation);

  BriefingDetail id(String id);

  BriefingDetail periodEnd(DateTime periodEnd);

  BriefingDetail periodStart(DateTime periodStart);

  BriefingDetail readAt(DateTime? readAt);

  BriefingDetail sections(List<BriefingSection> sections);

  BriefingDetail sourceSequence(int sourceSequence);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BriefingDetail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BriefingDetail(...).copyWith(id: 12, name: "My name")
  /// ````
  BriefingDetail call({
    BriefingDetailBriefingTypeEnum briefingType,
    DateTime generatedAt,
    int generation,
    String id,
    DateTime periodEnd,
    DateTime periodStart,
    DateTime? readAt,
    List<BriefingSection> sections,
    int sourceSequence,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBriefingDetail.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBriefingDetail.copyWith.fieldName(...)`
class _$BriefingDetailCWProxyImpl implements _$BriefingDetailCWProxy {
  const _$BriefingDetailCWProxyImpl(this._value);

  final BriefingDetail _value;

  @override
  BriefingDetail briefingType(BriefingDetailBriefingTypeEnum briefingType) =>
      this(briefingType: briefingType);

  @override
  BriefingDetail generatedAt(DateTime generatedAt) =>
      this(generatedAt: generatedAt);

  @override
  BriefingDetail generation(int generation) => this(generation: generation);

  @override
  BriefingDetail id(String id) => this(id: id);

  @override
  BriefingDetail periodEnd(DateTime periodEnd) => this(periodEnd: periodEnd);

  @override
  BriefingDetail periodStart(DateTime periodStart) =>
      this(periodStart: periodStart);

  @override
  BriefingDetail readAt(DateTime? readAt) => this(readAt: readAt);

  @override
  BriefingDetail sections(List<BriefingSection> sections) =>
      this(sections: sections);

  @override
  BriefingDetail sourceSequence(int sourceSequence) =>
      this(sourceSequence: sourceSequence);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BriefingDetail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BriefingDetail(...).copyWith(id: 12, name: "My name")
  /// ````
  BriefingDetail call({
    Object? briefingType = const $CopyWithPlaceholder(),
    Object? generatedAt = const $CopyWithPlaceholder(),
    Object? generation = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? periodEnd = const $CopyWithPlaceholder(),
    Object? periodStart = const $CopyWithPlaceholder(),
    Object? readAt = const $CopyWithPlaceholder(),
    Object? sections = const $CopyWithPlaceholder(),
    Object? sourceSequence = const $CopyWithPlaceholder(),
  }) {
    return BriefingDetail(
      briefingType: briefingType == const $CopyWithPlaceholder()
          ? _value.briefingType
          // ignore: cast_nullable_to_non_nullable
          : briefingType as BriefingDetailBriefingTypeEnum,
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
      sections: sections == const $CopyWithPlaceholder()
          ? _value.sections
          // ignore: cast_nullable_to_non_nullable
          : sections as List<BriefingSection>,
      sourceSequence: sourceSequence == const $CopyWithPlaceholder()
          ? _value.sourceSequence
          // ignore: cast_nullable_to_non_nullable
          : sourceSequence as int,
    );
  }
}

extension $BriefingDetailCopyWith on BriefingDetail {
  /// Returns a callable class that can be used as follows: `instanceOfBriefingDetail.copyWith(...)` or like so:`instanceOfBriefingDetail.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BriefingDetailCWProxy get copyWith => _$BriefingDetailCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BriefingDetail _$BriefingDetailFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'BriefingDetail',
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
            'sections',
            'source_sequence',
          ],
        );
        final val = BriefingDetail(
          briefingType: $checkedConvert(
            'briefing_type',
            (v) => $enumDecode(
              _$BriefingDetailBriefingTypeEnumEnumMap,
              v,
              unknownValue:
                  BriefingDetailBriefingTypeEnum.unknownDefaultOpenApi,
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
          sections: $checkedConvert(
            'sections',
            (v) => (v as List<dynamic>)
                .map((e) => BriefingSection.fromJson(e as Map<String, dynamic>))
                .toList(),
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

Map<String, dynamic> _$BriefingDetailToJson(BriefingDetail instance) =>
    <String, dynamic>{
      'briefing_type':
          _$BriefingDetailBriefingTypeEnumEnumMap[instance.briefingType]!,
      'generated_at': instance.generatedAt.toIso8601String(),
      'generation': instance.generation,
      'id': instance.id,
      'period_end': instance.periodEnd.toIso8601String(),
      'period_start': instance.periodStart.toIso8601String(),
      'read_at': instance.readAt?.toIso8601String(),
      'sections': instance.sections.map((e) => e.toJson()).toList(),
      'source_sequence': instance.sourceSequence,
    };

const _$BriefingDetailBriefingTypeEnumEnumMap = {
  BriefingDetailBriefingTypeEnum.daily: 'daily',
  BriefingDetailBriefingTypeEnum.weekly: 'weekly',
  BriefingDetailBriefingTypeEnum.moonCycle: 'moon_cycle',
  BriefingDetailBriefingTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
