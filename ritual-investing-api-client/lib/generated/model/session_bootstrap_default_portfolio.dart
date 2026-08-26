//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_bootstrap_default_portfolio.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SessionBootstrapDefaultPortfolio {
  /// Returns a new [SessionBootstrapDefaultPortfolio] instance.
  SessionBootstrapDefaultPortfolio({
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
        SessionBootstrapDefaultPortfolioCurrencyEnum.unknownDefaultOpenApi,
  )
  final SessionBootstrapDefaultPortfolioCurrencyEnum currency;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        SessionBootstrapDefaultPortfolioStatusEnum.unknownDefaultOpenApi,
  )
  final SessionBootstrapDefaultPortfolioStatusEnum status;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionBootstrapDefaultPortfolio &&
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

  factory SessionBootstrapDefaultPortfolio.fromJson(
    Map<String, dynamic> json,
  ) => _$SessionBootstrapDefaultPortfolioFromJson(json);

  Map<String, dynamic> toJson() =>
      _$SessionBootstrapDefaultPortfolioToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum SessionBootstrapDefaultPortfolioCurrencyEnum {
  @JsonValue(r'USD')
  USD(r'USD'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SessionBootstrapDefaultPortfolioCurrencyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum SessionBootstrapDefaultPortfolioStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SessionBootstrapDefaultPortfolioStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
