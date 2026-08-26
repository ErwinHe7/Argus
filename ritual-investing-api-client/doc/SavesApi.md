# ritual_investing_api_client.api.SavesApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**saveAsset**](SavesApi.md#saveasset) | **PUT** /v1/me/saved-assets/{id} | 
[**saveCircleTemplate**](SavesApi.md#savecircletemplate) | **PUT** /v1/me/saved-circle-templates/{id} | 
[**saveCoven**](SavesApi.md#savecoven) | **PUT** /v1/me/saved-coven/{id} | 
[**saveGrimoire**](SavesApi.md#savegrimoire) | **PUT** /v1/me/saved-grimoires/{id} | 
[**unsaveAsset**](SavesApi.md#unsaveasset) | **DELETE** /v1/me/saved-assets/{id} | 
[**unsaveCircleTemplate**](SavesApi.md#unsavecircletemplate) | **DELETE** /v1/me/saved-circle-templates/{id} | 
[**unsaveCoven**](SavesApi.md#unsavecoven) | **DELETE** /v1/me/saved-coven/{id} | 
[**unsaveGrimoire**](SavesApi.md#unsavegrimoire) | **DELETE** /v1/me/saved-grimoires/{id} | 


# **saveAsset**
> SaveAsset200Response saveAsset(id, saveAssetRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getSavesApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final SaveAssetRequest saveAssetRequest = ; // SaveAssetRequest | 

try {
    final response = api.saveAsset(id, saveAssetRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling SavesApi->saveAsset: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 
 **saveAssetRequest** | [**SaveAssetRequest**](SaveAssetRequest.md)|  | [optional] 

### Return type

[**SaveAsset200Response**](SaveAsset200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **saveCircleTemplate**
> SaveAsset200Response saveCircleTemplate(id, saveAssetRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getSavesApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final SaveAssetRequest saveAssetRequest = ; // SaveAssetRequest | 

try {
    final response = api.saveCircleTemplate(id, saveAssetRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling SavesApi->saveCircleTemplate: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 
 **saveAssetRequest** | [**SaveAssetRequest**](SaveAssetRequest.md)|  | [optional] 

### Return type

[**SaveAsset200Response**](SaveAsset200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **saveCoven**
> SaveAsset200Response saveCoven(id, saveAssetRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getSavesApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final SaveAssetRequest saveAssetRequest = ; // SaveAssetRequest | 

try {
    final response = api.saveCoven(id, saveAssetRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling SavesApi->saveCoven: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 
 **saveAssetRequest** | [**SaveAssetRequest**](SaveAssetRequest.md)|  | [optional] 

### Return type

[**SaveAsset200Response**](SaveAsset200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **saveGrimoire**
> SaveAsset200Response saveGrimoire(id, saveAssetRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getSavesApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final SaveAssetRequest saveAssetRequest = ; // SaveAssetRequest | 

try {
    final response = api.saveGrimoire(id, saveAssetRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling SavesApi->saveGrimoire: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 
 **saveAssetRequest** | [**SaveAssetRequest**](SaveAssetRequest.md)|  | [optional] 

### Return type

[**SaveAsset200Response**](SaveAsset200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **unsaveAsset**
> unsaveAsset(id)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getSavesApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.unsaveAsset(id);
} on DioException catch (e) {
    print('Exception when calling SavesApi->unsaveAsset: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **unsaveCircleTemplate**
> unsaveCircleTemplate(id)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getSavesApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.unsaveCircleTemplate(id);
} on DioException catch (e) {
    print('Exception when calling SavesApi->unsaveCircleTemplate: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **unsaveCoven**
> unsaveCoven(id)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getSavesApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.unsaveCoven(id);
} on DioException catch (e) {
    print('Exception when calling SavesApi->unsaveCoven: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **unsaveGrimoire**
> unsaveGrimoire(id)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getSavesApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.unsaveGrimoire(id);
} on DioException catch (e) {
    print('Exception when calling SavesApi->unsaveGrimoire: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

