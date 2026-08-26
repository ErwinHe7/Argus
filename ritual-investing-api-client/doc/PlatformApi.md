# ritual_investing_api_client.api.PlatformApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getHealth**](PlatformApi.md#gethealth) | **GET** /health | 
[**getLiveHealth**](PlatformApi.md#getlivehealth) | **GET** /v1/health/live | 
[**getOpenApiDocument**](PlatformApi.md#getopenapidocument) | **GET** /v1/openapi.json | 


# **getHealth**
> HealthResponse getHealth()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getPlatformApi();

try {
    final response = api.getHealth();
    print(response);
} on DioException catch (e) {
    print('Exception when calling PlatformApi->getHealth: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**HealthResponse**](HealthResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getLiveHealth**
> HealthResponse getLiveHealth()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getPlatformApi();

try {
    final response = api.getLiveHealth();
    print(response);
} on DioException catch (e) {
    print('Exception when calling PlatformApi->getLiveHealth: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**HealthResponse**](HealthResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getOpenApiDocument**
> OpenApiDocument getOpenApiDocument()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getPlatformApi();

try {
    final response = api.getOpenApiDocument();
    print(response);
} on DioException catch (e) {
    print('Exception when calling PlatformApi->getOpenApiDocument: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**OpenApiDocument**](OpenApiDocument.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

