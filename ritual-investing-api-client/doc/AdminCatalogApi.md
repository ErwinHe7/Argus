# ritual_investing_api_client.api.AdminCatalogApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createAdminAssetMetricSnapshot**](AdminCatalogApi.md#createadminassetmetricsnapshot) | **POST** /v1/admin/assets/{asset_id}/metric-snapshots | 
[**createAdminCovenQualification**](AdminCatalogApi.md#createadmincovenqualification) | **POST** /v1/admin/coven-entries/{entry_id}/qualifications | 
[**verifyAdminCovenQualification**](AdminCatalogApi.md#verifyadmincovenqualification) | **POST** /v1/admin/coven-qualifications/{qualification_id}/verifications | 


# **createAdminAssetMetricSnapshot**
> CreateAdminAssetMetricSnapshot201Response createAdminAssetMetricSnapshot(assetId, idempotencyKey, createAdminAssetMetricSnapshotRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminCatalogApi();
final String assetId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateAdminAssetMetricSnapshotRequest createAdminAssetMetricSnapshotRequest = ; // CreateAdminAssetMetricSnapshotRequest | 

try {
    final response = api.createAdminAssetMetricSnapshot(assetId, idempotencyKey, createAdminAssetMetricSnapshotRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminCatalogApi->createAdminAssetMetricSnapshot: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **assetId** | **String**|  | 
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createAdminAssetMetricSnapshotRequest** | [**CreateAdminAssetMetricSnapshotRequest**](CreateAdminAssetMetricSnapshotRequest.md)|  | 

### Return type

[**CreateAdminAssetMetricSnapshot201Response**](CreateAdminAssetMetricSnapshot201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createAdminCovenQualification**
> CreateAdminCovenQualification201Response createAdminCovenQualification(entryId, idempotencyKey, createAdminCovenQualificationRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminCatalogApi();
final String entryId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateAdminCovenQualificationRequest createAdminCovenQualificationRequest = ; // CreateAdminCovenQualificationRequest | 

try {
    final response = api.createAdminCovenQualification(entryId, idempotencyKey, createAdminCovenQualificationRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminCatalogApi->createAdminCovenQualification: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **entryId** | **String**|  | 
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createAdminCovenQualificationRequest** | [**CreateAdminCovenQualificationRequest**](CreateAdminCovenQualificationRequest.md)|  | 

### Return type

[**CreateAdminCovenQualification201Response**](CreateAdminCovenQualification201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **verifyAdminCovenQualification**
> VerifyAdminCovenQualification201Response verifyAdminCovenQualification(qualificationId, idempotencyKey, verifyAdminCovenQualificationRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';
// TODO Configure API key authorization: CloudflareAccess
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('CloudflareAccess').apiKeyPrefix = 'Bearer';

final api = RitualInvestingApiClient().getAdminCatalogApi();
final String qualificationId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final VerifyAdminCovenQualificationRequest verifyAdminCovenQualificationRequest = ; // VerifyAdminCovenQualificationRequest | 

try {
    final response = api.verifyAdminCovenQualification(qualificationId, idempotencyKey, verifyAdminCovenQualificationRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminCatalogApi->verifyAdminCovenQualification: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **qualificationId** | **String**|  | 
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **verifyAdminCovenQualificationRequest** | [**VerifyAdminCovenQualificationRequest**](VerifyAdminCovenQualificationRequest.md)|  | 

### Return type

[**VerifyAdminCovenQualification201Response**](VerifyAdminCovenQualification201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth), [CloudflareAccess](../README.md#CloudflareAccess)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

