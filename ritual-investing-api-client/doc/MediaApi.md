# ritual_investing_api_client.api.MediaApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createUploadIntent**](MediaApi.md#createuploadintent) | **POST** /v1/media/upload-intents | 
[**getUploadIntent**](MediaApi.md#getuploadintent) | **GET** /v1/media/upload-intents/{intent_id} | 


# **createUploadIntent**
> GetAccount200Response createUploadIntent(createUploadIntentRequest)



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

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getUploadIntent**
> GetAccount200Response getUploadIntent(intentId)



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

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

