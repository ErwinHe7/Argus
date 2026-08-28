//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_admin_editorial_revision_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateAdminEditorialRevisionRequest {
  /// Returns a new [CreateAdminEditorialRevisionRequest] instance.
  CreateAdminEditorialRevisionRequest({required this.payload});

  @JsonKey(name: r'payload', required: true, includeIfNull: false)
  final Map<String, Object?> payload;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateAdminEditorialRevisionRequest && other.payload == payload;

  @override
  int get hashCode => payload.hashCode;

  factory CreateAdminEditorialRevisionRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateAdminEditorialRevisionRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateAdminEditorialRevisionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
