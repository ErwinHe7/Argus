# ritual_investing_api_client.api.FoundersCovenApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getCovenEntry**](FoundersCovenApi.md#getcovenentry) | **GET** /v1/coven/{entry_id} | 
[**getCovenEvidence**](FoundersCovenApi.md#getcovenevidence) | **GET** /v1/coven/{entry_id}/evidence | 
[**listCoven**](FoundersCovenApi.md#listcoven) | **GET** /v1/coven | 


# **getCovenEntry**
> CovenDetailResponse getCovenEntry(entryId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getFoundersCovenApi();
final String entryId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getCovenEntry(entryId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling FoundersCovenApi->getCovenEntry: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **entryId** | **String**|  | 

### Return type

[**CovenDetailResponse**](CovenDetailResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getCovenEvidence**
> CovenEvidenceResponse getCovenEvidence(entryId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getFoundersCovenApi();
final String entryId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getCovenEvidence(entryId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling FoundersCovenApi->getCovenEvidence: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **entryId** | **String**|  | 

### Return type

[**CovenEvidenceResponse**](CovenEvidenceResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listCoven**
> CovenCollectionResponse listCoven(category, verifiedAsOf, cursor, limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getFoundersCovenApi();
final String category = category_example; // String | 
final DateTime verifiedAsOf = 2013-10-20; // DateTime | 
final String cursor = cursor_example; // String | 
final int limit = 56; // int | 

try {
    final response = api.listCoven(category, verifiedAsOf, cursor, limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling FoundersCovenApi->listCoven: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **category** | **String**|  | [optional] 
 **verifiedAsOf** | **DateTime**|  | [optional] 
 **cursor** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 20]

### Return type

[**CovenCollectionResponse**](CovenCollectionResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

