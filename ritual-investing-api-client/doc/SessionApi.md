# ritual_investing_api_client.api.SessionApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**bootstrapSession**](SessionApi.md#bootstrapsession) | **POST** /v1/session/bootstrap | 
[**finalizeBirthdayOnboarding**](SessionApi.md#finalizebirthdayonboarding) | **POST** /v1/session/onboarding/birthday/finalize | 
[**finalizeOnboarding**](SessionApi.md#finalizeonboarding) | **POST** /v1/session/onboarding/finalize | 


# **bootstrapSession**
> SessionBootstrapResponse bootstrapSession()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

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

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **finalizeBirthdayOnboarding**
> SessionBootstrapResponse finalizeBirthdayOnboarding(idempotencyKey, finalizeBirthdayOnboardingRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getSessionApi();
final String idempotencyKey = idempotencyKey_example; // String | 
final FinalizeBirthdayOnboardingRequest finalizeBirthdayOnboardingRequest = ; // FinalizeBirthdayOnboardingRequest | 

try {
    final response = api.finalizeBirthdayOnboarding(idempotencyKey, finalizeBirthdayOnboardingRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling SessionApi->finalizeBirthdayOnboarding: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**|  | 
 **finalizeBirthdayOnboardingRequest** | [**FinalizeBirthdayOnboardingRequest**](FinalizeBirthdayOnboardingRequest.md)|  | 

### Return type

[**SessionBootstrapResponse**](SessionBootstrapResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **finalizeOnboarding**
> SessionBootstrapResponse finalizeOnboarding(idempotencyKey, finalizeOnboardingRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getSessionApi();
final String idempotencyKey = idempotencyKey_example; // String | 
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
 **idempotencyKey** | **String**|  | 
 **finalizeOnboardingRequest** | [**FinalizeOnboardingRequest**](FinalizeOnboardingRequest.md)|  | 

### Return type

[**SessionBootstrapResponse**](SessionBootstrapResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

