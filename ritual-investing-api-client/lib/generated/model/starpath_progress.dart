//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'starpath_progress.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StarpathProgress {
  /// Returns a new [StarpathProgress] instance.
  StarpathProgress({
    required this.currentNodeOrdinal,

    required this.updatedAt,

    required this.version,
  });

  // minimum: 1
  // maximum: 9
  @JsonKey(name: r'current_node_ordinal', required: true, includeIfNull: false)
  final int currentNodeOrdinal;

  @JsonKey(name: r'updated_at', required: true, includeIfNull: false)
  final DateTime updatedAt;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarpathProgress &&
          other.currentNodeOrdinal == currentNodeOrdinal &&
          other.updatedAt == updatedAt &&
          other.version == version;

  @override
  int get hashCode =>
      currentNodeOrdinal.hashCode + updatedAt.hashCode + version.hashCode;

  factory StarpathProgress.fromJson(Map<String, dynamic> json) =>
      _$StarpathProgressFromJson(json);

  Map<String, dynamic> toJson() => _$StarpathProgressToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
