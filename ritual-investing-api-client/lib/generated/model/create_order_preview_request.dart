//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/positive_input_money.dart';
import 'package:ritual_investing_api_client/generated/model/quantity.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_order_preview_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateOrderPreviewRequest {
  /// Returns a new [CreateOrderPreviewRequest] instance.
  CreateOrderPreviewRequest({
    required this.assetId,

    this.notional,

    this.quantity,

    required this.side,
  });

  @JsonKey(name: r'asset_id', required: true, includeIfNull: false)
  final String assetId;

  @JsonKey(name: r'notional', required: false, includeIfNull: false)
  final PositiveInputMoney? notional;

  @JsonKey(name: r'quantity', required: false, includeIfNull: false)
  final Quantity? quantity;

  @JsonKey(
    name: r'side',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CreateOrderPreviewRequestSideEnum.unknownDefaultOpenApi,
  )
  final CreateOrderPreviewRequestSideEnum side;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateOrderPreviewRequest &&
          other.assetId == assetId &&
          other.notional == notional &&
          other.quantity == quantity &&
          other.side == side;

  @override
  int get hashCode =>
      assetId.hashCode + notional.hashCode + quantity.hashCode + side.hashCode;

  factory CreateOrderPreviewRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateOrderPreviewRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateOrderPreviewRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateOrderPreviewRequestSideEnum {
  @JsonValue(r'buy')
  buy(r'buy'),
  @JsonValue(r'sell')
  sell(r'sell'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateOrderPreviewRequestSideEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
