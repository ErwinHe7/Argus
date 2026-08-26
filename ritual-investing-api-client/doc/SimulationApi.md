# ritual_investing_api_client.api.SimulationApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createDemoContribution**](SimulationApi.md#createdemocontribution) | **POST** /v1/portfolios/{portfolio_id}/contributions | 
[**resetDemoState**](SimulationApi.md#resetdemostate) | **POST** /v1/me/demo-reset | 


# **createDemoContribution**
> SimulationResultResponse createDemoContribution(portfolioId, idempotencyKey, createDemoContributionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getSimulationApi();
final String portfolioId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = idempotencyKey_example; // String | 
final CreateDemoContributionRequest createDemoContributionRequest = ; // CreateDemoContributionRequest | 

try {
    final response = api.createDemoContribution(portfolioId, idempotencyKey, createDemoContributionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling SimulationApi->createDemoContribution: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **portfolioId** | **String**|  | 
 **idempotencyKey** | **String**|  | 
 **createDemoContributionRequest** | [**CreateDemoContributionRequest**](CreateDemoContributionRequest.md)|  | 

### Return type

[**SimulationResultResponse**](SimulationResultResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **resetDemoState**
> ResetDemoState200Response resetDemoState(idempotencyKey, resetDemoStateRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getSimulationApi();
final String idempotencyKey = idempotencyKey_example; // String | 
final ResetDemoStateRequest resetDemoStateRequest = ; // ResetDemoStateRequest | 

try {
    final response = api.resetDemoState(idempotencyKey, resetDemoStateRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling SimulationApi->resetDemoState: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**|  | 
 **resetDemoStateRequest** | [**ResetDemoStateRequest**](ResetDemoStateRequest.md)|  | 

### Return type

[**ResetDemoState200Response**](ResetDemoState200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

