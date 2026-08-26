//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_admin_asset_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateAdminAssetRequest {
  /// Returns a new [CreateAdminAssetRequest] instance.
  CreateAdminAssetRequest({
    required this.assetType,

    required this.currency,

    required this.exchange,

    required this.name,

    required this.slug,

    required this.status,

    required this.symbol,
  });

  /// Demo asset type: equity, etf, index, or cash.
  @JsonKey(name: r'asset_type', required: true, includeIfNull: false)
  final String assetType;

  @JsonKey(
    name: r'currency',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CreateAdminAssetRequestCurrencyEnum.unknownDefaultOpenApi,
  )
  final CreateAdminAssetRequestCurrencyEnum currency;

  @JsonKey(name: r'exchange', required: true, includeIfNull: true)
  final String? exchange;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CreateAdminAssetRequestStatusEnum.unknownDefaultOpenApi,
  )
  final CreateAdminAssetRequestStatusEnum status;

  @JsonKey(name: r'symbol', required: true, includeIfNull: false)
  final String symbol;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateAdminAssetRequest &&
          other.assetType == assetType &&
          other.currency == currency &&
          other.exchange == exchange &&
          other.name == name &&
          other.slug == slug &&
          other.status == status &&
          other.symbol == symbol;

  @override
  int get hashCode =>
      assetType.hashCode +
      currency.hashCode +
      (exchange == null ? 0 : exchange.hashCode) +
      name.hashCode +
      slug.hashCode +
      status.hashCode +
      symbol.hashCode;

  factory CreateAdminAssetRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateAdminAssetRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateAdminAssetRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateAdminAssetRequestCurrencyEnum {
  @JsonValue(r'USD')
  USD(r'USD'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateAdminAssetRequestCurrencyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CreateAdminAssetRequestStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'inactive')
  inactive(r'inactive'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateAdminAssetRequestStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
