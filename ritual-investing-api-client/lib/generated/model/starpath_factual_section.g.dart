// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'starpath_factual_section.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$StarpathFactualSectionCWProxy {
  StarpathFactualSection body(String body);

  StarpathFactualSection evidence(List<StarpathEvidence> evidence);

  StarpathFactualSection heading(String heading);

  StarpathFactualSection kind(StarpathFactualSectionKindEnum kind);

  StarpathFactualSection observedAt(DateTime observedAt);

  StarpathFactualSection ordinal(int ordinal);

  StarpathFactualSection uncertainty(String uncertainty);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathFactualSection(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathFactualSection(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathFactualSection call({
    String body,
    List<StarpathEvidence> evidence,
    String heading,
    StarpathFactualSectionKindEnum kind,
    DateTime observedAt,
    int ordinal,
    String uncertainty,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfStarpathFactualSection.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfStarpathFactualSection.copyWith.fieldName(...)`
class _$StarpathFactualSectionCWProxyImpl
    implements _$StarpathFactualSectionCWProxy {
  const _$StarpathFactualSectionCWProxyImpl(this._value);

  final StarpathFactualSection _value;

  @override
  StarpathFactualSection body(String body) => this(body: body);

  @override
  StarpathFactualSection evidence(List<StarpathEvidence> evidence) =>
      this(evidence: evidence);

  @override
  StarpathFactualSection heading(String heading) => this(heading: heading);

  @override
  StarpathFactualSection kind(StarpathFactualSectionKindEnum kind) =>
      this(kind: kind);

  @override
  StarpathFactualSection observedAt(DateTime observedAt) =>
      this(observedAt: observedAt);

  @override
  StarpathFactualSection ordinal(int ordinal) => this(ordinal: ordinal);

  @override
  StarpathFactualSection uncertainty(String uncertainty) =>
      this(uncertainty: uncertainty);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathFactualSection(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathFactualSection(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathFactualSection call({
    Object? body = const $CopyWithPlaceholder(),
    Object? evidence = const $CopyWithPlaceholder(),
    Object? heading = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
    Object? observedAt = const $CopyWithPlaceholder(),
    Object? ordinal = const $CopyWithPlaceholder(),
    Object? uncertainty = const $CopyWithPlaceholder(),
  }) {
    return StarpathFactualSection(
      body: body == const $CopyWithPlaceholder()
          ? _value.body
          // ignore: cast_nullable_to_non_nullable
          : body as String,
      evidence: evidence == const $CopyWithPlaceholder()
          ? _value.evidence
          // ignore: cast_nullable_to_non_nullable
          : evidence as List<StarpathEvidence>,
      heading: heading == const $CopyWithPlaceholder()
          ? _value.heading
          // ignore: cast_nullable_to_non_nullable
          : heading as String,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as StarpathFactualSectionKindEnum,
      observedAt: observedAt == const $CopyWithPlaceholder()
          ? _value.observedAt
          // ignore: cast_nullable_to_non_nullable
          : observedAt as DateTime,
      ordinal: ordinal == const $CopyWithPlaceholder()
          ? _value.ordinal
          // ignore: cast_nullable_to_non_nullable
          : ordinal as int,
      uncertainty: uncertainty == const $CopyWithPlaceholder()
          ? _value.uncertainty
          // ignore: cast_nullable_to_non_nullable
          : uncertainty as String,
    );
  }
}

extension $StarpathFactualSectionCopyWith on StarpathFactualSection {
  /// Returns a callable class that can be used as follows: `instanceOfStarpathFactualSection.copyWith(...)` or like so:`instanceOfStarpathFactualSection.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$StarpathFactualSectionCWProxy get copyWith =>
      _$StarpathFactualSectionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StarpathFactualSection _$StarpathFactualSectionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('StarpathFactualSection', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'body',
      'evidence',
      'heading',
      'kind',
      'observed_at',
      'ordinal',
      'uncertainty',
    ],
  );
  final val = StarpathFactualSection(
    body: $checkedConvert('body', (v) => v as String),
    evidence: $checkedConvert(
      'evidence',
      (v) => (v as List<dynamic>)
          .map((e) => StarpathEvidence.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    heading: $checkedConvert('heading', (v) => v as String),
    kind: $checkedConvert(
      'kind',
      (v) => $enumDecode(
        _$StarpathFactualSectionKindEnumEnumMap,
        v,
        unknownValue: StarpathFactualSectionKindEnum.unknownDefaultOpenApi,
      ),
    ),
    observedAt: $checkedConvert(
      'observed_at',
      (v) => DateTime.parse(v as String),
    ),
    ordinal: $checkedConvert('ordinal', (v) => (v as num).toInt()),
    uncertainty: $checkedConvert('uncertainty', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'observedAt': 'observed_at'});

Map<String, dynamic> _$StarpathFactualSectionToJson(
  StarpathFactualSection instance,
) => <String, dynamic>{
  'body': instance.body,
  'evidence': instance.evidence.map((e) => e.toJson()).toList(),
  'heading': instance.heading,
  'kind': _$StarpathFactualSectionKindEnumEnumMap[instance.kind]!,
  'observed_at': instance.observedAt.toIso8601String(),
  'ordinal': instance.ordinal,
  'uncertainty': instance.uncertainty,
};

const _$StarpathFactualSectionKindEnumEnumMap = {
  StarpathFactualSectionKindEnum.fact: 'fact',
  StarpathFactualSectionKindEnum.neutralExample: 'neutral_example',
  StarpathFactualSectionKindEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
