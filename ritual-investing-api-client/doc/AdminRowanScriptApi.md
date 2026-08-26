# ritual_investing_api_client.api.AdminRowanScriptApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createAdminRowanScript**](AdminRowanScriptApi.md#createadminrowanscript) | **POST** /v1/admin/rowan-scripts | 
[**createAdminRowanScriptRevision**](AdminRowanScriptApi.md#createadminrowanscriptrevision) | **POST** /v1/admin/rowan-scripts/{item_id}/revisions | 
[**decideAdminRowanScriptReview**](AdminRowanScriptApi.md#decideadminrowanscriptreview) | **POST** /v1/admin/rowan-scripts/{item_id}/revisions/{revision_id}/review-decisions | 
[**getAdminRowanScript**](AdminRowanScriptApi.md#getadminrowanscript) | **GET** /v1/admin/rowan-scripts/{item_id} | 
[**getAdminRowanScriptRevision**](AdminRowanScriptApi.md#getadminrowanscriptrevision) | **GET** /v1/admin/rowan-scripts/{item_id}/revisions/{revision_id} | 
[**listAdminRowanScript**](AdminRowanScriptApi.md#listadminrowanscript) | **GET** /v1/admin/rowan-scripts | 
[**patchAdminRowanScriptRevision**](AdminRowanScriptApi.md#patchadminrowanscriptrevision) | **PATCH** /v1/admin/rowan-scripts/{item_id}/revisions/{revision_id} | 
[**previewAdminRowanScriptRevision**](AdminRowanScriptApi.md#previewadminrowanscriptrevision) | **GET** /v1/admin/rowan-scripts/{item_id}/revisions/{revision_id}/preview | 
[**publishAdminRowanScriptRevision**](AdminRowanScriptApi.md#publishadminrowanscriptrevision) | **POST** /v1/admin/rowan-scripts/{item_id}/revisions/{revision_id}/publications | 
[**requestAdminRowanScriptReview**](AdminRowanScriptApi.md#requestadminrowanscriptreview) | **POST** /v1/admin/rowan-scripts/{item_id}/revisions/{revision_id}/review-requests | 
[**withdrawAdminRowanScript**](AdminRowanScriptApi.md#withdrawadminrowanscript) | **POST** /v1/admin/rowan-scripts/{item_id}/withdrawals | 


# **createAdminRowanScript**
> CreateAdminAssetCodex201Response createAdminRowanScript(idempotencyKey, createRowanScriptRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminRowanScriptApi();
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateRowanScriptRequest createRowanScriptRequest = ; // CreateRowanScriptRequest | 

try {
    final response = api.createAdminRowanScript(idempotencyKey, createRowanScriptRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminRowanScriptApi->createAdminRowanScript: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createRowanScriptRequest** | [**CreateRowanScriptRequest**](CreateRowanScriptRequest.md)|  | 

### Return type

[**CreateAdminAssetCodex201Response**](CreateAdminAssetCodex201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createAdminRowanScriptRevision**
> CreateAdminAssetCodex201Response createAdminRowanScriptRevision(itemId, idempotencyKey, createRowanScriptRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminRowanScriptApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateRowanScriptRevisionRequest createRowanScriptRevisionRequest = ; // CreateRowanScriptRevisionRequest | 

try {
    final response = api.createAdminRowanScriptRevision(itemId, idempotencyKey, createRowanScriptRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminRowanScriptApi->createAdminRowanScriptRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createRowanScriptRevisionRequest** | [**CreateRowanScriptRevisionRequest**](CreateRowanScriptRevisionRequest.md)|  | 

### Return type

[**CreateAdminAssetCodex201Response**](CreateAdminAssetCodex201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **decideAdminRowanScriptReview**
> GetAdminAssetCodexRevision200Response decideAdminRowanScriptReview(itemId, revisionId, idempotencyKey, decideAdminAssetCodexReviewRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminRowanScriptApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final DecideAdminAssetCodexReviewRequest decideAdminAssetCodexReviewRequest = ; // DecideAdminAssetCodexReviewRequest | 

try {
    final response = api.decideAdminRowanScriptReview(itemId, revisionId, idempotencyKey, decideAdminAssetCodexReviewRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminRowanScriptApi->decideAdminRowanScriptReview: $e\n');
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

# **getAdminRowanScript**
> CreateAdminAssetCodex201Response getAdminRowanScript(itemId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminRowanScriptApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAdminRowanScript(itemId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminRowanScriptApi->getAdminRowanScript: $e\n');
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

# **getAdminRowanScriptRevision**
> GetAdminAssetCodexRevision200Response getAdminRowanScriptRevision(itemId, revisionId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminRowanScriptApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAdminRowanScriptRevision(itemId, revisionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminRowanScriptApi->getAdminRowanScriptRevision: $e\n');
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

# **listAdminRowanScript**
> ListAdminAssetCodex200Response listAdminRowanScript(state, authorStaffId, search, limit, cursor)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminRowanScriptApi();
final String state = state_example; // String | 
final String authorStaffId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String search = search_example; // String | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 

try {
    final response = api.listAdminRowanScript(state, authorStaffId, search, limit, cursor);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminRowanScriptApi->listAdminRowanScript: $e\n');
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

# **patchAdminRowanScriptRevision**
> GetAdminAssetCodexRevision200Response patchAdminRowanScriptRevision(itemId, revisionId, ifMatch, patchRowanScriptRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminRowanScriptApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = "v3"; // String | 
final PatchRowanScriptRevisionRequest patchRowanScriptRevisionRequest = ; // PatchRowanScriptRevisionRequest | 

try {
    final response = api.patchAdminRowanScriptRevision(itemId, revisionId, ifMatch, patchRowanScriptRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminRowanScriptApi->patchAdminRowanScriptRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **revisionId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **patchRowanScriptRevisionRequest** | [**PatchRowanScriptRevisionRequest**](PatchRowanScriptRevisionRequest.md)|  | 

### Return type

[**GetAdminAssetCodexRevision200Response**](GetAdminAssetCodexRevision200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **previewAdminRowanScriptRevision**
> GetAdminAssetCodexRevision200Response previewAdminRowanScriptRevision(itemId, revisionId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminRowanScriptApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.previewAdminRowanScriptRevision(itemId, revisionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminRowanScriptApi->previewAdminRowanScriptRevision: $e\n');
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

# **publishAdminRowanScriptRevision**
> CreateAdminAssetCodex201Response publishAdminRowanScriptRevision(itemId, revisionId, idempotencyKey, publishAdminAssetCodexRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminRowanScriptApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final PublishAdminAssetCodexRevisionRequest publishAdminAssetCodexRevisionRequest = ; // PublishAdminAssetCodexRevisionRequest | 

try {
    final response = api.publishAdminRowanScriptRevision(itemId, revisionId, idempotencyKey, publishAdminAssetCodexRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminRowanScriptApi->publishAdminRowanScriptRevision: $e\n');
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

# **requestAdminRowanScriptReview**
> GetAdminAssetCodexRevision200Response requestAdminRowanScriptReview(itemId, revisionId, idempotencyKey, requestAdminAssetCodexReviewRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminRowanScriptApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final RequestAdminAssetCodexReviewRequest requestAdminAssetCodexReviewRequest = ; // RequestAdminAssetCodexReviewRequest | 

try {
    final response = api.requestAdminRowanScriptReview(itemId, revisionId, idempotencyKey, requestAdminAssetCodexReviewRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminRowanScriptApi->requestAdminRowanScriptReview: $e\n');
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

# **withdrawAdminRowanScript**
> CreateAdminAssetCodex201Response withdrawAdminRowanScript(itemId, idempotencyKey, withdrawAdminAssetCodexRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminRowanScriptApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final WithdrawAdminAssetCodexRequest withdrawAdminAssetCodexRequest = ; // WithdrawAdminAssetCodexRequest | 

try {
    final response = api.withdrawAdminRowanScript(itemId, idempotencyKey, withdrawAdminAssetCodexRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminRowanScriptApi->withdrawAdminRowanScript: $e\n');
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

