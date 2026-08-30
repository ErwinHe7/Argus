# ritual_investing_api_client.api.PrivacyApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createPrivacyDownloadUrl**](PrivacyApi.md#createprivacydownloadurl) | **POST** /v1/privacy/requests/{request_id}/download-url | 
[**downloadPrivacyExport**](PrivacyApi.md#downloadprivacyexport) | **GET** /v1/privacy/requests/{request_id}/download | 
[**listPrivacyRequests**](PrivacyApi.md#listprivacyrequests) | **GET** /v1/privacy/requests | 
[**requestPrivacyAction**](PrivacyApi.md#requestprivacyaction) | **POST** /v1/privacy/requests | 


# **createPrivacyDownloadUrl**
> PrivacyDownloadUrlResponse createPrivacyDownloadUrl(requestId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getPrivacyApi();
final String requestId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.createPrivacyDownloadUrl(requestId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PrivacyApi->createPrivacyDownloadUrl: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **requestId** | **String**|  | 

### Return type

[**PrivacyDownloadUrlResponse**](PrivacyDownloadUrlResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **downloadPrivacyExport**
> Uint8List downloadPrivacyExport(requestId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getPrivacyApi();
final String requestId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.downloadPrivacyExport(requestId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PrivacyApi->downloadPrivacyExport: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **requestId** | **String**|  | 

### Return type

[**Uint8List**](Uint8List.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/zip, application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listPrivacyRequests**
> PrivacyRequestCollectionResponse listPrivacyRequests()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getPrivacyApi();

try {
    final response = api.listPrivacyRequests();
    print(response);
} on DioException catch (e) {
    print('Exception when calling PrivacyApi->listPrivacyRequests: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**PrivacyRequestCollectionResponse**](PrivacyRequestCollectionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **requestPrivacyAction**
> PrivacyRequestResponse requestPrivacyAction(idempotencyKey, requestPrivacyActionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getPrivacyApi();
final String idempotencyKey = idempotencyKey_example; // String | 
final RequestPrivacyActionRequest requestPrivacyActionRequest = ; // RequestPrivacyActionRequest | 

try {
    final response = api.requestPrivacyAction(idempotencyKey, requestPrivacyActionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PrivacyApi->requestPrivacyAction: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**|  | 
 **requestPrivacyActionRequest** | [**RequestPrivacyActionRequest**](RequestPrivacyActionRequest.md)|  | 

### Return type

[**PrivacyRequestResponse**](PrivacyRequestResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

