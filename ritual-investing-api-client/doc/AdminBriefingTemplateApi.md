# ritual_investing_api_client.api.AdminBriefingTemplateApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createAdminBriefingTemplate**](AdminBriefingTemplateApi.md#createadminbriefingtemplate) | **POST** /v1/admin/briefing-templates | 
[**createAdminBriefingTemplateRevision**](AdminBriefingTemplateApi.md#createadminbriefingtemplaterevision) | **POST** /v1/admin/briefing-templates/{item_id}/revisions | 
[**decideAdminBriefingTemplateReview**](AdminBriefingTemplateApi.md#decideadminbriefingtemplatereview) | **POST** /v1/admin/briefing-templates/{item_id}/revisions/{revision_id}/review-decisions | 
[**getAdminBriefingTemplate**](AdminBriefingTemplateApi.md#getadminbriefingtemplate) | **GET** /v1/admin/briefing-templates/{item_id} | 
[**getAdminBriefingTemplateRevision**](AdminBriefingTemplateApi.md#getadminbriefingtemplaterevision) | **GET** /v1/admin/briefing-templates/{item_id}/revisions/{revision_id} | 
[**listAdminBriefingTemplate**](AdminBriefingTemplateApi.md#listadminbriefingtemplate) | **GET** /v1/admin/briefing-templates | 
[**patchAdminBriefingTemplateRevision**](AdminBriefingTemplateApi.md#patchadminbriefingtemplaterevision) | **PATCH** /v1/admin/briefing-templates/{item_id}/revisions/{revision_id} | 
[**previewAdminBriefingTemplateRevision**](AdminBriefingTemplateApi.md#previewadminbriefingtemplaterevision) | **GET** /v1/admin/briefing-templates/{item_id}/revisions/{revision_id}/preview | 
[**publishAdminBriefingTemplateRevision**](AdminBriefingTemplateApi.md#publishadminbriefingtemplaterevision) | **POST** /v1/admin/briefing-templates/{item_id}/revisions/{revision_id}/publications | 
[**requestAdminBriefingTemplateReview**](AdminBriefingTemplateApi.md#requestadminbriefingtemplatereview) | **POST** /v1/admin/briefing-templates/{item_id}/revisions/{revision_id}/review-requests | 
[**withdrawAdminBriefingTemplate**](AdminBriefingTemplateApi.md#withdrawadminbriefingtemplate) | **POST** /v1/admin/briefing-templates/{item_id}/withdrawals | 


# **createAdminBriefingTemplate**
> CreateAdminAssetCodex201Response createAdminBriefingTemplate(idempotencyKey, createBriefingTemplateRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminBriefingTemplateApi();
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateBriefingTemplateRequest createBriefingTemplateRequest = ; // CreateBriefingTemplateRequest | 

try {
    final response = api.createAdminBriefingTemplate(idempotencyKey, createBriefingTemplateRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminBriefingTemplateApi->createAdminBriefingTemplate: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createBriefingTemplateRequest** | [**CreateBriefingTemplateRequest**](CreateBriefingTemplateRequest.md)|  | 

### Return type

[**CreateAdminAssetCodex201Response**](CreateAdminAssetCodex201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createAdminBriefingTemplateRevision**
> CreateAdminAssetCodex201Response createAdminBriefingTemplateRevision(itemId, idempotencyKey, createBriefingTemplateRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminBriefingTemplateApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateBriefingTemplateRevisionRequest createBriefingTemplateRevisionRequest = ; // CreateBriefingTemplateRevisionRequest | 

try {
    final response = api.createAdminBriefingTemplateRevision(itemId, idempotencyKey, createBriefingTemplateRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminBriefingTemplateApi->createAdminBriefingTemplateRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createBriefingTemplateRevisionRequest** | [**CreateBriefingTemplateRevisionRequest**](CreateBriefingTemplateRevisionRequest.md)|  | 

### Return type

[**CreateAdminAssetCodex201Response**](CreateAdminAssetCodex201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **decideAdminBriefingTemplateReview**
> GetAdminAssetCodexRevision200Response decideAdminBriefingTemplateReview(itemId, revisionId, idempotencyKey, decideAdminAssetCodexReviewRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminBriefingTemplateApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final DecideAdminAssetCodexReviewRequest decideAdminAssetCodexReviewRequest = ; // DecideAdminAssetCodexReviewRequest | 

try {
    final response = api.decideAdminBriefingTemplateReview(itemId, revisionId, idempotencyKey, decideAdminAssetCodexReviewRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminBriefingTemplateApi->decideAdminBriefingTemplateReview: $e\n');
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

# **getAdminBriefingTemplate**
> CreateAdminAssetCodex201Response getAdminBriefingTemplate(itemId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminBriefingTemplateApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAdminBriefingTemplate(itemId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminBriefingTemplateApi->getAdminBriefingTemplate: $e\n');
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

# **getAdminBriefingTemplateRevision**
> GetAdminAssetCodexRevision200Response getAdminBriefingTemplateRevision(itemId, revisionId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminBriefingTemplateApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAdminBriefingTemplateRevision(itemId, revisionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminBriefingTemplateApi->getAdminBriefingTemplateRevision: $e\n');
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

# **listAdminBriefingTemplate**
> ListAdminAssetCodex200Response listAdminBriefingTemplate(state, authorStaffId, search, limit, cursor)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminBriefingTemplateApi();
final String state = state_example; // String | 
final String authorStaffId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String search = search_example; // String | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 

try {
    final response = api.listAdminBriefingTemplate(state, authorStaffId, search, limit, cursor);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminBriefingTemplateApi->listAdminBriefingTemplate: $e\n');
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

# **patchAdminBriefingTemplateRevision**
> GetAdminAssetCodexRevision200Response patchAdminBriefingTemplateRevision(itemId, revisionId, ifMatch, patchBriefingTemplateRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminBriefingTemplateApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = "v3"; // String | 
final PatchBriefingTemplateRevisionRequest patchBriefingTemplateRevisionRequest = ; // PatchBriefingTemplateRevisionRequest | 

try {
    final response = api.patchAdminBriefingTemplateRevision(itemId, revisionId, ifMatch, patchBriefingTemplateRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminBriefingTemplateApi->patchAdminBriefingTemplateRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **revisionId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **patchBriefingTemplateRevisionRequest** | [**PatchBriefingTemplateRevisionRequest**](PatchBriefingTemplateRevisionRequest.md)|  | 

### Return type

[**GetAdminAssetCodexRevision200Response**](GetAdminAssetCodexRevision200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **previewAdminBriefingTemplateRevision**
> GetAdminAssetCodexRevision200Response previewAdminBriefingTemplateRevision(itemId, revisionId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminBriefingTemplateApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.previewAdminBriefingTemplateRevision(itemId, revisionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminBriefingTemplateApi->previewAdminBriefingTemplateRevision: $e\n');
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

# **publishAdminBriefingTemplateRevision**
> CreateAdminAssetCodex201Response publishAdminBriefingTemplateRevision(itemId, revisionId, idempotencyKey, publishAdminAssetCodexRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminBriefingTemplateApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final PublishAdminAssetCodexRevisionRequest publishAdminAssetCodexRevisionRequest = ; // PublishAdminAssetCodexRevisionRequest | 

try {
    final response = api.publishAdminBriefingTemplateRevision(itemId, revisionId, idempotencyKey, publishAdminAssetCodexRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminBriefingTemplateApi->publishAdminBriefingTemplateRevision: $e\n');
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

# **requestAdminBriefingTemplateReview**
> GetAdminAssetCodexRevision200Response requestAdminBriefingTemplateReview(itemId, revisionId, idempotencyKey, requestAdminAssetCodexReviewRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminBriefingTemplateApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final RequestAdminAssetCodexReviewRequest requestAdminAssetCodexReviewRequest = ; // RequestAdminAssetCodexReviewRequest | 

try {
    final response = api.requestAdminBriefingTemplateReview(itemId, revisionId, idempotencyKey, requestAdminAssetCodexReviewRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminBriefingTemplateApi->requestAdminBriefingTemplateReview: $e\n');
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

# **withdrawAdminBriefingTemplate**
> CreateAdminAssetCodex201Response withdrawAdminBriefingTemplate(itemId, idempotencyKey, withdrawAdminAssetCodexRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminBriefingTemplateApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final WithdrawAdminAssetCodexRequest withdrawAdminAssetCodexRequest = ; // WithdrawAdminAssetCodexRequest | 

try {
    final response = api.withdrawAdminBriefingTemplate(itemId, idempotencyKey, withdrawAdminAssetCodexRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminBriefingTemplateApi->withdrawAdminBriefingTemplate: $e\n');
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

