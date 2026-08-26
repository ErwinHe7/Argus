//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/demo_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ritual_history_item.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RitualHistoryItem {
  /// Returns a new [RitualHistoryItem] instance.
  RitualHistoryItem({
    required this.assignmentId,

    required this.date,

    required this.demo,

    required this.mode,

    required this.state,

    required this.title,
  });

  @JsonKey(name: r'assignment_id', required: true, includeIfNull: false)
  final String assignmentId;

  @JsonKey(name: r'date', required: true, includeIfNull: false)
  final DateTime date;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final DemoDisclosure demo;

  @JsonKey(
    name: r'mode',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RitualHistoryItemModeEnum.unknownDefaultOpenApi,
  )
  final RitualHistoryItemModeEnum mode;

  @JsonKey(
    name: r'state',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RitualHistoryItemStateEnum.unknownDefaultOpenApi,
  )
  final RitualHistoryItemStateEnum state;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RitualHistoryItem &&
          other.assignmentId == assignmentId &&
          other.date == date &&
          other.demo == demo &&
          other.mode == mode &&
          other.state == state &&
          other.title == title;

  @override
  int get hashCode =>
      assignmentId.hashCode +
      date.hashCode +
      demo.hashCode +
      mode.hashCode +
      state.hashCode +
      title.hashCode;

  factory RitualHistoryItem.fromJson(Map<String, dynamic> json) =>
      _$RitualHistoryItemFromJson(json);

  Map<String, dynamic> toJson() => _$RitualHistoryItemToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RitualHistoryItemModeEnum {
  @JsonValue(r'tarot')
  tarot(r'tarot'),
  @JsonValue(r'astrology')
  astrology(r'astrology'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RitualHistoryItemModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum RitualHistoryItemStateEnum {
  @JsonValue(r'assigned')
  assigned(r'assigned'),
  @JsonValue(r'revealed')
  revealed(r'revealed'),
  @JsonValue(r'completed')
  completed(r'completed'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RitualHistoryItemStateEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
