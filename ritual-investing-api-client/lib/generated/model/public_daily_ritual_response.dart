//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/daily_ritual_preview.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'public_daily_ritual_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PublicDailyRitualResponse {
  /// Returns a new [PublicDailyRitualResponse] instance.
  PublicDailyRitualResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final DailyRitualPreview data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicDailyRitualResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory PublicDailyRitualResponse.fromJson(Map<String, dynamic> json) =>
      _$PublicDailyRitualResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PublicDailyRitualResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
