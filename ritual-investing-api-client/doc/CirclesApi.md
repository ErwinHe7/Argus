# ritual_investing_api_client.api.CirclesApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createCircle**](CirclesApi.md#createcircle) | **POST** /v1/circles | 
[**getCircle**](CirclesApi.md#getcircle) | **GET** /v1/circles/{circle_id} | 
[**listCircles**](CirclesApi.md#listcircles) | **GET** /v1/circles | 
[**updateCircle**](CirclesApi.md#updatecircle) | **PATCH** /v1/circles/{circle_id} | 


# **createCircle**
> GetAccount200Response createCircle(createCircleRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getCirclesApi();
final CreateCircleRequest createCircleRequest = ; // CreateCircleRequest | 

try {
    final response = api.createCircle(createCircleRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->createCircle: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **createCircleRequest** | [**CreateCircleRequest**](CreateCircleRequest.md)|  | 

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getCircle**
> GetAccount200Response getCircle(circleId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getCirclesApi();
final String circleId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getCircle(circleId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->getCircle: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **circleId** | **String**|  | 

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listCircles**
> GetAccount200Response listCircles(limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getCirclesApi();
final int limit = 56; // int | 

try {
    final response = api.listCircles(limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->listCircles: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **limit** | **int**|  | [optional] [default to 25]

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateCircle**
> GetAccount200Response updateCircle(circleId, ifMatch, updateCircleRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getCirclesApi();
final String circleId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 
final UpdateCircleRequest updateCircleRequest = ; // UpdateCircleRequest | 

try {
    final response = api.updateCircle(circleId, ifMatch, updateCircleRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->updateCircle: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **circleId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **updateCircleRequest** | [**UpdateCircleRequest**](UpdateCircleRequest.md)|  | 

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

