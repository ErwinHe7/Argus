# ritual_investing_api_client.api.BriefingsApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getBriefing**](BriefingsApi.md#getbriefing) | **GET** /v1/briefings/{briefing_id} | 
[**getDailyBriefing**](BriefingsApi.md#getdailybriefing) | **GET** /v1/briefings/daily | 
[**listBriefings**](BriefingsApi.md#listbriefings) | **GET** /v1/briefings | 
[**setBriefingReadState**](BriefingsApi.md#setbriefingreadstate) | **PUT** /v1/briefings/{briefing_id}/read-state | 


# **getBriefing**
> GetBriefing200Response getBriefing(briefingId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getBriefingsApi();
final String briefingId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getBriefing(briefingId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BriefingsApi->getBriefing: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **briefingId** | **String**|  | 

### Return type

[**GetBriefing200Response**](GetBriefing200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getDailyBriefing**
> GetBriefing200Response getDailyBriefing(localDate)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getBriefingsApi();
final DateTime localDate = 2013-10-20; // DateTime | 

try {
    final response = api.getDailyBriefing(localDate);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BriefingsApi->getDailyBriefing: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **localDate** | **DateTime**|  | [optional] 

### Return type

[**GetBriefing200Response**](GetBriefing200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listBriefings**
> ListBriefings200Response listBriefings(type, periodStart, periodEnd, limit, cursor)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getBriefingsApi();
final String type = type_example; // String | 
final DateTime periodStart = 2013-10-20; // DateTime | 
final DateTime periodEnd = 2013-10-20; // DateTime | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 

try {
    final response = api.listBriefings(type, periodStart, periodEnd, limit, cursor);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BriefingsApi->listBriefings: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **type** | **String**|  | [optional] 
 **periodStart** | **DateTime**|  | [optional] 
 **periodEnd** | **DateTime**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 20]
 **cursor** | **String**|  | [optional] 

### Return type

[**ListBriefings200Response**](ListBriefings200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setBriefingReadState**
> SetBriefingReadState200Response setBriefingReadState(briefingId, setBriefingReadStateRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getBriefingsApi();
final String briefingId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final SetBriefingReadStateRequest setBriefingReadStateRequest = ; // SetBriefingReadStateRequest | 

try {
    final response = api.setBriefingReadState(briefingId, setBriefingReadStateRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BriefingsApi->setBriefingReadState: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **briefingId** | **String**|  | 
 **setBriefingReadStateRequest** | [**SetBriefingReadStateRequest**](SetBriefingReadStateRequest.md)|  | 

### Return type

[**SetBriefingReadState200Response**](SetBriefingReadState200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

