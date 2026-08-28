//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'put_circle_asset_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PutCircleAssetRequest {
  /// Returns a new [PutCircleAssetRequest] instance.
  PutCircleAssetRequest({this.note, required this.ordinal, this.weightBps});

  @JsonKey(name: r'note', required: false, includeIfNull: false)
  final String? note;

  // minimum: 1
  // maximum: 50
  @JsonKey(name: r'ordinal', required: true, includeIfNull: false)
  final int ordinal;

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'weightBps', required: false, includeIfNull: false)
  final int? weightBps;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PutCircleAssetRequest &&
          other.note == note &&
          other.ordinal == ordinal &&
          other.weightBps == weightBps;

  @override
  int get hashCode =>
      (note == null ? 0 : note.hashCode) +
      ordinal.hashCode +
      (weightBps == null ? 0 : weightBps.hashCode);

  factory PutCircleAssetRequest.fromJson(Map<String, dynamic> json) =>
      _$PutCircleAssetRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PutCircleAssetRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
