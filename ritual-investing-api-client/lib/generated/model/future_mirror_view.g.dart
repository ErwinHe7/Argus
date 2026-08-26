// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'future_mirror_view.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FutureMirrorViewCWProxy {
  FutureMirrorView assumptions(CreateFutureMirrorRequest assumptions);

  FutureMirrorView demo(SimulationDemoDisclosure demo);

  FutureMirrorView generatedAt(DateTime generatedAt);

  FutureMirrorView id(String id);

  FutureMirrorView inputHash(String inputHash);

  FutureMirrorView intentionId(String intentionId);

  FutureMirrorView ledgerWatermark(int ledgerWatermark);

  FutureMirrorView modelVersion(FutureMirrorViewModelVersionEnum modelVersion);

  FutureMirrorView points(List<FutureMirrorViewPointsInner> points);

  FutureMirrorView uncertainty(String uncertainty);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FutureMirrorView(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FutureMirrorView(...).copyWith(id: 12, name: "My name")
  /// ````
  FutureMirrorView call({
    CreateFutureMirrorRequest assumptions,
    SimulationDemoDisclosure demo,
    DateTime generatedAt,
    String id,
    String inputHash,
    String intentionId,
    int ledgerWatermark,
    FutureMirrorViewModelVersionEnum modelVersion,
    List<FutureMirrorViewPointsInner> points,
    String uncertainty,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFutureMirrorView.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFutureMirrorView.copyWith.fieldName(...)`
class _$FutureMirrorViewCWProxyImpl implements _$FutureMirrorViewCWProxy {
  const _$FutureMirrorViewCWProxyImpl(this._value);

  final FutureMirrorView _value;

  @override
  FutureMirrorView assumptions(CreateFutureMirrorRequest assumptions) =>
      this(assumptions: assumptions);

  @override
  FutureMirrorView demo(SimulationDemoDisclosure demo) => this(demo: demo);

  @override
  FutureMirrorView generatedAt(DateTime generatedAt) =>
      this(generatedAt: generatedAt);

  @override
  FutureMirrorView id(String id) => this(id: id);

  @override
  FutureMirrorView inputHash(String inputHash) => this(inputHash: inputHash);

  @override
  FutureMirrorView intentionId(String intentionId) =>
      this(intentionId: intentionId);

  @override
  FutureMirrorView ledgerWatermark(int ledgerWatermark) =>
      this(ledgerWatermark: ledgerWatermark);

  @override
  FutureMirrorView modelVersion(
    FutureMirrorViewModelVersionEnum modelVersion,
  ) => this(modelVersion: modelVersion);

  @override
  FutureMirrorView points(List<FutureMirrorViewPointsInner> points) =>
      this(points: points);

  @override
  FutureMirrorView uncertainty(String uncertainty) =>
      this(uncertainty: uncertainty);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FutureMirrorView(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FutureMirrorView(...).copyWith(id: 12, name: "My name")
  /// ````
  FutureMirrorView call({
    Object? assumptions = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? generatedAt = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? inputHash = const $CopyWithPlaceholder(),
    Object? intentionId = const $CopyWithPlaceholder(),
    Object? ledgerWatermark = const $CopyWithPlaceholder(),
    Object? modelVersion = const $CopyWithPlaceholder(),
    Object? points = const $CopyWithPlaceholder(),
    Object? uncertainty = const $CopyWithPlaceholder(),
  }) {
    return FutureMirrorView(
      assumptions: assumptions == const $CopyWithPlaceholder()
          ? _value.assumptions
          // ignore: cast_nullable_to_non_nullable
          : assumptions as CreateFutureMirrorRequest,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as SimulationDemoDisclosure,
      generatedAt: generatedAt == const $CopyWithPlaceholder()
          ? _value.generatedAt
          // ignore: cast_nullable_to_non_nullable
          : generatedAt as DateTime,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      inputHash: inputHash == const $CopyWithPlaceholder()
          ? _value.inputHash
          // ignore: cast_nullable_to_non_nullable
          : inputHash as String,
      intentionId: intentionId == const $CopyWithPlaceholder()
          ? _value.intentionId
          // ignore: cast_nullable_to_non_nullable
          : intentionId as String,
      ledgerWatermark: ledgerWatermark == const $CopyWithPlaceholder()
          ? _value.ledgerWatermark
          // ignore: cast_nullable_to_non_nullable
          : ledgerWatermark as int,
      modelVersion: modelVersion == const $CopyWithPlaceholder()
          ? _value.modelVersion
          // ignore: cast_nullable_to_non_nullable
          : modelVersion as FutureMirrorViewModelVersionEnum,
      points: points == const $CopyWithPlaceholder()
          ? _value.points
          // ignore: cast_nullable_to_non_nullable
          : points as List<FutureMirrorViewPointsInner>,
      uncertainty: uncertainty == const $CopyWithPlaceholder()
          ? _value.uncertainty
          // ignore: cast_nullable_to_non_nullable
          : uncertainty as String,
    );
  }
}

extension $FutureMirrorViewCopyWith on FutureMirrorView {
  /// Returns a callable class that can be used as follows: `instanceOfFutureMirrorView.copyWith(...)` or like so:`instanceOfFutureMirrorView.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FutureMirrorViewCWProxy get copyWith => _$FutureMirrorViewCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FutureMirrorView _$FutureMirrorViewFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'FutureMirrorView',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'assumptions',
            'demo',
            'generated_at',
            'id',
            'input_hash',
            'intention_id',
            'ledger_watermark',
            'model_version',
            'points',
            'uncertainty',
          ],
        );
        final val = FutureMirrorView(
          assumptions: $checkedConvert(
            'assumptions',
            (v) =>
                CreateFutureMirrorRequest.fromJson(v as Map<String, dynamic>),
          ),
          demo: $checkedConvert(
            'demo',
            (v) => SimulationDemoDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          generatedAt: $checkedConvert(
            'generated_at',
            (v) => DateTime.parse(v as String),
          ),
          id: $checkedConvert('id', (v) => v as String),
          inputHash: $checkedConvert('input_hash', (v) => v as String),
          intentionId: $checkedConvert('intention_id', (v) => v as String),
          ledgerWatermark: $checkedConvert(
            'ledger_watermark',
            (v) => (v as num).toInt(),
          ),
          modelVersion: $checkedConvert(
            'model_version',
            (v) => $enumDecode(
              _$FutureMirrorViewModelVersionEnumEnumMap,
              v,
              unknownValue:
                  FutureMirrorViewModelVersionEnum.unknownDefaultOpenApi,
            ),
          ),
          points: $checkedConvert(
            'points',
            (v) => (v as List<dynamic>)
                .map(
                  (e) => FutureMirrorViewPointsInner.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList(),
          ),
          uncertainty: $checkedConvert('uncertainty', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'generatedAt': 'generated_at',
        'inputHash': 'input_hash',
        'intentionId': 'intention_id',
        'ledgerWatermark': 'ledger_watermark',
        'modelVersion': 'model_version',
      },
    );

Map<String, dynamic> _$FutureMirrorViewToJson(FutureMirrorView instance) =>
    <String, dynamic>{
      'assumptions': instance.assumptions.toJson(),
      'demo': instance.demo.toJson(),
      'generated_at': instance.generatedAt.toIso8601String(),
      'id': instance.id,
      'input_hash': instance.inputHash,
      'intention_id': instance.intentionId,
      'ledger_watermark': instance.ledgerWatermark,
      'model_version':
          _$FutureMirrorViewModelVersionEnumEnumMap[instance.modelVersion]!,
      'points': instance.points.map((e) => e.toJson()).toList(),
      'uncertainty': instance.uncertainty,
    };

const _$FutureMirrorViewModelVersionEnumEnumMap = {
  FutureMirrorViewModelVersionEnum.ritualDemoV1: 'ritual-demo-v1',
  FutureMirrorViewModelVersionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
