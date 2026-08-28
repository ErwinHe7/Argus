//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'briefing_pending.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BriefingPending {
  /// Returns a new [BriefingPending] instance.
  BriefingPending({required this.localDate, required this.status});

  @JsonKey(name: r'local_date', required: true, includeIfNull: false)
  final DateTime localDate;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BriefingPendingStatusEnum.unknownDefaultOpenApi,
  )
  final BriefingPendingStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BriefingPending &&
          other.localDate == localDate &&
          other.status == status;

  @override
  int get hashCode => localDate.hashCode + status.hashCode;

  factory BriefingPending.fromJson(Map<String, dynamic> json) =>
      _$BriefingPendingFromJson(json);

  Map<String, dynamic> toJson() => _$BriefingPendingToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BriefingPendingStatusEnum {
  @JsonValue(r'briefing_pending')
  briefingPending(r'briefing_pending'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BriefingPendingStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
