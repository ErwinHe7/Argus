# ritual_investing_api_client.api.OrdersApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**commitOrder**](OrdersApi.md#commitorder) | **POST** /v1/portfolios/{portfolio_id}/orders | 
[**createOrderPreview**](OrdersApi.md#createorderpreview) | **POST** /v1/portfolios/{portfolio_id}/order-previews | 
[**getOrder**](OrdersApi.md#getorder) | **GET** /v1/orders/{order_id} | 
[**listOrders**](OrdersApi.md#listorders) | **GET** /v1/orders | 


# **commitOrder**
> CommitOrder200Response commitOrder(portfolioId, idempotencyKey, commitOrderRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getOrdersApi();
final String portfolioId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = idempotencyKey_example; // String | 
final CommitOrderRequest commitOrderRequest = ; // CommitOrderRequest | 

try {
    final response = api.commitOrder(portfolioId, idempotencyKey, commitOrderRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling OrdersApi->commitOrder: $e\n');
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

# **createOrderPreview**
> CreateOrderPreview200Response createOrderPreview(portfolioId, createOrderPreviewRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getOrdersApi();
final String portfolioId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final CreateOrderPreviewRequest createOrderPreviewRequest = ; // CreateOrderPreviewRequest | 

try {
    final response = api.createOrderPreview(portfolioId, createOrderPreviewRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling OrdersApi->createOrderPreview: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **portfolioId** | **String**|  | 
 **createOrderPreviewRequest** | [**CreateOrderPreviewRequest**](CreateOrderPreviewRequest.md)|  | 

### Return type

[**CreateOrderPreview200Response**](CreateOrderPreview200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getOrder**
> GetOrder200Response getOrder(orderId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getOrdersApi();
final String orderId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getOrder(orderId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling OrdersApi->getOrder: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **orderId** | **String**|  | 

### Return type

[**GetOrder200Response**](GetOrder200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listOrders**
> ListOrders200Response listOrders(limit, cursor, portfolioId, status)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getOrdersApi();
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 
final String portfolioId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String status = status_example; // String | 

try {
    final response = api.listOrders(limit, cursor, portfolioId, status);
    print(response);
} on DioException catch (e) {
    print('Exception when calling OrdersApi->listOrders: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **limit** | **int**|  | [optional] [default to 20]
 **cursor** | **String**|  | [optional] 
 **portfolioId** | **String**|  | [optional] 
 **status** | **String**|  | [optional] 

### Return type

[**ListOrders200Response**](ListOrders200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

