//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'get_daily_briefing202_response_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GetDailyBriefing202ResponseData {
  /// Returns a new [GetDailyBriefing202ResponseData] instance.
  GetDailyBriefing202ResponseData({
    required this.localDate,

    required this.status,
  });

  @JsonKey(name: r'local_date', required: true, includeIfNull: false)
  final DateTime localDate;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        GetDailyBriefing202ResponseDataStatusEnum.unknownDefaultOpenApi,
  )
  final GetDailyBriefing202ResponseDataStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GetDailyBriefing202ResponseData &&
          other.localDate == localDate &&
          other.status == status;

  @override
  int get hashCode => localDate.hashCode + status.hashCode;

  factory GetDailyBriefing202ResponseData.fromJson(Map<String, dynamic> json) =>
      _$GetDailyBriefing202ResponseDataFromJson(json);

  Map<String, dynamic> toJson() =>
      _$GetDailyBriefing202ResponseDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum GetDailyBriefing202ResponseDataStatusEnum {
  @JsonValue(r'briefing_pending')
  briefingPending(r'briefing_pending'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const GetDailyBriefing202ResponseDataStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
