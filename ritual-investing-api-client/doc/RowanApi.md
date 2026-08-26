# ritual_investing_api_client.api.RowanApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getRowanCounsel**](RowanApi.md#getrowancounsel) | **GET** /v1/rowan/counsel | 


# **getRowanCounsel**
> RowanCounselResponse getRowanCounsel(surface, contextCode, resourceId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getRowanApi();
final String surface = surface_example; // String | 
final String contextCode = contextCode_example; // String | 
final String resourceId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getRowanCounsel(surface, contextCode, resourceId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RowanApi->getRowanCounsel: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **surface** | **String**|  | 
 **contextCode** | **String**|  | 
 **resourceId** | **String**|  | [optional] 

### Return type

[**RowanCounselResponse**](RowanCounselResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

