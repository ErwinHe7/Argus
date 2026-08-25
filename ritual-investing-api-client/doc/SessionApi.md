# ritual_investing_api_client.api.SessionApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**bootstrapSession**](SessionApi.md#bootstrapsession) | **POST** /v1/session/bootstrap | 
[**finalizeOnboarding**](SessionApi.md#finalizeonboarding) | **POST** /v1/session/onboarding/finalize | 


# **bootstrapSession**
> SessionBootstrapResponse bootstrapSession()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getSessionApi();

try {
    final response = api.bootstrapSession();
    print(response);
} on DioException catch (e) {
    print('Exception when calling SessionApi->bootstrapSession: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**SessionBootstrapResponse**](SessionBootstrapResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **finalizeOnboarding**
> SessionBootstrapResponse finalizeOnboarding(idempotencyKey, finalizeOnboardingRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getSessionApi();
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final FinalizeOnboardingRequest finalizeOnboardingRequest = ; // FinalizeOnboardingRequest | 

try {
    final response = api.finalizeOnboarding(idempotencyKey, finalizeOnboardingRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling SessionApi->finalizeOnboarding: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **finalizeOnboardingRequest** | [**FinalizeOnboardingRequest**](FinalizeOnboardingRequest.md)|  | 

### Return type

[**SessionBootstrapResponse**](SessionBootstrapResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

