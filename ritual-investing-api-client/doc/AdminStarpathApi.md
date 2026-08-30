# ritual_investing_api_client.api.AdminStarpathApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getAdminStarpathRevision**](AdminStarpathApi.md#getadminstarpathrevision) | **GET** /v1/admin/starpath/revisions/{revision_id} | 
[**publishAdminStarpathManifest**](AdminStarpathApi.md#publishadminstarpathmanifest) | **POST** /v1/admin/starpath/manifests/{manifest_id}/publish | 
[**reviewAdminStarpathRevision**](AdminStarpathApi.md#reviewadminstarpathrevision) | **POST** /v1/admin/starpath/revisions/{revision_id}/reviews | 
[**submitAdminStarpathRevision**](AdminStarpathApi.md#submitadminstarpathrevision) | **POST** /v1/admin/starpath/revisions/{revision_id}/submit | 


# **getAdminStarpathRevision**
> ListAdminAudit200Response getAdminStarpathRevision(revisionId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminStarpathApi();
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAdminStarpathRevision(revisionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminStarpathApi->getAdminStarpathRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **revisionId** | **String**|  | 

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **publishAdminStarpathManifest**
> ListAdminAudit200Response publishAdminStarpathManifest(manifestId, publishAdminStarpathManifestRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminStarpathApi();
final String manifestId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final PublishAdminStarpathManifestRequest publishAdminStarpathManifestRequest = ; // PublishAdminStarpathManifestRequest | 

try {
    final response = api.publishAdminStarpathManifest(manifestId, publishAdminStarpathManifestRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminStarpathApi->publishAdminStarpathManifest: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **manifestId** | **String**|  | 
 **publishAdminStarpathManifestRequest** | [**PublishAdminStarpathManifestRequest**](PublishAdminStarpathManifestRequest.md)|  | 

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **reviewAdminStarpathRevision**
> ListAdminAudit200Response reviewAdminStarpathRevision(revisionId, reviewAdminStarpathRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminStarpathApi();
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final ReviewAdminStarpathRevisionRequest reviewAdminStarpathRevisionRequest = ; // ReviewAdminStarpathRevisionRequest | 

try {
    final response = api.reviewAdminStarpathRevision(revisionId, reviewAdminStarpathRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminStarpathApi->reviewAdminStarpathRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **revisionId** | **String**|  | 
 **reviewAdminStarpathRevisionRequest** | [**ReviewAdminStarpathRevisionRequest**](ReviewAdminStarpathRevisionRequest.md)|  | 

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **submitAdminStarpathRevision**
> ListAdminAudit200Response submitAdminStarpathRevision(revisionId, submitAdminStarpathRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminStarpathApi();
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final SubmitAdminStarpathRevisionRequest submitAdminStarpathRevisionRequest = ; // SubmitAdminStarpathRevisionRequest | 

try {
    final response = api.submitAdminStarpathRevision(revisionId, submitAdminStarpathRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminStarpathApi->submitAdminStarpathRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **revisionId** | **String**|  | 
 **submitAdminStarpathRevisionRequest** | [**SubmitAdminStarpathRevisionRequest**](SubmitAdminStarpathRevisionRequest.md)|  | 

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

