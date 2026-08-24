//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'admin_session.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AdminSession {
  /// Returns a new [AdminSession] instance.
  AdminSession({required this.displayLabel, required this.staffId});

  @JsonKey(name: r'display_label', required: true, includeIfNull: false)
  final String displayLabel;

  @JsonKey(name: r'staff_id', required: true, includeIfNull: false)
  final String staffId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminSession &&
          other.displayLabel == displayLabel &&
          other.staffId == staffId;

  @override
  int get hashCode => displayLabel.hashCode + staffId.hashCode;

  factory AdminSession.fromJson(Map<String, dynamic> json) =>
      _$AdminSessionFromJson(json);

  Map<String, dynamic> toJson() => _$AdminSessionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
