# ritual_investing_api_client.api.AdminEvidenceApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createAdminEvidenceClaim**](AdminEvidenceApi.md#createadminevidenceclaim) | **POST** /v1/admin/evidence-claims | 
[**createAdminEvidenceSource**](AdminEvidenceApi.md#createadminevidencesource) | **POST** /v1/admin/evidence-sources | 
[**getAdminEvidenceClaim**](AdminEvidenceApi.md#getadminevidenceclaim) | **GET** /v1/admin/evidence-claims/{claim_id} | 
[**getAdminEvidenceSource**](AdminEvidenceApi.md#getadminevidencesource) | **GET** /v1/admin/evidence-sources/{source_id} | 
[**listAdminEvidenceClaims**](AdminEvidenceApi.md#listadminevidenceclaims) | **GET** /v1/admin/evidence-claims | 
[**listAdminEvidenceSources**](AdminEvidenceApi.md#listadminevidencesources) | **GET** /v1/admin/evidence-sources | 
[**patchAdminEvidenceSource**](AdminEvidenceApi.md#patchadminevidencesource) | **PATCH** /v1/admin/evidence-sources/{source_id} | 


# **createAdminEvidenceClaim**
> CreateAdminEvidenceClaim201Response createAdminEvidenceClaim(idempotencyKey, createAdminEvidenceClaimRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminEvidenceApi();
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateAdminEvidenceClaimRequest createAdminEvidenceClaimRequest = ; // CreateAdminEvidenceClaimRequest | 

try {
    final response = api.createAdminEvidenceClaim(idempotencyKey, createAdminEvidenceClaimRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminEvidenceApi->createAdminEvidenceClaim: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createAdminEvidenceClaimRequest** | [**CreateAdminEvidenceClaimRequest**](CreateAdminEvidenceClaimRequest.md)|  | 

### Return type

[**CreateAdminEvidenceClaim201Response**](CreateAdminEvidenceClaim201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createAdminEvidenceSource**
> CreateAdminEvidenceSource201Response createAdminEvidenceSource(idempotencyKey, createAdminEvidenceSourceRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminEvidenceApi();
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateAdminEvidenceSourceRequest createAdminEvidenceSourceRequest = ; // CreateAdminEvidenceSourceRequest | 

try {
    final response = api.createAdminEvidenceSource(idempotencyKey, createAdminEvidenceSourceRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminEvidenceApi->createAdminEvidenceSource: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createAdminEvidenceSourceRequest** | [**CreateAdminEvidenceSourceRequest**](CreateAdminEvidenceSourceRequest.md)|  | 

### Return type

[**CreateAdminEvidenceSource201Response**](CreateAdminEvidenceSource201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAdminEvidenceClaim**
> CreateAdminEvidenceClaim201Response getAdminEvidenceClaim(claimId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminEvidenceApi();
final String claimId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAdminEvidenceClaim(claimId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminEvidenceApi->getAdminEvidenceClaim: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **claimId** | **String**|  | 

### Return type

[**CreateAdminEvidenceClaim201Response**](CreateAdminEvidenceClaim201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAdminEvidenceSource**
> CreateAdminEvidenceSource201Response getAdminEvidenceSource(sourceId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminEvidenceApi();
final String sourceId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAdminEvidenceSource(sourceId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminEvidenceApi->getAdminEvidenceSource: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sourceId** | **String**|  | 

### Return type

[**CreateAdminEvidenceSource201Response**](CreateAdminEvidenceSource201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminEvidenceClaims**
> ListAdminEvidenceClaims200Response listAdminEvidenceClaims(status, type, search, limit, cursor)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminEvidenceApi();
final String status = status_example; // String | 
final String type = type_example; // String | 
final String search = search_example; // String | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 

try {
    final response = api.listAdminEvidenceClaims(status, type, search, limit, cursor);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminEvidenceApi->listAdminEvidenceClaims: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **status** | **String**|  | [optional] 
 **type** | **String**|  | [optional] 
 **search** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 20]
 **cursor** | **String**|  | [optional] 

### Return type

[**ListAdminEvidenceClaims200Response**](ListAdminEvidenceClaims200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminEvidenceSources**
> ListAdminEvidenceSources200Response listAdminEvidenceSources(status, type, search, limit, cursor)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminEvidenceApi();
final String status = status_example; // String | 
final String type = type_example; // String | 
final String search = search_example; // String | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 

try {
    final response = api.listAdminEvidenceSources(status, type, search, limit, cursor);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminEvidenceApi->listAdminEvidenceSources: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **status** | **String**|  | [optional] 
 **type** | **String**|  | [optional] 
 **search** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 20]
 **cursor** | **String**|  | [optional] 

### Return type

[**ListAdminEvidenceSources200Response**](ListAdminEvidenceSources200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **patchAdminEvidenceSource**
> CreateAdminEvidenceSource201Response patchAdminEvidenceSource(sourceId, ifMatch, patchAdminEvidenceSourceRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminEvidenceApi();
final String sourceId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = "v3"; // String | 
final PatchAdminEvidenceSourceRequest patchAdminEvidenceSourceRequest = ; // PatchAdminEvidenceSourceRequest | 

try {
    final response = api.patchAdminEvidenceSource(sourceId, ifMatch, patchAdminEvidenceSourceRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminEvidenceApi->patchAdminEvidenceSource: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sourceId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **patchAdminEvidenceSourceRequest** | [**PatchAdminEvidenceSourceRequest**](PatchAdminEvidenceSourceRequest.md)|  | 

### Return type

[**CreateAdminEvidenceSource201Response**](CreateAdminEvidenceSource201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

