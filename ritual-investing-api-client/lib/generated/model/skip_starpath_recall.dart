//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'skip_starpath_recall.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SkipStarpathRecall {
  /// Returns a new [SkipStarpathRecall] instance.
  SkipStarpathRecall({required this.sessionId});

  @JsonKey(name: r'session_id', required: true, includeIfNull: false)
  final String sessionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkipStarpathRecall && other.sessionId == sessionId;

  @override
  int get hashCode => sessionId.hashCode;

  factory SkipStarpathRecall.fromJson(Map<String, dynamic> json) =>
      _$SkipStarpathRecallFromJson(json);

  Map<String, dynamic> toJson() => _$SkipStarpathRecallToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
