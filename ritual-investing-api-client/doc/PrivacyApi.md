# ritual_investing_api_client.api.PrivacyApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**listPrivacyRequests**](PrivacyApi.md#listprivacyrequests) | **GET** /v1/privacy/requests | 
[**requestPrivacyAction**](PrivacyApi.md#requestprivacyaction) | **POST** /v1/privacy/requests | 


# **listPrivacyRequests**
> GetAccount200Response listPrivacyRequests()



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

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **requestPrivacyAction**
> GetAccount200Response requestPrivacyAction(idempotencyKey, requestPrivacyActionRequest)



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

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

