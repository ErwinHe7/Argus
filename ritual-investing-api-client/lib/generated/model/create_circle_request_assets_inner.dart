//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_circle_request_assets_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateCircleRequestAssetsInner {
  /// Returns a new [CreateCircleRequestAssetsInner] instance.
  CreateCircleRequestAssetsInner({
    required this.assetId,

    this.note,

    required this.ordinal,

    this.weightBps,
  });

  @JsonKey(name: r'asset_id', required: true, includeIfNull: false)
  final String assetId;

  @JsonKey(name: r'note', required: false, includeIfNull: false)
  final String? note;

  // minimum: 1
  // maximum: 50
  @JsonKey(name: r'ordinal', required: true, includeIfNull: false)
  final int ordinal;

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'weight_bps', required: false, includeIfNull: false)
  final int? weightBps;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateCircleRequestAssetsInner &&
          other.assetId == assetId &&
          other.note == note &&
          other.ordinal == ordinal &&
          other.weightBps == weightBps;

  @override
  int get hashCode =>
      assetId.hashCode + note.hashCode + ordinal.hashCode + weightBps.hashCode;

  factory CreateCircleRequestAssetsInner.fromJson(Map<String, dynamic> json) =>
      _$CreateCircleRequestAssetsInnerFromJson(json);

  Map<String, dynamic> toJson() => _$CreateCircleRequestAssetsInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
