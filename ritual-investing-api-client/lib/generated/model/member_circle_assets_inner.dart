//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'member_circle_assets_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemberCircleAssetsInner {
  /// Returns a new [MemberCircleAssetsInner] instance.
  MemberCircleAssetsInner({
    required this.assetId,

    required this.id,

    required this.note,

    required this.ordinal,

    required this.weightBps,
  });

  @JsonKey(name: r'asset_id', required: true, includeIfNull: false)
  final String assetId;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'note', required: true, includeIfNull: true)
  final String? note;

  // minimum: 0
  @JsonKey(name: r'ordinal', required: true, includeIfNull: false)
  final int ordinal;

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'weight_bps', required: true, includeIfNull: true)
  final int? weightBps;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberCircleAssetsInner &&
          other.assetId == assetId &&
          other.id == id &&
          other.note == note &&
          other.ordinal == ordinal &&
          other.weightBps == weightBps;

  @override
  int get hashCode =>
      assetId.hashCode +
      id.hashCode +
      (note == null ? 0 : note.hashCode) +
      ordinal.hashCode +
      (weightBps == null ? 0 : weightBps.hashCode);

  factory MemberCircleAssetsInner.fromJson(Map<String, dynamic> json) =>
      _$MemberCircleAssetsInnerFromJson(json);

  Map<String, dynamic> toJson() => _$MemberCircleAssetsInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
