//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'publish_admin_starpath_manifest_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PublishAdminStarpathManifestRequest {
  /// Returns a new [PublishAdminStarpathManifestRequest] instance.
  PublishAdminStarpathManifestRequest({required this.reason});

  @JsonKey(name: r'reason', required: true, includeIfNull: false)
  final String reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublishAdminStarpathManifestRequest && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  factory PublishAdminStarpathManifestRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$PublishAdminStarpathManifestRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$PublishAdminStarpathManifestRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
