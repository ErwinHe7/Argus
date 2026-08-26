# ritual_investing_api_client.api.RebalancingApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**commitRebalance**](RebalancingApi.md#commitrebalance) | **POST** /v1/portfolios/{portfolio_id}/rebalances | 
[**createRebalancePreview**](RebalancingApi.md#createrebalancepreview) | **POST** /v1/portfolios/{portfolio_id}/rebalance-previews | 


# **commitRebalance**
> CommitOrder200Response commitRebalance(portfolioId, idempotencyKey, commitOrderRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getRebalancingApi();
final String portfolioId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = idempotencyKey_example; // String | 
final CommitOrderRequest commitOrderRequest = ; // CommitOrderRequest | 

try {
    final response = api.commitRebalance(portfolioId, idempotencyKey, commitOrderRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RebalancingApi->commitRebalance: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **portfolioId** | **String**|  | 
 **idempotencyKey** | **String**|  | 
 **commitOrderRequest** | [**CommitOrderRequest**](CommitOrderRequest.md)|  | 

### Return type

[**CommitOrder200Response**](CommitOrder200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createRebalancePreview**
> CreateRebalancePreview200Response createRebalancePreview(portfolioId, createRebalancePreviewRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getRebalancingApi();
final String portfolioId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final CreateRebalancePreviewRequest createRebalancePreviewRequest = ; // CreateRebalancePreviewRequest | 

try {
    final response = api.createRebalancePreview(portfolioId, createRebalancePreviewRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RebalancingApi->createRebalancePreview: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **portfolioId** | **String**|  | 
 **createRebalancePreviewRequest** | [**CreateRebalancePreviewRequest**](CreateRebalancePreviewRequest.md)|  | 

### Return type

[**CreateRebalancePreview200Response**](CreateRebalancePreview200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

