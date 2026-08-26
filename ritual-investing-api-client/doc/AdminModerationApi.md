# ritual_investing_api_client.api.AdminModerationApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createAdminModerationCase**](AdminModerationApi.md#createadminmoderationcase) | **POST** /v1/admin/moderation/reports/{report_id}/cases | 
[**getAdminModerationCase**](AdminModerationApi.md#getadminmoderationcase) | **GET** /v1/admin/moderation/cases/{case_id} | 
[**listAdminModerationReports**](AdminModerationApi.md#listadminmoderationreports) | **GET** /v1/admin/moderation/reports | 
[**patchAdminModerationCase**](AdminModerationApi.md#patchadminmoderationcase) | **PATCH** /v1/admin/moderation/cases/{case_id} | 


# **createAdminModerationCase**
> GetAdminModerationCase200Response createAdminModerationCase(reportId, idempotencyKey, createAdminModerationCaseRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminModerationApi();
final String reportId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateAdminModerationCaseRequest createAdminModerationCaseRequest = ; // CreateAdminModerationCaseRequest | 

try {
    final response = api.createAdminModerationCase(reportId, idempotencyKey, createAdminModerationCaseRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminModerationApi->createAdminModerationCase: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **reportId** | **String**|  | 
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createAdminModerationCaseRequest** | [**CreateAdminModerationCaseRequest**](CreateAdminModerationCaseRequest.md)|  | 

### Return type

[**GetAdminModerationCase200Response**](GetAdminModerationCase200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAdminModerationCase**
> GetAdminModerationCase200Response getAdminModerationCase(caseId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminModerationApi();
final String caseId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAdminModerationCase(caseId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminModerationApi->getAdminModerationCase: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **caseId** | **String**|  | 

### Return type

[**GetAdminModerationCase200Response**](GetAdminModerationCase200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminModerationReports**
> ListAdminModerationReports200Response listAdminModerationReports(status, targetKind, from, to, limit, cursor)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminModerationApi();
final String status = status_example; // String | 
final String targetKind = targetKind_example; // String | 
final DateTime from = 2013-10-20T19:20:30+01:00; // DateTime | 
final DateTime to = 2013-10-20T19:20:30+01:00; // DateTime | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 

try {
    final response = api.listAdminModerationReports(status, targetKind, from, to, limit, cursor);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminModerationApi->listAdminModerationReports: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **status** | **String**|  | [optional] 
 **targetKind** | **String**|  | [optional] 
 **from** | **DateTime**|  | [optional] 
 **to** | **DateTime**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 20]
 **cursor** | **String**|  | [optional] 

### Return type

[**ListAdminModerationReports200Response**](ListAdminModerationReports200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **patchAdminModerationCase**
> GetAdminModerationCase200Response patchAdminModerationCase(caseId, ifMatch, patchAdminModerationCaseRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminModerationApi();
final String caseId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = "v3"; // String | 
final PatchAdminModerationCaseRequest patchAdminModerationCaseRequest = ; // PatchAdminModerationCaseRequest | 

try {
    final response = api.patchAdminModerationCase(caseId, ifMatch, patchAdminModerationCaseRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminModerationApi->patchAdminModerationCase: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **caseId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **patchAdminModerationCaseRequest** | [**PatchAdminModerationCaseRequest**](PatchAdminModerationCaseRequest.md)|  | 

### Return type

[**GetAdminModerationCase200Response**](GetAdminModerationCase200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

