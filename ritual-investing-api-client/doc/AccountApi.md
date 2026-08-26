# ritual_investing_api_client.api.AccountApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createConsent**](AccountApi.md#createconsent) | **POST** /v1/me/consents | 
[**deleteAstrologyProfile**](AccountApi.md#deleteastrologyprofile) | **DELETE** /v1/me/astrology-profile | 
[**getAstrologyProfile**](AccountApi.md#getastrologyprofile) | **GET** /v1/me/astrology-profile | 
[**getInvestorProfile**](AccountApi.md#getinvestorprofile) | **GET** /v1/me/investor-profile | 
[**getMe**](AccountApi.md#getme) | **GET** /v1/me | 
[**getOnboarding**](AccountApi.md#getonboarding) | **GET** /v1/me/onboarding | 
[**getPreferences**](AccountApi.md#getpreferences) | **GET** /v1/me/preferences | 
[**patchOnboarding**](AccountApi.md#patchonboarding) | **PATCH** /v1/me/onboarding | 
[**patchPreferences**](AccountApi.md#patchpreferences) | **PATCH** /v1/me/preferences | 
[**patchProfile**](AccountApi.md#patchprofile) | **PATCH** /v1/me/profile | 
[**putAstrologyProfile**](AccountApi.md#putastrologyprofile) | **PUT** /v1/me/astrology-profile | 
[**putInvestorProfile**](AccountApi.md#putinvestorprofile) | **PUT** /v1/me/investor-profile | 


# **createConsent**
> ConsentReceiptResponse createConsent(createConsentRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getAccountApi();
final CreateConsentRequest createConsentRequest = ; // CreateConsentRequest | 

try {
    final response = api.createConsent(createConsentRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AccountApi->createConsent: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **createConsentRequest** | [**CreateConsentRequest**](CreateConsentRequest.md)|  | 

### Return type

[**ConsentReceiptResponse**](ConsentReceiptResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteAstrologyProfile**
> deleteAstrologyProfile(ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getAccountApi();
final String ifMatch = "v3"; // String | 

try {
    api.deleteAstrologyProfile(ifMatch);
} on DioException catch (e) {
    print('Exception when calling AccountApi->deleteAstrologyProfile: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **ifMatch** | **String**|  | [optional] 

### Return type

void (empty response body)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAstrologyProfile**
> AstrologyProfileResponse getAstrologyProfile()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getAccountApi();

try {
    final response = api.getAstrologyProfile();
    print(response);
} on DioException catch (e) {
    print('Exception when calling AccountApi->getAstrologyProfile: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**AstrologyProfileResponse**](AstrologyProfileResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getInvestorProfile**
> InvestorProfileResponse getInvestorProfile()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getAccountApi();

try {
    final response = api.getInvestorProfile();
    print(response);
} on DioException catch (e) {
    print('Exception when calling AccountApi->getInvestorProfile: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**InvestorProfileResponse**](InvestorProfileResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getMe**
> MemberAccountResponse getMe()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getAccountApi();

try {
    final response = api.getMe();
    print(response);
} on DioException catch (e) {
    print('Exception when calling AccountApi->getMe: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**MemberAccountResponse**](MemberAccountResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getOnboarding**
> OnboardingResponse getOnboarding()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getAccountApi();

try {
    final response = api.getOnboarding();
    print(response);
} on DioException catch (e) {
    print('Exception when calling AccountApi->getOnboarding: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**OnboardingResponse**](OnboardingResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getPreferences**
> MemberPreferencesResponse getPreferences()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getAccountApi();

try {
    final response = api.getPreferences();
    print(response);
} on DioException catch (e) {
    print('Exception when calling AccountApi->getPreferences: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**MemberPreferencesResponse**](MemberPreferencesResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **patchOnboarding**
> PatchOnboarding200Response patchOnboarding(ifMatch, patchOnboardingRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getAccountApi();
final String ifMatch = "v3"; // String | 
final PatchOnboardingRequest patchOnboardingRequest = ; // PatchOnboardingRequest | 

try {
    final response = api.patchOnboarding(ifMatch, patchOnboardingRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AccountApi->patchOnboarding: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **ifMatch** | **String**|  | 
 **patchOnboardingRequest** | [**PatchOnboardingRequest**](PatchOnboardingRequest.md)|  | 

### Return type

[**PatchOnboarding200Response**](PatchOnboarding200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **patchPreferences**
> PatchPreferences200Response patchPreferences(ifMatch, patchPreferencesRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getAccountApi();
final String ifMatch = "v3"; // String | 
final PatchPreferencesRequest patchPreferencesRequest = ; // PatchPreferencesRequest | 

try {
    final response = api.patchPreferences(ifMatch, patchPreferencesRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AccountApi->patchPreferences: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **ifMatch** | **String**|  | 
 **patchPreferencesRequest** | [**PatchPreferencesRequest**](PatchPreferencesRequest.md)|  | 

### Return type

[**PatchPreferences200Response**](PatchPreferences200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **patchProfile**
> MemberProfileResponse patchProfile(ifMatch, patchProfileRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getAccountApi();
final String ifMatch = "v3"; // String | 
final PatchProfileRequest patchProfileRequest = ; // PatchProfileRequest | 

try {
    final response = api.patchProfile(ifMatch, patchProfileRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AccountApi->patchProfile: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **ifMatch** | **String**|  | 
 **patchProfileRequest** | [**PatchProfileRequest**](PatchProfileRequest.md)|  | 

### Return type

[**MemberProfileResponse**](MemberProfileResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **putAstrologyProfile**
> PutAstrologyProfile200Response putAstrologyProfile(putAstrologyProfileRequest, ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getAccountApi();
final PutAstrologyProfileRequest putAstrologyProfileRequest = ; // PutAstrologyProfileRequest | 
final String ifMatch = "v3"; // String | 

try {
    final response = api.putAstrologyProfile(putAstrologyProfileRequest, ifMatch);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AccountApi->putAstrologyProfile: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **putAstrologyProfileRequest** | [**PutAstrologyProfileRequest**](PutAstrologyProfileRequest.md)|  | 
 **ifMatch** | **String**|  | [optional] 

### Return type

[**PutAstrologyProfile200Response**](PutAstrologyProfile200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **putInvestorProfile**
> PutInvestorProfile200Response putInvestorProfile(putInvestorProfileRequest, ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getAccountApi();
final PutInvestorProfileRequest putInvestorProfileRequest = ; // PutInvestorProfileRequest | 
final String ifMatch = "v3"; // String | 

try {
    final response = api.putInvestorProfile(putInvestorProfileRequest, ifMatch);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AccountApi->putInvestorProfile: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **putInvestorProfileRequest** | [**PutInvestorProfileRequest**](PutInvestorProfileRequest.md)|  | 
 **ifMatch** | **String**|  | [optional] 

### Return type

[**PutInvestorProfile200Response**](PutInvestorProfile200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

