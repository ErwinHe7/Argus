# ritual_investing_api_client.api.DemoEntitlementsApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**confirmDemoCheckout**](DemoEntitlementsApi.md#confirmdemocheckout) | **POST** /v1/demo-checkout-sessions/{session_id}/confirm | 
[**createDemoCheckout**](DemoEntitlementsApi.md#createdemocheckout) | **POST** /v1/demo-checkout-sessions | 
[**downgradeDemoEntitlement**](DemoEntitlementsApi.md#downgradedemoentitlement) | **POST** /v1/me/entitlements/downgrade | 
[**getDemoCheckout**](DemoEntitlementsApi.md#getdemocheckout) | **GET** /v1/demo-checkout-sessions/{session_id} | 
[**getDemoEntitlement**](DemoEntitlementsApi.md#getdemoentitlement) | **GET** /v1/me/entitlements | 
[**listDemoPlans**](DemoEntitlementsApi.md#listdemoplans) | **GET** /v1/demo-plans | 
[**restoreDemoEntitlement**](DemoEntitlementsApi.md#restoredemoentitlement) | **POST** /v1/me/entitlements/restore | 


# **confirmDemoCheckout**
> ConfirmDemoCheckout200Response confirmDemoCheckout(sessionId, idempotencyKey, ifMatch, body)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getDemoEntitlementsApi();
final String sessionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = idempotencyKey_example; // String | 
final String ifMatch = ifMatch_example; // String | 
final Object body = Object; // Object | 

try {
    final response = api.confirmDemoCheckout(sessionId, idempotencyKey, ifMatch, body);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DemoEntitlementsApi->confirmDemoCheckout: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sessionId** | **String**|  | 
 **idempotencyKey** | **String**|  | 
 **ifMatch** | **String**|  | 
 **body** | **Object**|  | [optional] 

### Return type

[**ConfirmDemoCheckout200Response**](ConfirmDemoCheckout200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createDemoCheckout**
> CreateDemoCheckout201Response createDemoCheckout(idempotencyKey, createDemoCheckoutRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getDemoEntitlementsApi();
final String idempotencyKey = idempotencyKey_example; // String | 
final CreateDemoCheckoutRequest createDemoCheckoutRequest = ; // CreateDemoCheckoutRequest | 

try {
    final response = api.createDemoCheckout(idempotencyKey, createDemoCheckoutRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DemoEntitlementsApi->createDemoCheckout: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**|  | 
 **createDemoCheckoutRequest** | [**CreateDemoCheckoutRequest**](CreateDemoCheckoutRequest.md)|  | 

### Return type

[**CreateDemoCheckout201Response**](CreateDemoCheckout201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **downgradeDemoEntitlement**
> ConfirmDemoCheckout200Response downgradeDemoEntitlement(idempotencyKey, ifMatch, body)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getDemoEntitlementsApi();
final String idempotencyKey = idempotencyKey_example; // String | 
final String ifMatch = ifMatch_example; // String | 
final Object body = Object; // Object | 

try {
    final response = api.downgradeDemoEntitlement(idempotencyKey, ifMatch, body);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DemoEntitlementsApi->downgradeDemoEntitlement: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**|  | 
 **ifMatch** | **String**|  | 
 **body** | **Object**|  | [optional] 

### Return type

[**ConfirmDemoCheckout200Response**](ConfirmDemoCheckout200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getDemoCheckout**
> CreateDemoCheckout201Response getDemoCheckout(sessionId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getDemoEntitlementsApi();
final String sessionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getDemoCheckout(sessionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DemoEntitlementsApi->getDemoCheckout: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sessionId** | **String**|  | 

### Return type

[**CreateDemoCheckout201Response**](CreateDemoCheckout201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getDemoEntitlement**
> ConfirmDemoCheckout200Response getDemoEntitlement()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getDemoEntitlementsApi();

try {
    final response = api.getDemoEntitlement();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DemoEntitlementsApi->getDemoEntitlement: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**ConfirmDemoCheckout200Response**](ConfirmDemoCheckout200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listDemoPlans**
> ListDemoPlans200Response listDemoPlans()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getDemoEntitlementsApi();

try {
    final response = api.listDemoPlans();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DemoEntitlementsApi->listDemoPlans: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**ListDemoPlans200Response**](ListDemoPlans200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **restoreDemoEntitlement**
> ConfirmDemoCheckout200Response restoreDemoEntitlement(idempotencyKey, body)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getDemoEntitlementsApi();
final String idempotencyKey = idempotencyKey_example; // String | 
final Object body = Object; // Object | 

try {
    final response = api.restoreDemoEntitlement(idempotencyKey, body);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DemoEntitlementsApi->restoreDemoEntitlement: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**|  | 
 **body** | **Object**|  | [optional] 

### Return type

[**ConfirmDemoCheckout200Response**](ConfirmDemoCheckout200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

