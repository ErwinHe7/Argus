# ritual_investing_api_client.api.AdminGrimoireApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createAdminGrimoire**](AdminGrimoireApi.md#createadmingrimoire) | **POST** /v1/admin/grimoires | 
[**createAdminGrimoireRevision**](AdminGrimoireApi.md#createadmingrimoirerevision) | **POST** /v1/admin/grimoires/{item_id}/revisions | 
[**decideAdminGrimoireReview**](AdminGrimoireApi.md#decideadmingrimoirereview) | **POST** /v1/admin/grimoires/{item_id}/revisions/{revision_id}/review-decisions | 
[**getAdminGrimoire**](AdminGrimoireApi.md#getadmingrimoire) | **GET** /v1/admin/grimoires/{item_id} | 
[**getAdminGrimoireRevision**](AdminGrimoireApi.md#getadmingrimoirerevision) | **GET** /v1/admin/grimoires/{item_id}/revisions/{revision_id} | 
[**listAdminGrimoire**](AdminGrimoireApi.md#listadmingrimoire) | **GET** /v1/admin/grimoires | 
[**patchAdminGrimoireRevision**](AdminGrimoireApi.md#patchadmingrimoirerevision) | **PATCH** /v1/admin/grimoires/{item_id}/revisions/{revision_id} | 
[**previewAdminGrimoireRevision**](AdminGrimoireApi.md#previewadmingrimoirerevision) | **GET** /v1/admin/grimoires/{item_id}/revisions/{revision_id}/preview | 
[**publishAdminGrimoireRevision**](AdminGrimoireApi.md#publishadmingrimoirerevision) | **POST** /v1/admin/grimoires/{item_id}/revisions/{revision_id}/publications | 
[**requestAdminGrimoireReview**](AdminGrimoireApi.md#requestadmingrimoirereview) | **POST** /v1/admin/grimoires/{item_id}/revisions/{revision_id}/review-requests | 
[**withdrawAdminGrimoire**](AdminGrimoireApi.md#withdrawadmingrimoire) | **POST** /v1/admin/grimoires/{item_id}/withdrawals | 


# **createAdminGrimoire**
> CreateAdminAssetCodex201Response createAdminGrimoire(idempotencyKey, createGrimoireRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminGrimoireApi();
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateGrimoireRequest createGrimoireRequest = ; // CreateGrimoireRequest | 

try {
    final response = api.createAdminGrimoire(idempotencyKey, createGrimoireRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminGrimoireApi->createAdminGrimoire: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createGrimoireRequest** | [**CreateGrimoireRequest**](CreateGrimoireRequest.md)|  | 

### Return type

[**CreateAdminAssetCodex201Response**](CreateAdminAssetCodex201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createAdminGrimoireRevision**
> CreateAdminAssetCodex201Response createAdminGrimoireRevision(itemId, idempotencyKey, createGrimoireRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminGrimoireApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateGrimoireRevisionRequest createGrimoireRevisionRequest = ; // CreateGrimoireRevisionRequest | 

try {
    final response = api.createAdminGrimoireRevision(itemId, idempotencyKey, createGrimoireRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminGrimoireApi->createAdminGrimoireRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createGrimoireRevisionRequest** | [**CreateGrimoireRevisionRequest**](CreateGrimoireRevisionRequest.md)|  | 

### Return type

[**CreateAdminAssetCodex201Response**](CreateAdminAssetCodex201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **decideAdminGrimoireReview**
> GetAdminAssetCodexRevision200Response decideAdminGrimoireReview(itemId, revisionId, idempotencyKey, decideAdminAssetCodexReviewRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminGrimoireApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final DecideAdminAssetCodexReviewRequest decideAdminAssetCodexReviewRequest = ; // DecideAdminAssetCodexReviewRequest | 

try {
    final response = api.decideAdminGrimoireReview(itemId, revisionId, idempotencyKey, decideAdminAssetCodexReviewRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminGrimoireApi->decideAdminGrimoireReview: $e\n');
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

# **getAdminGrimoire**
> CreateAdminAssetCodex201Response getAdminGrimoire(itemId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminGrimoireApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAdminGrimoire(itemId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminGrimoireApi->getAdminGrimoire: $e\n');
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

# **getAdminGrimoireRevision**
> GetAdminAssetCodexRevision200Response getAdminGrimoireRevision(itemId, revisionId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminGrimoireApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAdminGrimoireRevision(itemId, revisionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminGrimoireApi->getAdminGrimoireRevision: $e\n');
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

# **listAdminGrimoire**
> ListAdminAssetCodex200Response listAdminGrimoire(state, authorStaffId, search, limit, cursor)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminGrimoireApi();
final String state = state_example; // String | 
final String authorStaffId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String search = search_example; // String | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 

try {
    final response = api.listAdminGrimoire(state, authorStaffId, search, limit, cursor);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminGrimoireApi->listAdminGrimoire: $e\n');
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

# **patchAdminGrimoireRevision**
> GetAdminAssetCodexRevision200Response patchAdminGrimoireRevision(itemId, revisionId, ifMatch, patchGrimoireRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminGrimoireApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = "v3"; // String | 
final PatchGrimoireRevisionRequest patchGrimoireRevisionRequest = ; // PatchGrimoireRevisionRequest | 

try {
    final response = api.patchAdminGrimoireRevision(itemId, revisionId, ifMatch, patchGrimoireRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminGrimoireApi->patchAdminGrimoireRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **revisionId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **patchGrimoireRevisionRequest** | [**PatchGrimoireRevisionRequest**](PatchGrimoireRevisionRequest.md)|  | 

### Return type

[**GetAdminAssetCodexRevision200Response**](GetAdminAssetCodexRevision200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **previewAdminGrimoireRevision**
> GetAdminAssetCodexRevision200Response previewAdminGrimoireRevision(itemId, revisionId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminGrimoireApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.previewAdminGrimoireRevision(itemId, revisionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminGrimoireApi->previewAdminGrimoireRevision: $e\n');
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

# **publishAdminGrimoireRevision**
> CreateAdminAssetCodex201Response publishAdminGrimoireRevision(itemId, revisionId, idempotencyKey, publishAdminAssetCodexRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminGrimoireApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final PublishAdminAssetCodexRevisionRequest publishAdminAssetCodexRevisionRequest = ; // PublishAdminAssetCodexRevisionRequest | 

try {
    final response = api.publishAdminGrimoireRevision(itemId, revisionId, idempotencyKey, publishAdminAssetCodexRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminGrimoireApi->publishAdminGrimoireRevision: $e\n');
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

# **requestAdminGrimoireReview**
> GetAdminAssetCodexRevision200Response requestAdminGrimoireReview(itemId, revisionId, idempotencyKey, requestAdminAssetCodexReviewRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminGrimoireApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final RequestAdminAssetCodexReviewRequest requestAdminAssetCodexReviewRequest = ; // RequestAdminAssetCodexReviewRequest | 

try {
    final response = api.requestAdminGrimoireReview(itemId, revisionId, idempotencyKey, requestAdminAssetCodexReviewRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminGrimoireApi->requestAdminGrimoireReview: $e\n');
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

# **withdrawAdminGrimoire**
> CreateAdminAssetCodex201Response withdrawAdminGrimoire(itemId, idempotencyKey, withdrawAdminAssetCodexRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminGrimoireApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final WithdrawAdminAssetCodexRequest withdrawAdminAssetCodexRequest = ; // WithdrawAdminAssetCodexRequest | 

try {
    final response = api.withdrawAdminGrimoire(itemId, idempotencyKey, withdrawAdminAssetCodexRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminGrimoireApi->withdrawAdminGrimoire: $e\n');
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

