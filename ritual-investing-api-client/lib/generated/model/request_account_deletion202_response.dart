//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/request_account_deletion202_response_data.dart';
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'request_account_deletion202_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RequestAccountDeletion202Response {
  /// Returns a new [RequestAccountDeletion202Response] instance.
  RequestAccountDeletion202Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final RequestAccountDeletion202ResponseData data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestAccountDeletion202Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory RequestAccountDeletion202Response.fromJson(
    Map<String, dynamic> json,
  ) => _$RequestAccountDeletion202ResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$RequestAccountDeletion202ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
