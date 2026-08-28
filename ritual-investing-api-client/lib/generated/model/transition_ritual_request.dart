//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'transition_ritual_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TransitionRitualRequest {
  /// Returns a new [TransitionRitualRequest] instance.
  TransitionRitualRequest({required this.from, required this.to});

  @JsonKey(
    name: r'from',
    required: true,
    includeIfNull: false,
    unknownEnumValue: TransitionRitualRequestFromEnum.unknownDefaultOpenApi,
  )
  final TransitionRitualRequestFromEnum from;

  @JsonKey(
    name: r'to',
    required: true,
    includeIfNull: false,
    unknownEnumValue: TransitionRitualRequestToEnum.unknownDefaultOpenApi,
  )
  final TransitionRitualRequestToEnum to;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransitionRitualRequest && other.from == from && other.to == to;

  @override
  int get hashCode => from.hashCode + to.hashCode;

  factory TransitionRitualRequest.fromJson(Map<String, dynamic> json) =>
      _$TransitionRitualRequestFromJson(json);

  Map<String, dynamic> toJson() => _$TransitionRitualRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum TransitionRitualRequestFromEnum {
  @JsonValue(r'assigned')
  assigned(r'assigned'),
  @JsonValue(r'revealed')
  revealed(r'revealed'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const TransitionRitualRequestFromEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum TransitionRitualRequestToEnum {
  @JsonValue(r'revealed')
  revealed(r'revealed'),
  @JsonValue(r'completed')
  completed(r'completed'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const TransitionRitualRequestToEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
