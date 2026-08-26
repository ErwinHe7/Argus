//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_admin_asset_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchAdminAssetRequest {
  /// Returns a new [PatchAdminAssetRequest] instance.
  PatchAdminAssetRequest({
    this.assetType,

    this.currency,

    this.exchange,

    this.name,

    this.status,

    this.symbol,
  });

  /// Demo asset type: equity, etf, index, or cash.
  @JsonKey(name: r'asset_type', required: false, includeIfNull: false)
  final String? assetType;

  @JsonKey(
    name: r'currency',
    required: false,
    includeIfNull: false,
    unknownEnumValue: PatchAdminAssetRequestCurrencyEnum.unknownDefaultOpenApi,
  )
  final PatchAdminAssetRequestCurrencyEnum? currency;

  @JsonKey(name: r'exchange', required: false, includeIfNull: false)
  final String? exchange;

  @JsonKey(name: r'name', required: false, includeIfNull: false)
  final String? name;

  @JsonKey(
    name: r'status',
    required: false,
    includeIfNull: false,
    unknownEnumValue: PatchAdminAssetRequestStatusEnum.unknownDefaultOpenApi,
  )
  final PatchAdminAssetRequestStatusEnum? status;

  @JsonKey(name: r'symbol', required: false, includeIfNull: false)
  final String? symbol;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchAdminAssetRequest &&
          other.assetType == assetType &&
          other.currency == currency &&
          other.exchange == exchange &&
          other.name == name &&
          other.status == status &&
          other.symbol == symbol;

  @override
  int get hashCode =>
      assetType.hashCode +
      currency.hashCode +
      (exchange == null ? 0 : exchange.hashCode) +
      name.hashCode +
      status.hashCode +
      symbol.hashCode;

  factory PatchAdminAssetRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchAdminAssetRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchAdminAssetRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PatchAdminAssetRequestCurrencyEnum {
  @JsonValue(r'USD')
  USD(r'USD'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PatchAdminAssetRequestCurrencyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum PatchAdminAssetRequestStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'inactive')
  inactive(r'inactive'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PatchAdminAssetRequestStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
