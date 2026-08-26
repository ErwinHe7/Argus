//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'circle_view_assets_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CircleViewAssetsInner {
  /// Returns a new [CircleViewAssetsInner] instance.
  CircleViewAssetsInner({
    required this.assetId,

    required this.note,

    required this.ordinal,

    required this.weightBps,
  });

  @JsonKey(name: r'asset_id', required: true, includeIfNull: false)
  final String assetId;

  @JsonKey(name: r'note', required: true, includeIfNull: true)
  final String? note;

  // minimum: 1
  // maximum: 50
  @JsonKey(name: r'ordinal', required: true, includeIfNull: false)
  final int ordinal;

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'weight_bps', required: true, includeIfNull: true)
  final int? weightBps;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircleViewAssetsInner &&
          other.assetId == assetId &&
          other.note == note &&
          other.ordinal == ordinal &&
          other.weightBps == weightBps;

  @override
  int get hashCode =>
      assetId.hashCode +
      (note == null ? 0 : note.hashCode) +
      ordinal.hashCode +
      (weightBps == null ? 0 : weightBps.hashCode);

  factory CircleViewAssetsInner.fromJson(Map<String, dynamic> json) =>
      _$CircleViewAssetsInnerFromJson(json);

  Map<String, dynamic> toJson() => _$CircleViewAssetsInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
