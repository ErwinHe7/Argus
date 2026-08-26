//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/simulation_demo_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/create_future_mirror_request.dart';
import 'package:ritual_investing_api_client/generated/model/future_mirror_view_points_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'future_mirror_view.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FutureMirrorView {
  /// Returns a new [FutureMirrorView] instance.
  FutureMirrorView({
    required this.assumptions,

    required this.demo,

    required this.generatedAt,

    required this.id,

    required this.inputHash,

    required this.intentionId,

    required this.ledgerWatermark,

    required this.modelVersion,

    required this.points,

    required this.uncertainty,
  });

  @JsonKey(name: r'assumptions', required: true, includeIfNull: false)
  final CreateFutureMirrorRequest assumptions;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final SimulationDemoDisclosure demo;

  @JsonKey(name: r'generated_at', required: true, includeIfNull: false)
  final DateTime generatedAt;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'input_hash', required: true, includeIfNull: false)
  final String inputHash;

  @JsonKey(name: r'intention_id', required: true, includeIfNull: false)
  final String intentionId;

  // minimum: 0
  @JsonKey(name: r'ledger_watermark', required: true, includeIfNull: false)
  final int ledgerWatermark;

  @JsonKey(
    name: r'model_version',
    required: true,
    includeIfNull: false,
    unknownEnumValue: FutureMirrorViewModelVersionEnum.unknownDefaultOpenApi,
  )
  final FutureMirrorViewModelVersionEnum modelVersion;

  @JsonKey(name: r'points', required: true, includeIfNull: false)
  final List<FutureMirrorViewPointsInner> points;

  @JsonKey(name: r'uncertainty', required: true, includeIfNull: false)
  final String uncertainty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FutureMirrorView &&
          other.assumptions == assumptions &&
          other.demo == demo &&
          other.generatedAt == generatedAt &&
          other.id == id &&
          other.inputHash == inputHash &&
          other.intentionId == intentionId &&
          other.ledgerWatermark == ledgerWatermark &&
          other.modelVersion == modelVersion &&
          other.points == points &&
          other.uncertainty == uncertainty;

  @override
  int get hashCode =>
      assumptions.hashCode +
      demo.hashCode +
      generatedAt.hashCode +
      id.hashCode +
      inputHash.hashCode +
      intentionId.hashCode +
      ledgerWatermark.hashCode +
      modelVersion.hashCode +
      points.hashCode +
      uncertainty.hashCode;

  factory FutureMirrorView.fromJson(Map<String, dynamic> json) =>
      _$FutureMirrorViewFromJson(json);

  Map<String, dynamic> toJson() => _$FutureMirrorViewToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum FutureMirrorViewModelVersionEnum {
  @JsonValue(r'ritual-demo-v1')
  ritualDemoV1(r'ritual-demo-v1'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const FutureMirrorViewModelVersionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
