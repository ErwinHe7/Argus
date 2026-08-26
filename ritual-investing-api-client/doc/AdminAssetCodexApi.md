# ritual_investing_api_client.api.AdminAssetCodexApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createAdminAssetCodex**](AdminAssetCodexApi.md#createadminassetcodex) | **POST** /v1/admin/asset-codex | 
[**createAdminAssetCodexRevision**](AdminAssetCodexApi.md#createadminassetcodexrevision) | **POST** /v1/admin/asset-codex/{item_id}/revisions | 
[**decideAdminAssetCodexReview**](AdminAssetCodexApi.md#decideadminassetcodexreview) | **POST** /v1/admin/asset-codex/{item_id}/revisions/{revision_id}/review-decisions | 
[**getAdminAssetCodex**](AdminAssetCodexApi.md#getadminassetcodex) | **GET** /v1/admin/asset-codex/{item_id} | 
[**getAdminAssetCodexRevision**](AdminAssetCodexApi.md#getadminassetcodexrevision) | **GET** /v1/admin/asset-codex/{item_id}/revisions/{revision_id} | 
[**listAdminAssetCodex**](AdminAssetCodexApi.md#listadminassetcodex) | **GET** /v1/admin/asset-codex | 
[**patchAdminAssetCodexRevision**](AdminAssetCodexApi.md#patchadminassetcodexrevision) | **PATCH** /v1/admin/asset-codex/{item_id}/revisions/{revision_id} | 
[**previewAdminAssetCodexRevision**](AdminAssetCodexApi.md#previewadminassetcodexrevision) | **GET** /v1/admin/asset-codex/{item_id}/revisions/{revision_id}/preview | 
[**publishAdminAssetCodexRevision**](AdminAssetCodexApi.md#publishadminassetcodexrevision) | **POST** /v1/admin/asset-codex/{item_id}/revisions/{revision_id}/publications | 
[**requestAdminAssetCodexReview**](AdminAssetCodexApi.md#requestadminassetcodexreview) | **POST** /v1/admin/asset-codex/{item_id}/revisions/{revision_id}/review-requests | 
[**withdrawAdminAssetCodex**](AdminAssetCodexApi.md#withdrawadminassetcodex) | **POST** /v1/admin/asset-codex/{item_id}/withdrawals | 


# **createAdminAssetCodex**
> CreateAdminAssetCodex201Response createAdminAssetCodex(idempotencyKey, createAssetCodexRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminAssetCodexApi();
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateAssetCodexRequest createAssetCodexRequest = ; // CreateAssetCodexRequest | 

try {
    final response = api.createAdminAssetCodex(idempotencyKey, createAssetCodexRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminAssetCodexApi->createAdminAssetCodex: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createAssetCodexRequest** | [**CreateAssetCodexRequest**](CreateAssetCodexRequest.md)|  | 

### Return type

[**CreateAdminAssetCodex201Response**](CreateAdminAssetCodex201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createAdminAssetCodexRevision**
> CreateAdminAssetCodex201Response createAdminAssetCodexRevision(itemId, idempotencyKey, createAssetCodexRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminAssetCodexApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateAssetCodexRevisionRequest createAssetCodexRevisionRequest = ; // CreateAssetCodexRevisionRequest | 

try {
    final response = api.createAdminAssetCodexRevision(itemId, idempotencyKey, createAssetCodexRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminAssetCodexApi->createAdminAssetCodexRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createAssetCodexRevisionRequest** | [**CreateAssetCodexRevisionRequest**](CreateAssetCodexRevisionRequest.md)|  | 

### Return type

[**CreateAdminAssetCodex201Response**](CreateAdminAssetCodex201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **decideAdminAssetCodexReview**
> GetAdminAssetCodexRevision200Response decideAdminAssetCodexReview(itemId, revisionId, idempotencyKey, decideAdminAssetCodexReviewRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminAssetCodexApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final DecideAdminAssetCodexReviewRequest decideAdminAssetCodexReviewRequest = ; // DecideAdminAssetCodexReviewRequest | 

try {
    final response = api.decideAdminAssetCodexReview(itemId, revisionId, idempotencyKey, decideAdminAssetCodexReviewRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminAssetCodexApi->decideAdminAssetCodexReview: $e\n');
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

# **getAdminAssetCodex**
> CreateAdminAssetCodex201Response getAdminAssetCodex(itemId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminAssetCodexApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAdminAssetCodex(itemId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminAssetCodexApi->getAdminAssetCodex: $e\n');
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

# **getAdminAssetCodexRevision**
> GetAdminAssetCodexRevision200Response getAdminAssetCodexRevision(itemId, revisionId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminAssetCodexApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAdminAssetCodexRevision(itemId, revisionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminAssetCodexApi->getAdminAssetCodexRevision: $e\n');
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

# **listAdminAssetCodex**
> ListAdminAssetCodex200Response listAdminAssetCodex(state, authorStaffId, search, limit, cursor)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminAssetCodexApi();
final String state = state_example; // String | 
final String authorStaffId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String search = search_example; // String | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 

try {
    final response = api.listAdminAssetCodex(state, authorStaffId, search, limit, cursor);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminAssetCodexApi->listAdminAssetCodex: $e\n');
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

# **patchAdminAssetCodexRevision**
> GetAdminAssetCodexRevision200Response patchAdminAssetCodexRevision(itemId, revisionId, ifMatch, patchAssetCodexRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminAssetCodexApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = "v3"; // String | 
final PatchAssetCodexRevisionRequest patchAssetCodexRevisionRequest = ; // PatchAssetCodexRevisionRequest | 

try {
    final response = api.patchAdminAssetCodexRevision(itemId, revisionId, ifMatch, patchAssetCodexRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminAssetCodexApi->patchAdminAssetCodexRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **revisionId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **patchAssetCodexRevisionRequest** | [**PatchAssetCodexRevisionRequest**](PatchAssetCodexRevisionRequest.md)|  | 

### Return type

[**GetAdminAssetCodexRevision200Response**](GetAdminAssetCodexRevision200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **previewAdminAssetCodexRevision**
> GetAdminAssetCodexRevision200Response previewAdminAssetCodexRevision(itemId, revisionId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminAssetCodexApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.previewAdminAssetCodexRevision(itemId, revisionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminAssetCodexApi->previewAdminAssetCodexRevision: $e\n');
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

# **publishAdminAssetCodexRevision**
> CreateAdminAssetCodex201Response publishAdminAssetCodexRevision(itemId, revisionId, idempotencyKey, publishAdminAssetCodexRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminAssetCodexApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final PublishAdminAssetCodexRevisionRequest publishAdminAssetCodexRevisionRequest = ; // PublishAdminAssetCodexRevisionRequest | 

try {
    final response = api.publishAdminAssetCodexRevision(itemId, revisionId, idempotencyKey, publishAdminAssetCodexRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminAssetCodexApi->publishAdminAssetCodexRevision: $e\n');
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

# **requestAdminAssetCodexReview**
> GetAdminAssetCodexRevision200Response requestAdminAssetCodexReview(itemId, revisionId, idempotencyKey, requestAdminAssetCodexReviewRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminAssetCodexApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final RequestAdminAssetCodexReviewRequest requestAdminAssetCodexReviewRequest = ; // RequestAdminAssetCodexReviewRequest | 

try {
    final response = api.requestAdminAssetCodexReview(itemId, revisionId, idempotencyKey, requestAdminAssetCodexReviewRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminAssetCodexApi->requestAdminAssetCodexReview: $e\n');
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

# **withdrawAdminAssetCodex**
> CreateAdminAssetCodex201Response withdrawAdminAssetCodex(itemId, idempotencyKey, withdrawAdminAssetCodexRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminAssetCodexApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final WithdrawAdminAssetCodexRequest withdrawAdminAssetCodexRequest = ; // WithdrawAdminAssetCodexRequest | 

try {
    final response = api.withdrawAdminAssetCodex(itemId, idempotencyKey, withdrawAdminAssetCodexRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminAssetCodexApi->withdrawAdminAssetCodex: $e\n');
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

