# ritual_investing_api_client.api.AccountApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getAccount**](AccountApi.md#getaccount) | **GET** /v1/account | 
[**recordConsent**](AccountApi.md#recordconsent) | **POST** /v1/consents | 
[**updatePreferences**](AccountApi.md#updatepreferences) | **PATCH** /v1/preferences | 


# **getAccount**
> GetAccount200Response getAccount()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAccountApi();

try {
    final response = api.getAccount();
    print(response);
} on DioException catch (e) {
    print('Exception when calling AccountApi->getAccount: $e\n');
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

# **recordConsent**
> GetAccount200Response recordConsent(recordConsentRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAccountApi();
final RecordConsentRequest recordConsentRequest = ; // RecordConsentRequest | 

try {
    final response = api.recordConsent(recordConsentRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AccountApi->recordConsent: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **recordConsentRequest** | [**RecordConsentRequest**](RecordConsentRequest.md)|  | 

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updatePreferences**
> GetAccount200Response updatePreferences(ifMatch, updatePreferencesRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAccountApi();
final String ifMatch = ifMatch_example; // String | 
final UpdatePreferencesRequest updatePreferencesRequest = ; // UpdatePreferencesRequest | 

try {
    final response = api.updatePreferences(ifMatch, updatePreferencesRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AccountApi->updatePreferences: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **ifMatch** | **String**|  | 
 **updatePreferencesRequest** | [**UpdatePreferencesRequest**](UpdatePreferencesRequest.md)|  | 

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

