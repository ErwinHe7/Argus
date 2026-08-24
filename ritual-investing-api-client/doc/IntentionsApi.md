# ritual_investing_api_client.api.IntentionsApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**archiveIntention**](IntentionsApi.md#archiveintention) | **DELETE** /v1/intentions/{intention_id} | 
[**createIntention**](IntentionsApi.md#createintention) | **POST** /v1/intentions | 
[**getIntention**](IntentionsApi.md#getintention) | **GET** /v1/intentions/{intention_id} | 
[**listIntentions**](IntentionsApi.md#listintentions) | **GET** /v1/intentions | 
[**patchIntention**](IntentionsApi.md#patchintention) | **PATCH** /v1/intentions/{intention_id} | 


# **archiveIntention**
> archiveIntention(intentionId, ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getIntentionsApi();
final String intentionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 

try {
    api.archiveIntention(intentionId, ifMatch);
} on DioException catch (e) {
    print('Exception when calling IntentionsApi->archiveIntention: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **intentionId** | **String**|  | 
 **ifMatch** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createIntention**
> CreateIntention201Response createIntention(idempotencyKey, createIntentionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getIntentionsApi();
final String idempotencyKey = idempotencyKey_example; // String | 
final CreateIntentionRequest createIntentionRequest = ; // CreateIntentionRequest | 

try {
    final response = api.createIntention(idempotencyKey, createIntentionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling IntentionsApi->createIntention: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**|  | 
 **createIntentionRequest** | [**CreateIntentionRequest**](CreateIntentionRequest.md)|  | 

### Return type

[**CreateIntention201Response**](CreateIntention201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getIntention**
> CreateIntention201Response getIntention(intentionId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getIntentionsApi();
final String intentionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getIntention(intentionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling IntentionsApi->getIntention: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **intentionId** | **String**|  | 

### Return type

[**CreateIntention201Response**](CreateIntention201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listIntentions**
> ListIntentions200Response listIntentions(limit, cursor, status)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getIntentionsApi();
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 
final String status = status_example; // String | 

try {
    final response = api.listIntentions(limit, cursor, status);
    print(response);
} on DioException catch (e) {
    print('Exception when calling IntentionsApi->listIntentions: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **limit** | **int**|  | [optional] [default to 20]
 **cursor** | **String**|  | [optional] 
 **status** | **String**|  | [optional] 

### Return type

[**ListIntentions200Response**](ListIntentions200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **patchIntention**
> CreateIntention201Response patchIntention(intentionId, ifMatch, patchIntentionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getIntentionsApi();
final String intentionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 
final PatchIntentionRequest patchIntentionRequest = ; // PatchIntentionRequest | 

try {
    final response = api.patchIntention(intentionId, ifMatch, patchIntentionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling IntentionsApi->patchIntention: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **intentionId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **patchIntentionRequest** | [**PatchIntentionRequest**](PatchIntentionRequest.md)|  | 

### Return type

[**CreateIntention201Response**](CreateIntention201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

