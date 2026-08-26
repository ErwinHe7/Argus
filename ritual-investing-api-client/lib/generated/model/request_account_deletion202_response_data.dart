//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'request_account_deletion202_response_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RequestAccountDeletion202ResponseData {
  /// Returns a new [RequestAccountDeletion202ResponseData] instance.
  RequestAccountDeletion202ResponseData({
    required this.effectiveAt,

    required this.purgeBy,

    required this.purgeGeneration,

    required this.requestId,

    required this.status,

    required this.tombstoneId,
  });

  @JsonKey(name: r'effective_at', required: true, includeIfNull: false)
  final DateTime effectiveAt;

  @JsonKey(name: r'purge_by', required: true, includeIfNull: false)
  final DateTime purgeBy;

  // minimum: 0
  @JsonKey(name: r'purge_generation', required: true, includeIfNull: false)
  final int purgeGeneration;

  @JsonKey(name: r'request_id', required: true, includeIfNull: false)
  final String requestId;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        RequestAccountDeletion202ResponseDataStatusEnum.unknownDefaultOpenApi,
  )
  final RequestAccountDeletion202ResponseDataStatusEnum status;

  @JsonKey(name: r'tombstone_id', required: true, includeIfNull: false)
  final String tombstoneId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestAccountDeletion202ResponseData &&
          other.effectiveAt == effectiveAt &&
          other.purgeBy == purgeBy &&
          other.purgeGeneration == purgeGeneration &&
          other.requestId == requestId &&
          other.status == status &&
          other.tombstoneId == tombstoneId;

  @override
  int get hashCode =>
      effectiveAt.hashCode +
      purgeBy.hashCode +
      purgeGeneration.hashCode +
      requestId.hashCode +
      status.hashCode +
      tombstoneId.hashCode;

  factory RequestAccountDeletion202ResponseData.fromJson(
    Map<String, dynamic> json,
  ) => _$RequestAccountDeletion202ResponseDataFromJson(json);

  Map<String, dynamic> toJson() =>
      _$RequestAccountDeletion202ResponseDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RequestAccountDeletion202ResponseDataStatusEnum {
  @JsonValue(r'queued')
  queued(r'queued'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RequestAccountDeletion202ResponseDataStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
