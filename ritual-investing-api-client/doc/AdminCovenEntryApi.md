# ritual_investing_api_client.api.AdminCovenEntryApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createAdminCovenEntry**](AdminCovenEntryApi.md#createadmincovenentry) | **POST** /v1/admin/coven-entries | 
[**createAdminCovenEntryRevision**](AdminCovenEntryApi.md#createadmincovenentryrevision) | **POST** /v1/admin/coven-entries/{item_id}/revisions | 
[**decideAdminCovenEntryReview**](AdminCovenEntryApi.md#decideadmincovenentryreview) | **POST** /v1/admin/coven-entries/{item_id}/revisions/{revision_id}/review-decisions | 
[**getAdminCovenEntry**](AdminCovenEntryApi.md#getadmincovenentry) | **GET** /v1/admin/coven-entries/{item_id} | 
[**getAdminCovenEntryRevision**](AdminCovenEntryApi.md#getadmincovenentryrevision) | **GET** /v1/admin/coven-entries/{item_id}/revisions/{revision_id} | 
[**listAdminCovenEntry**](AdminCovenEntryApi.md#listadmincovenentry) | **GET** /v1/admin/coven-entries | 
[**patchAdminCovenEntryRevision**](AdminCovenEntryApi.md#patchadmincovenentryrevision) | **PATCH** /v1/admin/coven-entries/{item_id}/revisions/{revision_id} | 
[**previewAdminCovenEntryRevision**](AdminCovenEntryApi.md#previewadmincovenentryrevision) | **GET** /v1/admin/coven-entries/{item_id}/revisions/{revision_id}/preview | 
[**publishAdminCovenEntryRevision**](AdminCovenEntryApi.md#publishadmincovenentryrevision) | **POST** /v1/admin/coven-entries/{item_id}/revisions/{revision_id}/publications | 
[**requestAdminCovenEntryReview**](AdminCovenEntryApi.md#requestadmincovenentryreview) | **POST** /v1/admin/coven-entries/{item_id}/revisions/{revision_id}/review-requests | 
[**withdrawAdminCovenEntry**](AdminCovenEntryApi.md#withdrawadmincovenentry) | **POST** /v1/admin/coven-entries/{item_id}/withdrawals | 


# **createAdminCovenEntry**
> CreateAdminAssetCodex201Response createAdminCovenEntry(idempotencyKey, createCovenEntryRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminCovenEntryApi();
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateCovenEntryRequest createCovenEntryRequest = ; // CreateCovenEntryRequest | 

try {
    final response = api.createAdminCovenEntry(idempotencyKey, createCovenEntryRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminCovenEntryApi->createAdminCovenEntry: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createCovenEntryRequest** | [**CreateCovenEntryRequest**](CreateCovenEntryRequest.md)|  | 

### Return type

[**CreateAdminAssetCodex201Response**](CreateAdminAssetCodex201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createAdminCovenEntryRevision**
> CreateAdminAssetCodex201Response createAdminCovenEntryRevision(itemId, idempotencyKey, createCovenEntryRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminCovenEntryApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateCovenEntryRevisionRequest createCovenEntryRevisionRequest = ; // CreateCovenEntryRevisionRequest | 

try {
    final response = api.createAdminCovenEntryRevision(itemId, idempotencyKey, createCovenEntryRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminCovenEntryApi->createAdminCovenEntryRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createCovenEntryRevisionRequest** | [**CreateCovenEntryRevisionRequest**](CreateCovenEntryRevisionRequest.md)|  | 

### Return type

[**CreateAdminAssetCodex201Response**](CreateAdminAssetCodex201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **decideAdminCovenEntryReview**
> GetAdminAssetCodexRevision200Response decideAdminCovenEntryReview(itemId, revisionId, idempotencyKey, decideAdminAssetCodexReviewRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminCovenEntryApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final DecideAdminAssetCodexReviewRequest decideAdminAssetCodexReviewRequest = ; // DecideAdminAssetCodexReviewRequest | 

try {
    final response = api.decideAdminCovenEntryReview(itemId, revisionId, idempotencyKey, decideAdminAssetCodexReviewRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminCovenEntryApi->decideAdminCovenEntryReview: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **revisionId** | **String**|  | 
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **decideAdminAssetCodexReviewRequest** | [**DecideAdminAssetCodexReviewRequest**](DecideAdminAssetCodexReviewRequest.md)|  | 

### Return type

[**GetAdminAssetCodexRevision200Response**](GetAdminAssetCodexRevision200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAdminCovenEntry**
> CreateAdminAssetCodex201Response getAdminCovenEntry(itemId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminCovenEntryApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAdminCovenEntry(itemId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminCovenEntryApi->getAdminCovenEntry: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 

### Return type

[**CreateAdminAssetCodex201Response**](CreateAdminAssetCodex201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAdminCovenEntryRevision**
> GetAdminAssetCodexRevision200Response getAdminCovenEntryRevision(itemId, revisionId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminCovenEntryApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAdminCovenEntryRevision(itemId, revisionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminCovenEntryApi->getAdminCovenEntryRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **revisionId** | **String**|  | 

### Return type

[**GetAdminAssetCodexRevision200Response**](GetAdminAssetCodexRevision200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminCovenEntry**
> ListAdminAssetCodex200Response listAdminCovenEntry(state, authorStaffId, search, limit, cursor)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminCovenEntryApi();
final String state = state_example; // String | 
final String authorStaffId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String search = search_example; // String | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 

try {
    final response = api.listAdminCovenEntry(state, authorStaffId, search, limit, cursor);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminCovenEntryApi->listAdminCovenEntry: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **state** | **String**|  | [optional] 
 **authorStaffId** | **String**|  | [optional] 
 **search** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 20]
 **cursor** | **String**|  | [optional] 

### Return type

[**ListAdminAssetCodex200Response**](ListAdminAssetCodex200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **patchAdminCovenEntryRevision**
> GetAdminAssetCodexRevision200Response patchAdminCovenEntryRevision(itemId, revisionId, ifMatch, patchCovenEntryRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminCovenEntryApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = "v3"; // String | 
final PatchCovenEntryRevisionRequest patchCovenEntryRevisionRequest = ; // PatchCovenEntryRevisionRequest | 

try {
    final response = api.patchAdminCovenEntryRevision(itemId, revisionId, ifMatch, patchCovenEntryRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminCovenEntryApi->patchAdminCovenEntryRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **revisionId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **patchCovenEntryRevisionRequest** | [**PatchCovenEntryRevisionRequest**](PatchCovenEntryRevisionRequest.md)|  | 

### Return type

[**GetAdminAssetCodexRevision200Response**](GetAdminAssetCodexRevision200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **previewAdminCovenEntryRevision**
> GetAdminAssetCodexRevision200Response previewAdminCovenEntryRevision(itemId, revisionId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminCovenEntryApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.previewAdminCovenEntryRevision(itemId, revisionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminCovenEntryApi->previewAdminCovenEntryRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **revisionId** | **String**|  | 

### Return type

[**GetAdminAssetCodexRevision200Response**](GetAdminAssetCodexRevision200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **publishAdminCovenEntryRevision**
> CreateAdminAssetCodex201Response publishAdminCovenEntryRevision(itemId, revisionId, idempotencyKey, publishAdminAssetCodexRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminCovenEntryApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final PublishAdminAssetCodexRevisionRequest publishAdminAssetCodexRevisionRequest = ; // PublishAdminAssetCodexRevisionRequest | 

try {
    final response = api.publishAdminCovenEntryRevision(itemId, revisionId, idempotencyKey, publishAdminAssetCodexRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminCovenEntryApi->publishAdminCovenEntryRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **revisionId** | **String**|  | 
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **publishAdminAssetCodexRevisionRequest** | [**PublishAdminAssetCodexRevisionRequest**](PublishAdminAssetCodexRevisionRequest.md)|  | 

### Return type

[**CreateAdminAssetCodex201Response**](CreateAdminAssetCodex201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **requestAdminCovenEntryReview**
> GetAdminAssetCodexRevision200Response requestAdminCovenEntryReview(itemId, revisionId, idempotencyKey, requestAdminAssetCodexReviewRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminCovenEntryApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final RequestAdminAssetCodexReviewRequest requestAdminAssetCodexReviewRequest = ; // RequestAdminAssetCodexReviewRequest | 

try {
    final response = api.requestAdminCovenEntryReview(itemId, revisionId, idempotencyKey, requestAdminAssetCodexReviewRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminCovenEntryApi->requestAdminCovenEntryReview: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **revisionId** | **String**|  | 
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **requestAdminAssetCodexReviewRequest** | [**RequestAdminAssetCodexReviewRequest**](RequestAdminAssetCodexReviewRequest.md)|  | 

### Return type

[**GetAdminAssetCodexRevision200Response**](GetAdminAssetCodexRevision200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **withdrawAdminCovenEntry**
> CreateAdminAssetCodex201Response withdrawAdminCovenEntry(itemId, idempotencyKey, withdrawAdminAssetCodexRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminCovenEntryApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final WithdrawAdminAssetCodexRequest withdrawAdminAssetCodexRequest = ; // WithdrawAdminAssetCodexRequest | 

try {
    final response = api.withdrawAdminCovenEntry(itemId, idempotencyKey, withdrawAdminAssetCodexRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminCovenEntryApi->withdrawAdminCovenEntry: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **withdrawAdminAssetCodexRequest** | [**WithdrawAdminAssetCodexRequest**](WithdrawAdminAssetCodexRequest.md)|  | 

### Return type

[**CreateAdminAssetCodex201Response**](CreateAdminAssetCodex201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

