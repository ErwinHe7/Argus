# ritual_investing_api_client.api.AdminOperationsApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getAdminJob**](AdminOperationsApi.md#getadminjob) | **GET** /v1/admin/jobs/{job_id} | 
[**listAdminJobs**](AdminOperationsApi.md#listadminjobs) | **GET** /v1/admin/jobs | 
[**retryAdminJob**](AdminOperationsApi.md#retryadminjob) | **POST** /v1/admin/jobs/{job_id}/retry | 


# **getAdminJob**
> GetAdminJob200Response getAdminJob(jobId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminOperationsApi();
final String jobId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAdminJob(jobId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminOperationsApi->getAdminJob: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **jobId** | **String**|  | 

### Return type

[**GetAdminJob200Response**](GetAdminJob200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminJobs**
> ListAdminJobs200Response listAdminJobs(status, limit, cursor)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminOperationsApi();
final String status = status_example; // String | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 

try {
    final response = api.listAdminJobs(status, limit, cursor);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminOperationsApi->listAdminJobs: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **status** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 20]
 **cursor** | **String**|  | [optional] 

### Return type

[**ListAdminJobs200Response**](ListAdminJobs200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **retryAdminJob**
> GetAdminJob200Response retryAdminJob(jobId, idempotencyKey, retryAdminJobRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminOperationsApi();
final String jobId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final RetryAdminJobRequest retryAdminJobRequest = ; // RetryAdminJobRequest | 

try {
    final response = api.retryAdminJob(jobId, idempotencyKey, retryAdminJobRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminOperationsApi->retryAdminJob: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **jobId** | **String**|  | 
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **retryAdminJobRequest** | [**RetryAdminJobRequest**](RetryAdminJobRequest.md)|  | 

### Return type

[**GetAdminJob200Response**](GetAdminJob200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

