//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'save_item_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SaveItemRequest {
  /// Returns a new [SaveItemRequest] instance.
  SaveItemRequest({this.sourceId, this.sourceKind});

  @JsonKey(name: r'source_id', required: false, includeIfNull: false)
  final String? sourceId;

  @JsonKey(
    name: r'source_kind',
    required: false,
    includeIfNull: false,
    unknownEnumValue: SaveItemRequestSourceKindEnum.unknownDefaultOpenApi,
  )
  final SaveItemRequestSourceKindEnum? sourceKind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaveItemRequest &&
          other.sourceId == sourceId &&
          other.sourceKind == sourceKind;

  @override
  int get hashCode =>
      (sourceId == null ? 0 : sourceId.hashCode) + sourceKind.hashCode;

  factory SaveItemRequest.fromJson(Map<String, dynamic> json) =>
      _$SaveItemRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SaveItemRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum SaveItemRequestSourceKindEnum {
  @JsonValue(r'ritual')
  ritual(r'ritual'),
  @JsonValue(r'circle')
  circle(r'circle'),
  @JsonValue(r'discover')
  discover(r'discover'),
  @JsonValue(r'search')
  search(r'search'),
  @JsonValue(r'direct')
  direct(r'direct'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SaveItemRequestSourceKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
