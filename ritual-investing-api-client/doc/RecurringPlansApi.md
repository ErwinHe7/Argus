# ritual_investing_api_client.api.RecurringPlansApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**cancelRecurringPlan**](RecurringPlansApi.md#cancelrecurringplan) | **DELETE** /v1/recurring-plans/{plan_id} | 
[**createRecurringPlan**](RecurringPlansApi.md#createrecurringplan) | **POST** /v1/portfolios/{portfolio_id}/recurring-plans | 
[**getRecurringPlan**](RecurringPlansApi.md#getrecurringplan) | **GET** /v1/recurring-plans/{plan_id} | 
[**listRecurringPlans**](RecurringPlansApi.md#listrecurringplans) | **GET** /v1/portfolios/{portfolio_id}/recurring-plans | 
[**patchRecurringPlan**](RecurringPlansApi.md#patchrecurringplan) | **PATCH** /v1/recurring-plans/{plan_id} | 
[**pauseRecurringPlan**](RecurringPlansApi.md#pauserecurringplan) | **POST** /v1/recurring-plans/{plan_id}/pause | 
[**resumeRecurringPlan**](RecurringPlansApi.md#resumerecurringplan) | **POST** /v1/recurring-plans/{plan_id}/resume | 


# **cancelRecurringPlan**
> cancelRecurringPlan(planId, ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getRecurringPlansApi();
final String planId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 

try {
    api.cancelRecurringPlan(planId, ifMatch);
} on DioException catch (e) {
    print('Exception when calling RecurringPlansApi->cancelRecurringPlan: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **planId** | **String**|  | 
 **ifMatch** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createRecurringPlan**
> CreateRecurringPlan201Response createRecurringPlan(portfolioId, idempotencyKey, createRecurringPlanRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getRecurringPlansApi();
final String portfolioId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = idempotencyKey_example; // String | 
final CreateRecurringPlanRequest createRecurringPlanRequest = ; // CreateRecurringPlanRequest | 

try {
    final response = api.createRecurringPlan(portfolioId, idempotencyKey, createRecurringPlanRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RecurringPlansApi->createRecurringPlan: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **portfolioId** | **String**|  | 
 **idempotencyKey** | **String**|  | 
 **createRecurringPlanRequest** | [**CreateRecurringPlanRequest**](CreateRecurringPlanRequest.md)|  | 

### Return type

[**CreateRecurringPlan201Response**](CreateRecurringPlan201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getRecurringPlan**
> CreateRecurringPlan201Response getRecurringPlan(planId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getRecurringPlansApi();
final String planId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getRecurringPlan(planId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RecurringPlansApi->getRecurringPlan: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **planId** | **String**|  | 

### Return type

[**CreateRecurringPlan201Response**](CreateRecurringPlan201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listRecurringPlans**
> ListRecurringPlans200Response listRecurringPlans(portfolioId, limit, cursor, status)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getRecurringPlansApi();
final String portfolioId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 
final String status = status_example; // String | 

try {
    final response = api.listRecurringPlans(portfolioId, limit, cursor, status);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RecurringPlansApi->listRecurringPlans: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **portfolioId** | **String**|  | 
 **limit** | **int**|  | [optional] [default to 20]
 **cursor** | **String**|  | [optional] 
 **status** | **String**|  | [optional] 

### Return type

[**ListRecurringPlans200Response**](ListRecurringPlans200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **patchRecurringPlan**
> CreateRecurringPlan201Response patchRecurringPlan(planId, ifMatch, patchRecurringPlanRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getRecurringPlansApi();
final String planId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 
final PatchRecurringPlanRequest patchRecurringPlanRequest = ; // PatchRecurringPlanRequest | 

try {
    final response = api.patchRecurringPlan(planId, ifMatch, patchRecurringPlanRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RecurringPlansApi->patchRecurringPlan: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **planId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **patchRecurringPlanRequest** | [**PatchRecurringPlanRequest**](PatchRecurringPlanRequest.md)|  | 

### Return type

[**CreateRecurringPlan201Response**](CreateRecurringPlan201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **pauseRecurringPlan**
> CreateRecurringPlan201Response pauseRecurringPlan(planId, ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getRecurringPlansApi();
final String planId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 

try {
    final response = api.pauseRecurringPlan(planId, ifMatch);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RecurringPlansApi->pauseRecurringPlan: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **planId** | **String**|  | 
 **ifMatch** | **String**|  | 

### Return type

[**CreateRecurringPlan201Response**](CreateRecurringPlan201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **resumeRecurringPlan**
> CreateRecurringPlan201Response resumeRecurringPlan(planId, ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getRecurringPlansApi();
final String planId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 

try {
    final response = api.resumeRecurringPlan(planId, ifMatch);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RecurringPlansApi->resumeRecurringPlan: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **planId** | **String**|  | 
 **ifMatch** | **String**|  | 

### Return type

[**CreateRecurringPlan201Response**](CreateRecurringPlan201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

