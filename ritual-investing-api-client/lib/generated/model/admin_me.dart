//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'admin_me.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AdminMe {
  /// Returns a new [AdminMe] instance.
  AdminMe({
    required this.displayLabel,

    required this.permissions,

    required this.revocationEpoch,

    required this.staffId,
  });

  @JsonKey(name: r'display_label', required: true, includeIfNull: false)
  final String displayLabel;

  @JsonKey(name: r'permissions', required: true, includeIfNull: false)
  final List<String> permissions;

  // minimum: 0
  @JsonKey(name: r'revocation_epoch', required: true, includeIfNull: false)
  final int revocationEpoch;

  @JsonKey(name: r'staff_id', required: true, includeIfNull: false)
  final String staffId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminMe &&
          other.displayLabel == displayLabel &&
          other.permissions == permissions &&
          other.revocationEpoch == revocationEpoch &&
          other.staffId == staffId;

  @override
  int get hashCode =>
      displayLabel.hashCode +
      permissions.hashCode +
      revocationEpoch.hashCode +
      staffId.hashCode;

  factory AdminMe.fromJson(Map<String, dynamic> json) =>
      _$AdminMeFromJson(json);

  Map<String, dynamic> toJson() => _$AdminMeToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
