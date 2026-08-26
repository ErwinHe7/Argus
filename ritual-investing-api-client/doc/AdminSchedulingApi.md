# ritual_investing_api_client.api.AdminSchedulingApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createAdminRitualSchedule**](AdminSchedulingApi.md#createadminritualschedule) | **POST** /v1/admin/ritual-schedules | 
[**listAdminRitualSchedules**](AdminSchedulingApi.md#listadminritualschedules) | **GET** /v1/admin/ritual-schedules | 
[**patchAdminRitualSchedule**](AdminSchedulingApi.md#patchadminritualschedule) | **PATCH** /v1/admin/ritual-schedules/{schedule_id} | 
[**withdrawAdminRitualSchedule**](AdminSchedulingApi.md#withdrawadminritualschedule) | **DELETE** /v1/admin/ritual-schedules/{schedule_id} | 


# **createAdminRitualSchedule**
> CreateAdminRitualSchedule201Response createAdminRitualSchedule(idempotencyKey, createAdminRitualScheduleRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminSchedulingApi();
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateAdminRitualScheduleRequest createAdminRitualScheduleRequest = ; // CreateAdminRitualScheduleRequest | 

try {
    final response = api.createAdminRitualSchedule(idempotencyKey, createAdminRitualScheduleRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminSchedulingApi->createAdminRitualSchedule: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createAdminRitualScheduleRequest** | [**CreateAdminRitualScheduleRequest**](CreateAdminRitualScheduleRequest.md)|  | 

### Return type

[**CreateAdminRitualSchedule201Response**](CreateAdminRitualSchedule201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminRitualSchedules**
> ListAdminRitualSchedules200Response listAdminRitualSchedules(from, to, mode, state, limit, cursor)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminSchedulingApi();
final DateTime from = 2013-10-20; // DateTime | 
final DateTime to = 2013-10-20; // DateTime | 
final String mode = mode_example; // String | 
final String state = state_example; // String | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 

try {
    final response = api.listAdminRitualSchedules(from, to, mode, state, limit, cursor);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminSchedulingApi->listAdminRitualSchedules: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **from** | **DateTime**|  | 
 **to** | **DateTime**|  | 
 **mode** | **String**|  | [optional] 
 **state** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 20]
 **cursor** | **String**|  | [optional] 

### Return type

[**ListAdminRitualSchedules200Response**](ListAdminRitualSchedules200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **patchAdminRitualSchedule**
> CreateAdminRitualSchedule201Response patchAdminRitualSchedule(scheduleId, ifMatch, patchAdminRitualScheduleRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminSchedulingApi();
final String scheduleId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = "v3"; // String | 
final PatchAdminRitualScheduleRequest patchAdminRitualScheduleRequest = ; // PatchAdminRitualScheduleRequest | 

try {
    final response = api.patchAdminRitualSchedule(scheduleId, ifMatch, patchAdminRitualScheduleRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminSchedulingApi->patchAdminRitualSchedule: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **scheduleId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **patchAdminRitualScheduleRequest** | [**PatchAdminRitualScheduleRequest**](PatchAdminRitualScheduleRequest.md)|  | 

### Return type

[**CreateAdminRitualSchedule201Response**](CreateAdminRitualSchedule201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **withdrawAdminRitualSchedule**
> withdrawAdminRitualSchedule(scheduleId, ifMatch, withdrawAdminAssetCodexRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminSchedulingApi();
final String scheduleId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = "v3"; // String | 
final WithdrawAdminAssetCodexRequest withdrawAdminAssetCodexRequest = ; // WithdrawAdminAssetCodexRequest | 

try {
    api.withdrawAdminRitualSchedule(scheduleId, ifMatch, withdrawAdminAssetCodexRequest);
} on DioException catch (e) {
    print('Exception when calling AdminSchedulingApi->withdrawAdminRitualSchedule: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **scheduleId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **withdrawAdminAssetCodexRequest** | [**WithdrawAdminAssetCodexRequest**](WithdrawAdminAssetCodexRequest.md)|  | 

### Return type

void (empty response body)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

