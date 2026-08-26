# ritual_investing_api_client.api.FutureMirrorApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createFutureMirror**](FutureMirrorApi.md#createfuturemirror) | **POST** /v1/intentions/{intention_id}/future-mirror | 
[**getFutureMirror**](FutureMirrorApi.md#getfuturemirror) | **GET** /v1/intentions/{intention_id}/future-mirror/{run_id} | 
[**getLatestFutureMirror**](FutureMirrorApi.md#getlatestfuturemirror) | **GET** /v1/intentions/{intention_id}/future-mirror/latest | 


# **createFutureMirror**
> CreateFutureMirror200Response createFutureMirror(intentionId, idempotencyKey, createFutureMirrorRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getFutureMirrorApi();
final String intentionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = idempotencyKey_example; // String | 
final CreateFutureMirrorRequest createFutureMirrorRequest = ; // CreateFutureMirrorRequest | 

try {
    final response = api.createFutureMirror(intentionId, idempotencyKey, createFutureMirrorRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling FutureMirrorApi->createFutureMirror: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **intentionId** | **String**|  | 
 **idempotencyKey** | **String**|  | 
 **createFutureMirrorRequest** | [**CreateFutureMirrorRequest**](CreateFutureMirrorRequest.md)|  | 

### Return type

[**CreateFutureMirror200Response**](CreateFutureMirror200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getFutureMirror**
> CreateFutureMirror200Response getFutureMirror(intentionId, runId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getFutureMirrorApi();
final String intentionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String runId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getFutureMirror(intentionId, runId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling FutureMirrorApi->getFutureMirror: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **intentionId** | **String**|  | 
 **runId** | **String**|  | 

### Return type

[**CreateFutureMirror200Response**](CreateFutureMirror200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getLatestFutureMirror**
> CreateFutureMirror200Response getLatestFutureMirror(intentionId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getFutureMirrorApi();
final String intentionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getLatestFutureMirror(intentionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling FutureMirrorApi->getLatestFutureMirror: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **intentionId** | **String**|  | 

### Return type

[**CreateFutureMirror200Response**](CreateFutureMirror200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

