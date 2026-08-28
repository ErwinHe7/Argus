# ritual_investing_api_client.api.AccountApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**deleteAstrologyProfile**](AccountApi.md#deleteastrologyprofile) | **DELETE** /v1/astrology-profile | 
[**getAccount**](AccountApi.md#getaccount) | **GET** /v1/account | 
[**recordConsent**](AccountApi.md#recordconsent) | **POST** /v1/consents | 
[**updateAstrologyProfile**](AccountApi.md#updateastrologyprofile) | **PUT** /v1/astrology-profile | 
[**updateInvestorProfile**](AccountApi.md#updateinvestorprofile) | **PUT** /v1/investor-profile | 
[**updatePreferences**](AccountApi.md#updatepreferences) | **PATCH** /v1/preferences | 


# **deleteAstrologyProfile**
> DeleteAstrologyProfileResponse deleteAstrologyProfile(ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAccountApi();
final String ifMatch = ifMatch_example; // String | 

try {
    final response = api.deleteAstrologyProfile(ifMatch);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AccountApi->deleteAstrologyProfile: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **ifMatch** | **String**|  | 

### Return type

[**DeleteAstrologyProfileResponse**](DeleteAstrologyProfileResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAccount**
> MemberAccountResponse getAccount()



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

[**MemberAccountResponse**](MemberAccountResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **recordConsent**
> ConsentReceiptResponse recordConsent(recordConsentRequest)



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

[**ConsentReceiptResponse**](ConsentReceiptResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateAstrologyProfile**
> AstrologyProfileResponse updateAstrologyProfile(updateAstrologyProfileRequest, ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAccountApi();
final UpdateAstrologyProfileRequest updateAstrologyProfileRequest = ; // UpdateAstrologyProfileRequest | 
final String ifMatch = ifMatch_example; // String | 

try {
    final response = api.updateAstrologyProfile(updateAstrologyProfileRequest, ifMatch);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AccountApi->updateAstrologyProfile: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **updateAstrologyProfileRequest** | [**UpdateAstrologyProfileRequest**](UpdateAstrologyProfileRequest.md)|  | 
 **ifMatch** | **String**|  | [optional] 

### Return type

[**AstrologyProfileResponse**](AstrologyProfileResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateInvestorProfile**
> InvestorProfileResponse updateInvestorProfile(updateInvestorProfileRequest, ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAccountApi();
final UpdateInvestorProfileRequest updateInvestorProfileRequest = ; // UpdateInvestorProfileRequest | 
final String ifMatch = ifMatch_example; // String | 

try {
    final response = api.updateInvestorProfile(updateInvestorProfileRequest, ifMatch);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AccountApi->updateInvestorProfile: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **updateInvestorProfileRequest** | [**UpdateInvestorProfileRequest**](UpdateInvestorProfileRequest.md)|  | 
 **ifMatch** | **String**|  | [optional] 

### Return type

[**InvestorProfileResponse**](InvestorProfileResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updatePreferences**
> UpdatePreferencesResponse updatePreferences(ifMatch, updatePreferencesRequest)



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

[**UpdatePreferencesResponse**](UpdatePreferencesResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

