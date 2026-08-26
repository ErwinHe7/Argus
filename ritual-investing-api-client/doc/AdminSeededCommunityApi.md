# ritual_investing_api_client.api.AdminSeededCommunityApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createAdminSeededCreator**](AdminSeededCommunityApi.md#createadminseededcreator) | **POST** /v1/admin/seeded-creators | 
[**getAdminSeededCreator**](AdminSeededCommunityApi.md#getadminseededcreator) | **GET** /v1/admin/seeded-creators/{creator_id} | 
[**listAdminSeededCreators**](AdminSeededCommunityApi.md#listadminseededcreators) | **GET** /v1/admin/seeded-creators | 
[**patchAdminSeededCreator**](AdminSeededCommunityApi.md#patchadminseededcreator) | **PATCH** /v1/admin/seeded-creators/{creator_id} | 


# **createAdminSeededCreator**
> CreateAdminSeededCreator201Response createAdminSeededCreator(idempotencyKey, createAdminSeededCreatorRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminSeededCommunityApi();
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateAdminSeededCreatorRequest createAdminSeededCreatorRequest = ; // CreateAdminSeededCreatorRequest | 

try {
    final response = api.createAdminSeededCreator(idempotencyKey, createAdminSeededCreatorRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminSeededCommunityApi->createAdminSeededCreator: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createAdminSeededCreatorRequest** | [**CreateAdminSeededCreatorRequest**](CreateAdminSeededCreatorRequest.md)|  | 

### Return type

[**CreateAdminSeededCreator201Response**](CreateAdminSeededCreator201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAdminSeededCreator**
> CreateAdminSeededCreator201Response getAdminSeededCreator(creatorId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminSeededCommunityApi();
final String creatorId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAdminSeededCreator(creatorId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminSeededCommunityApi->getAdminSeededCreator: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **creatorId** | **String**|  | 

### Return type

[**CreateAdminSeededCreator201Response**](CreateAdminSeededCreator201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminSeededCreators**
> ListAdminSeededCreators200Response listAdminSeededCreators(status, type, search, limit, cursor)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminSeededCommunityApi();
final String status = status_example; // String | 
final String type = type_example; // String | 
final String search = search_example; // String | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 

try {
    final response = api.listAdminSeededCreators(status, type, search, limit, cursor);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminSeededCommunityApi->listAdminSeededCreators: $e\n');
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

[**ListAdminSeededCreators200Response**](ListAdminSeededCreators200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **patchAdminSeededCreator**
> CreateAdminSeededCreator201Response patchAdminSeededCreator(creatorId, ifMatch, patchAdminSeededCreatorRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminSeededCommunityApi();
final String creatorId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = "v3"; // String | 
final PatchAdminSeededCreatorRequest patchAdminSeededCreatorRequest = ; // PatchAdminSeededCreatorRequest | 

try {
    final response = api.patchAdminSeededCreator(creatorId, ifMatch, patchAdminSeededCreatorRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminSeededCommunityApi->patchAdminSeededCreator: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **creatorId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **patchAdminSeededCreatorRequest** | [**PatchAdminSeededCreatorRequest**](PatchAdminSeededCreatorRequest.md)|  | 

### Return type

[**CreateAdminSeededCreator201Response**](CreateAdminSeededCreator201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

