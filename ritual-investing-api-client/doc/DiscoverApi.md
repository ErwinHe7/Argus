# ritual_investing_api_client.api.DiscoverApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getCircleTemplate**](DiscoverApi.md#getcircletemplate) | **GET** /v1/circle-templates/{id} | 
[**getGrimoire**](DiscoverApi.md#getgrimoire) | **GET** /v1/grimoires/{id} | 
[**listCircleTemplates**](DiscoverApi.md#listcircletemplates) | **GET** /v1/circle-templates | 
[**listDiscover**](DiscoverApi.md#listdiscover) | **GET** /v1/discover | 
[**listGrimoires**](DiscoverApi.md#listgrimoires) | **GET** /v1/grimoires | 
[**listSeededCreators**](DiscoverApi.md#listseededcreators) | **GET** /v1/community/creators | 


# **getCircleTemplate**
> CircleTemplateDetailResponse getCircleTemplate(id)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getDiscoverApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getCircleTemplate(id);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DiscoverApi->getCircleTemplate: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 

### Return type

[**CircleTemplateDetailResponse**](CircleTemplateDetailResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getGrimoire**
> GrimoireDetailResponse getGrimoire(id)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getDiscoverApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getGrimoire(id);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DiscoverApi->getGrimoire: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 

### Return type

[**GrimoireDetailResponse**](GrimoireDetailResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listCircleTemplates**
> CircleTemplateCollectionResponse listCircleTemplates(cursor, limit, theme, creator)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getDiscoverApi();
final String cursor = cursor_example; // String | 
final int limit = 56; // int | 
final String theme = theme_example; // String | 
final String creator = creator_example; // String | 

try {
    final response = api.listCircleTemplates(cursor, limit, theme, creator);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DiscoverApi->listCircleTemplates: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **cursor** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 20]
 **theme** | **String**|  | [optional] 
 **creator** | **String**|  | [optional] 

### Return type

[**CircleTemplateCollectionResponse**](CircleTemplateCollectionResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listDiscover**
> DiscoverResponse listDiscover(cursor, limit, section)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getDiscoverApi();
final String cursor = cursor_example; // String | 
final int limit = 56; // int | 
final String section = section_example; // String | 

try {
    final response = api.listDiscover(cursor, limit, section);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DiscoverApi->listDiscover: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **cursor** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 20]
 **section** | **String**|  | [optional] 

### Return type

[**DiscoverResponse**](DiscoverResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listGrimoires**
> GrimoireCollectionResponse listGrimoires(cursor, limit, theme)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getDiscoverApi();
final String cursor = cursor_example; // String | 
final int limit = 56; // int | 
final String theme = theme_example; // String | 

try {
    final response = api.listGrimoires(cursor, limit, theme);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DiscoverApi->listGrimoires: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **cursor** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 20]
 **theme** | **String**|  | [optional] 

### Return type

[**GrimoireCollectionResponse**](GrimoireCollectionResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listSeededCreators**
> CreatorCollectionResponse listSeededCreators(cursor, limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getDiscoverApi();
final String cursor = cursor_example; // String | 
final int limit = 56; // int | 

try {
    final response = api.listSeededCreators(cursor, limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DiscoverApi->listSeededCreators: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **cursor** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 20]

### Return type

[**CreatorCollectionResponse**](CreatorCollectionResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

