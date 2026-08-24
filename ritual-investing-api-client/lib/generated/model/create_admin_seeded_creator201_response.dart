//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/admin_seeded_creator.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_admin_seeded_creator201_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateAdminSeededCreator201Response {
  /// Returns a new [CreateAdminSeededCreator201Response] instance.
  CreateAdminSeededCreator201Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final AdminSeededCreator data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateAdminSeededCreator201Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory CreateAdminSeededCreator201Response.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateAdminSeededCreator201ResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateAdminSeededCreator201ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
