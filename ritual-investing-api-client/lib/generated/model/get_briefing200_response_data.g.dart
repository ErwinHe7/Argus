// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_briefing200_response_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetBriefing200ResponseDataCWProxy {
  GetBriefing200ResponseData briefingType(
    GetBriefing200ResponseDataBriefingTypeEnum briefingType,
  );

  GetBriefing200ResponseData generatedAt(DateTime generatedAt);

  GetBriefing200ResponseData generation(int generation);

  GetBriefing200ResponseData id(String id);

  GetBriefing200ResponseData periodEnd(DateTime periodEnd);

  GetBriefing200ResponseData periodStart(DateTime periodStart);

  GetBriefing200ResponseData readAt(DateTime? readAt);

  GetBriefing200ResponseData sections(
    List<GetBriefing200ResponseDataSectionsInner> sections,
  );

  GetBriefing200ResponseData sourceSequence(int sourceSequence);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetBriefing200ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetBriefing200ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  GetBriefing200ResponseData call({
    GetBriefing200ResponseDataBriefingTypeEnum briefingType,
    DateTime generatedAt,
    int generation,
    String id,
    DateTime periodEnd,
    DateTime periodStart,
    DateTime? readAt,
    List<GetBriefing200ResponseDataSectionsInner> sections,
    int sourceSequence,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetBriefing200ResponseData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetBriefing200ResponseData.copyWith.fieldName(...)`
class _$GetBriefing200ResponseDataCWProxyImpl
    implements _$GetBriefing200ResponseDataCWProxy {
  const _$GetBriefing200ResponseDataCWProxyImpl(this._value);

  final GetBriefing200ResponseData _value;

  @override
  GetBriefing200ResponseData briefingType(
    GetBriefing200ResponseDataBriefingTypeEnum briefingType,
  ) => this(briefingType: briefingType);

  @override
  GetBriefing200ResponseData generatedAt(DateTime generatedAt) =>
      this(generatedAt: generatedAt);

  @override
  GetBriefing200ResponseData generation(int generation) =>
      this(generation: generation);

  @override
  GetBriefing200ResponseData id(String id) => this(id: id);

  @override
  GetBriefing200ResponseData periodEnd(DateTime periodEnd) =>
      this(periodEnd: periodEnd);

  @override
  GetBriefing200ResponseData periodStart(DateTime periodStart) =>
      this(periodStart: periodStart);

  @override
  GetBriefing200ResponseData readAt(DateTime? readAt) => this(readAt: readAt);

  @override
  GetBriefing200ResponseData sections(
    List<GetBriefing200ResponseDataSectionsInner> sections,
  ) => this(sections: sections);

  @override
  GetBriefing200ResponseData sourceSequence(int sourceSequence) =>
      this(sourceSequence: sourceSequence);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetBriefing200ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetBriefing200ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  GetBriefing200ResponseData call({
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
    return GetBriefing200ResponseData(
      briefingType: briefingType == const $CopyWithPlaceholder()
          ? _value.briefingType
          // ignore: cast_nullable_to_non_nullable
          : briefingType as GetBriefing200ResponseDataBriefingTypeEnum,
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
          : sections as List<GetBriefing200ResponseDataSectionsInner>,
      sourceSequence: sourceSequence == const $CopyWithPlaceholder()
          ? _value.sourceSequence
          // ignore: cast_nullable_to_non_nullable
          : sourceSequence as int,
    );
  }
}

extension $GetBriefing200ResponseDataCopyWith on GetBriefing200ResponseData {
  /// Returns a callable class that can be used as follows: `instanceOfGetBriefing200ResponseData.copyWith(...)` or like so:`instanceOfGetBriefing200ResponseData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetBriefing200ResponseDataCWProxy get copyWith =>
      _$GetBriefing200ResponseDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetBriefing200ResponseData _$GetBriefing200ResponseDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'GetBriefing200ResponseData',
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
    final val = GetBriefing200ResponseData(
      briefingType: $checkedConvert(
        'briefing_type',
        (v) => $enumDecode(
          _$GetBriefing200ResponseDataBriefingTypeEnumEnumMap,
          v,
          unknownValue:
              GetBriefing200ResponseDataBriefingTypeEnum.unknownDefaultOpenApi,
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
            .map(
              (e) => GetBriefing200ResponseDataSectionsInner.fromJson(
                e as Map<String, dynamic>,
              ),
            )
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

Map<String, dynamic> _$GetBriefing200ResponseDataToJson(
  GetBriefing200ResponseData instance,
) => <String, dynamic>{
  'briefing_type':
      _$GetBriefing200ResponseDataBriefingTypeEnumEnumMap[instance
          .briefingType]!,
  'generated_at': instance.generatedAt.toIso8601String(),
  'generation': instance.generation,
  'id': instance.id,
  'period_end': instance.periodEnd.toIso8601String(),
  'period_start': instance.periodStart.toIso8601String(),
  'read_at': instance.readAt?.toIso8601String(),
  'sections': instance.sections.map((e) => e.toJson()).toList(),
  'source_sequence': instance.sourceSequence,
};

const _$GetBriefing200ResponseDataBriefingTypeEnumEnumMap = {
  GetBriefing200ResponseDataBriefingTypeEnum.daily: 'daily',
  GetBriefing200ResponseDataBriefingTypeEnum.weekly: 'weekly',
  GetBriefing200ResponseDataBriefingTypeEnum.moonCycle: 'moon_cycle',
  GetBriefing200ResponseDataBriefingTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
