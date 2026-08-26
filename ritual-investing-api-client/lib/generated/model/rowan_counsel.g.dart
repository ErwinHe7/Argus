// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rowan_counsel.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RowanCounselCWProxy {
  RowanCounsel body(String body);

  RowanCounsel riskFooter(String riskFooter);

  RowanCounsel scriptRevisionId(String scriptRevisionId);

  RowanCounsel surface(RowanCounselSurfaceEnum surface);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RowanCounsel(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RowanCounsel(...).copyWith(id: 12, name: "My name")
  /// ````
  RowanCounsel call({
    String body,
    String riskFooter,
    String scriptRevisionId,
    RowanCounselSurfaceEnum surface,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRowanCounsel.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRowanCounsel.copyWith.fieldName(...)`
class _$RowanCounselCWProxyImpl implements _$RowanCounselCWProxy {
  const _$RowanCounselCWProxyImpl(this._value);

  final RowanCounsel _value;

  @override
  RowanCounsel body(String body) => this(body: body);

  @override
  RowanCounsel riskFooter(String riskFooter) => this(riskFooter: riskFooter);

  @override
  RowanCounsel scriptRevisionId(String scriptRevisionId) =>
      this(scriptRevisionId: scriptRevisionId);

  @override
  RowanCounsel surface(RowanCounselSurfaceEnum surface) =>
      this(surface: surface);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RowanCounsel(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RowanCounsel(...).copyWith(id: 12, name: "My name")
  /// ````
  RowanCounsel call({
    Object? body = const $CopyWithPlaceholder(),
    Object? riskFooter = const $CopyWithPlaceholder(),
    Object? scriptRevisionId = const $CopyWithPlaceholder(),
    Object? surface = const $CopyWithPlaceholder(),
  }) {
    return RowanCounsel(
      body: body == const $CopyWithPlaceholder()
          ? _value.body
          // ignore: cast_nullable_to_non_nullable
          : body as String,
      riskFooter: riskFooter == const $CopyWithPlaceholder()
          ? _value.riskFooter
          // ignore: cast_nullable_to_non_nullable
          : riskFooter as String,
      scriptRevisionId: scriptRevisionId == const $CopyWithPlaceholder()
          ? _value.scriptRevisionId
          // ignore: cast_nullable_to_non_nullable
          : scriptRevisionId as String,
      surface: surface == const $CopyWithPlaceholder()
          ? _value.surface
          // ignore: cast_nullable_to_non_nullable
          : surface as RowanCounselSurfaceEnum,
    );
  }
}

extension $RowanCounselCopyWith on RowanCounsel {
  /// Returns a callable class that can be used as follows: `instanceOfRowanCounsel.copyWith(...)` or like so:`instanceOfRowanCounsel.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RowanCounselCWProxy get copyWith => _$RowanCounselCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RowanCounsel _$RowanCounselFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'RowanCounsel',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'body',
            'risk_footer',
            'script_revision_id',
            'surface',
          ],
        );
        final val = RowanCounsel(
          body: $checkedConvert('body', (v) => v as String),
          riskFooter: $checkedConvert('risk_footer', (v) => v as String),
          scriptRevisionId: $checkedConvert(
            'script_revision_id',
            (v) => v as String,
          ),
          surface: $checkedConvert(
            'surface',
            (v) => $enumDecode(
              _$RowanCounselSurfaceEnumEnumMap,
              v,
              unknownValue: RowanCounselSurfaceEnum.unknownDefaultOpenApi,
            ),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'riskFooter': 'risk_footer',
        'scriptRevisionId': 'script_revision_id',
      },
    );

Map<String, dynamic> _$RowanCounselToJson(RowanCounsel instance) =>
    <String, dynamic>{
      'body': instance.body,
      'risk_footer': instance.riskFooter,
      'script_revision_id': instance.scriptRevisionId,
      'surface': _$RowanCounselSurfaceEnumEnumMap[instance.surface]!,
    };

const _$RowanCounselSurfaceEnumEnumMap = {
  RowanCounselSurfaceEnum.dailyRitual: 'daily_ritual',
  RowanCounselSurfaceEnum.evidence: 'evidence',
  RowanCounselSurfaceEnum.assetCodex: 'asset_codex',
  RowanCounselSurfaceEnum.coven: 'coven',
  RowanCounselSurfaceEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
