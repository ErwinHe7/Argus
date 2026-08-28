# ritual_investing_api_client.api.FutureMirrorApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createFutureMirror**](FutureMirrorApi.md#createfuturemirror) | **POST** /v1/intentions/{intention_id}/future-mirror | 
[**getFutureMirror**](FutureMirrorApi.md#getfuturemirror) | **GET** /v1/intentions/{intention_id}/future-mirror/{run_id} | 
[**getLatestFutureMirror**](FutureMirrorApi.md#getlatestfuturemirror) | **GET** /v1/intentions/{intention_id}/future-mirror/latest | 


# **createFutureMirror**
> HypotheticalFutureMirrorResponse createFutureMirror(intentionId, idempotencyKey, createHypotheticalFutureMirror)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getFutureMirrorApi();
final String intentionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = idempotencyKey_example; // String | 
final CreateHypotheticalFutureMirror createHypotheticalFutureMirror = ; // CreateHypotheticalFutureMirror | 

try {
    final response = api.createFutureMirror(intentionId, idempotencyKey, createHypotheticalFutureMirror);
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
 **createHypotheticalFutureMirror** | [**CreateHypotheticalFutureMirror**](CreateHypotheticalFutureMirror.md)|  | 

### Return type

[**HypotheticalFutureMirrorResponse**](HypotheticalFutureMirrorResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getFutureMirror**
> HypotheticalFutureMirrorResponse getFutureMirror(intentionId, runId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

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

[**HypotheticalFutureMirrorResponse**](HypotheticalFutureMirrorResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getLatestFutureMirror**
> HypotheticalFutureMirrorResponse getLatestFutureMirror(intentionId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

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

[**HypotheticalFutureMirrorResponse**](HypotheticalFutureMirrorResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

