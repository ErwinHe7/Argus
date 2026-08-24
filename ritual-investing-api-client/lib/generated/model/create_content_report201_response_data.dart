//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_content_report201_response_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateContentReport201ResponseData {
  /// Returns a new [CreateContentReport201ResponseData] instance.
  CreateContentReport201ResponseData({required this.id, required this.status});

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CreateContentReport201ResponseDataStatusEnum.unknownDefaultOpenApi,
  )
  final CreateContentReport201ResponseDataStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateContentReport201ResponseData &&
          other.id == id &&
          other.status == status;

  @override
  int get hashCode => id.hashCode + status.hashCode;

  factory CreateContentReport201ResponseData.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateContentReport201ResponseDataFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateContentReport201ResponseDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateContentReport201ResponseDataStatusEnum {
  @JsonValue(r'received')
  received(r'received'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateContentReport201ResponseDataStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
