//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'disconnect_webull_connection_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DisconnectWebullConnectionRequest {
  /// Returns a new [DisconnectWebullConnectionRequest] instance.
  DisconnectWebullConnectionRequest({required this.stepUpReceipt});

  @JsonKey(name: r'step_up_receipt', required: true, includeIfNull: false)
  final String stepUpReceipt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisconnectWebullConnectionRequest &&
          other.stepUpReceipt == stepUpReceipt;

  @override
  int get hashCode => stepUpReceipt.hashCode;

  factory DisconnectWebullConnectionRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$DisconnectWebullConnectionRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$DisconnectWebullConnectionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
