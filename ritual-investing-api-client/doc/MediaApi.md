# ritual_investing_api_client.api.MediaApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createUploadIntent**](MediaApi.md#createuploadintent) | **POST** /v1/media/upload-intents | 
[**finalizeUpload**](MediaApi.md#finalizeupload) | **POST** /v1/media/upload-intents/{intent_id}/finalize | 
[**getUploadIntent**](MediaApi.md#getuploadintent) | **GET** /v1/media/upload-intents/{intent_id} | 


# **createUploadIntent**
> ListAdminAudit200Response createUploadIntent(createUploadIntentRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getMediaApi();
final CreateUploadIntentRequest createUploadIntentRequest = ; // CreateUploadIntentRequest | 

try {
    final response = api.createUploadIntent(createUploadIntentRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling MediaApi->createUploadIntent: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **createUploadIntentRequest** | [**CreateUploadIntentRequest**](CreateUploadIntentRequest.md)|  | 

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **finalizeUpload**
> ListAdminAudit200Response finalizeUpload(intentId, finalizeUploadRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getMediaApi();
final String intentId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final FinalizeUploadRequest finalizeUploadRequest = ; // FinalizeUploadRequest | 

try {
    final response = api.finalizeUpload(intentId, finalizeUploadRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling MediaApi->finalizeUpload: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **intentId** | **String**|  | 
 **finalizeUploadRequest** | [**FinalizeUploadRequest**](FinalizeUploadRequest.md)|  | 

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getUploadIntent**
> ListAdminAudit200Response getUploadIntent(intentId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getMediaApi();
final String intentId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getUploadIntent(intentId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling MediaApi->getUploadIntent: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **intentId** | **String**|  | 

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

