//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'admin_asset.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AdminAsset {
  /// Returns a new [AdminAsset] instance.
  AdminAsset({
    required this.assetType,

    required this.currency,

    required this.etag,

    required this.exchange,

    required this.id,

    required this.isDemo,

    required this.name,

    required this.slug,

    required this.status,

    required this.symbol,

    required this.version,
  });

  /// Demo asset type: equity, etf, index, or cash.
  @JsonKey(name: r'asset_type', required: true, includeIfNull: false)
  final String assetType;

  @JsonKey(
    name: r'currency',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminAssetCurrencyEnum.unknownDefaultOpenApi,
  )
  final AdminAssetCurrencyEnum currency;

  @JsonKey(name: r'etag', required: true, includeIfNull: false)
  final String etag;

  @JsonKey(name: r'exchange', required: true, includeIfNull: true)
  final String? exchange;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'is_demo', required: true, includeIfNull: false)
  final bool isDemo;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminAssetStatusEnum.unknownDefaultOpenApi,
  )
  final AdminAssetStatusEnum status;

  @JsonKey(name: r'symbol', required: true, includeIfNull: false)
  final String symbol;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminAsset &&
          other.assetType == assetType &&
          other.currency == currency &&
          other.etag == etag &&
          other.exchange == exchange &&
          other.id == id &&
          other.isDemo == isDemo &&
          other.name == name &&
          other.slug == slug &&
          other.status == status &&
          other.symbol == symbol &&
          other.version == version;

  @override
  int get hashCode =>
      assetType.hashCode +
      currency.hashCode +
      etag.hashCode +
      (exchange == null ? 0 : exchange.hashCode) +
      id.hashCode +
      isDemo.hashCode +
      name.hashCode +
      slug.hashCode +
      status.hashCode +
      symbol.hashCode +
      version.hashCode;

  factory AdminAsset.fromJson(Map<String, dynamic> json) =>
      _$AdminAssetFromJson(json);

  Map<String, dynamic> toJson() => _$AdminAssetToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AdminAssetCurrencyEnum {
  @JsonValue(r'USD')
  USD(r'USD'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminAssetCurrencyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum AdminAssetStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'inactive')
  inactive(r'inactive'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminAssetStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
