# ritual_investing_api_client.api.AdminOperationsApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**listAdminBrokerageDiagnostics**](AdminOperationsApi.md#listadminbrokeragediagnostics) | **GET** /v1/admin/operations/brokerage | 
[**listAdminJobs**](AdminOperationsApi.md#listadminjobs) | **GET** /v1/admin/operations/jobs | 
[**listAdminPrivacy**](AdminOperationsApi.md#listadminprivacy) | **GET** /v1/admin/operations/privacy | 
[**retryAdminJob**](AdminOperationsApi.md#retryadminjob) | **POST** /v1/admin/operations/jobs/{job_id}/retry | 
[**retryAdminPrivacy**](AdminOperationsApi.md#retryadminprivacy) | **POST** /v1/admin/operations/privacy/{request_id}/retry | 


# **listAdminBrokerageDiagnostics**
> GetAccount200Response listAdminBrokerageDiagnostics(limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminOperationsApi();
final int limit = 56; // int | 

try {
    final response = api.listAdminBrokerageDiagnostics(limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminOperationsApi->listAdminBrokerageDiagnostics: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **limit** | **int**|  | [optional] [default to 25]

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminJobs**
> GetAccount200Response listAdminJobs(limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminOperationsApi();
final int limit = 56; // int | 

try {
    final response = api.listAdminJobs(limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminOperationsApi->listAdminJobs: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **limit** | **int**|  | [optional] [default to 25]

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminPrivacy**
> GetAccount200Response listAdminPrivacy(limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminOperationsApi();
final int limit = 56; // int | 

try {
    final response = api.listAdminPrivacy(limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminOperationsApi->listAdminPrivacy: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **limit** | **int**|  | [optional] [default to 25]

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **retryAdminJob**
> GetAccount200Response retryAdminJob(jobId, idempotencyKey, retryAdminJobRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminOperationsApi();
final String jobId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = idempotencyKey_example; // String | 
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
 **idempotencyKey** | **String**|  | 
 **retryAdminJobRequest** | [**RetryAdminJobRequest**](RetryAdminJobRequest.md)|  | 

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **retryAdminPrivacy**
> GetAccount200Response retryAdminPrivacy(requestId, idempotencyKey, retryAdminJobRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminOperationsApi();
final String requestId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = idempotencyKey_example; // String | 
final RetryAdminJobRequest retryAdminJobRequest = ; // RetryAdminJobRequest | 

try {
    final response = api.retryAdminPrivacy(requestId, idempotencyKey, retryAdminJobRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminOperationsApi->retryAdminPrivacy: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **requestId** | **String**|  | 
 **idempotencyKey** | **String**|  | 
 **retryAdminJobRequest** | [**RetryAdminJobRequest**](RetryAdminJobRequest.md)|  | 

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

