//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'demo_reset_result_default_portfolio.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DemoResetResultDefaultPortfolio {
  /// Returns a new [DemoResetResultDefaultPortfolio] instance.
  DemoResetResultDefaultPortfolio({
    required this.currency,

    required this.id,

    required this.name,

    required this.status,

    required this.version,
  });

  @JsonKey(
    name: r'currency',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        DemoResetResultDefaultPortfolioCurrencyEnum.unknownDefaultOpenApi,
  )
  final DemoResetResultDefaultPortfolioCurrencyEnum currency;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        DemoResetResultDefaultPortfolioStatusEnum.unknownDefaultOpenApi,
  )
  final DemoResetResultDefaultPortfolioStatusEnum status;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DemoResetResultDefaultPortfolio &&
          other.currency == currency &&
          other.id == id &&
          other.name == name &&
          other.status == status &&
          other.version == version;

  @override
  int get hashCode =>
      currency.hashCode +
      id.hashCode +
      name.hashCode +
      status.hashCode +
      version.hashCode;

  factory DemoResetResultDefaultPortfolio.fromJson(Map<String, dynamic> json) =>
      _$DemoResetResultDefaultPortfolioFromJson(json);

  Map<String, dynamic> toJson() =>
      _$DemoResetResultDefaultPortfolioToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum DemoResetResultDefaultPortfolioCurrencyEnum {
  @JsonValue(r'USD')
  USD(r'USD'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DemoResetResultDefaultPortfolioCurrencyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum DemoResetResultDefaultPortfolioStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DemoResetResultDefaultPortfolioStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
