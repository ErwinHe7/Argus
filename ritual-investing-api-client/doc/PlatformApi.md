# ritual_investing_api_client.api.PlatformApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getLiveHealth**](PlatformApi.md#getlivehealth) | **GET** /v1/health/live | 
[**getOpenApiDocument**](PlatformApi.md#getopenapidocument) | **GET** /v1/openapi.json | 


# **getLiveHealth**
> GetAccount200Response getLiveHealth()



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

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getOpenApiDocument**
> GetAccount200Response getOpenApiDocument()



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

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

