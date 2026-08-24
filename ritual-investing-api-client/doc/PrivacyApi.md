# ritual_investing_api_client.api.PrivacyApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**downloadPrivacyExport**](PrivacyApi.md#downloadprivacyexport) | **GET** /v1/me/privacy/exports/{request_id}/download | 
[**getPrivacyExport**](PrivacyApi.md#getprivacyexport) | **GET** /v1/me/privacy/exports/{request_id} | 
[**requestAccountDeletion**](PrivacyApi.md#requestaccountdeletion) | **POST** /v1/me/privacy/deletion-requests | 
[**requestPrivacyExport**](PrivacyApi.md#requestprivacyexport) | **POST** /v1/me/privacy/exports | 


# **downloadPrivacyExport**
> Object downloadPrivacyExport(requestId, token)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getPrivacyApi();
final String requestId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String token = token_example; // String | 

try {
    final response = api.downloadPrivacyExport(requestId, token);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PrivacyApi->downloadPrivacyExport: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **requestId** | **String**|  | 
 **token** | **String**|  | 

### Return type

**Object**

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/zip, application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getPrivacyExport**
> RequestPrivacyExport202Response getPrivacyExport(requestId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getPrivacyApi();
final String requestId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getPrivacyExport(requestId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PrivacyApi->getPrivacyExport: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **requestId** | **String**|  | 

### Return type

[**RequestPrivacyExport202Response**](RequestPrivacyExport202Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **requestAccountDeletion**
> RequestAccountDeletion202Response requestAccountDeletion(idempotencyKey, requestAccountDeletionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getPrivacyApi();
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final RequestAccountDeletionRequest requestAccountDeletionRequest = ; // RequestAccountDeletionRequest | 

try {
    final response = api.requestAccountDeletion(idempotencyKey, requestAccountDeletionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PrivacyApi->requestAccountDeletion: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **requestAccountDeletionRequest** | [**RequestAccountDeletionRequest**](RequestAccountDeletionRequest.md)|  | 

### Return type

[**RequestAccountDeletion202Response**](RequestAccountDeletion202Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **requestPrivacyExport**
> RequestPrivacyExport202Response requestPrivacyExport(idempotencyKey, requestPrivacyExportRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getPrivacyApi();
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final RequestPrivacyExportRequest requestPrivacyExportRequest = ; // RequestPrivacyExportRequest | 

try {
    final response = api.requestPrivacyExport(idempotencyKey, requestPrivacyExportRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PrivacyApi->requestPrivacyExport: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **requestPrivacyExportRequest** | [**RequestPrivacyExportRequest**](RequestPrivacyExportRequest.md)|  | 

### Return type

[**RequestPrivacyExport202Response**](RequestPrivacyExport202Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

