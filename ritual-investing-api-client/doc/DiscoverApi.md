# ritual_investing_api_client.api.DiscoverApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getCircleTemplate**](DiscoverApi.md#getcircletemplate) | **GET** /v1/discover/circle-templates/{template_id} | 
[**getGrimoire**](DiscoverApi.md#getgrimoire) | **GET** /v1/discover/grimoires/{id} | 
[**getSeededCreator**](DiscoverApi.md#getseededcreator) | **GET** /v1/discover/creators/{id} | 
[**listCircleTemplates**](DiscoverApi.md#listcircletemplates) | **GET** /v1/discover/circle-templates | 
[**listDiscover**](DiscoverApi.md#listdiscover) | **GET** /v1/discover | 
[**listDiscoverAssets**](DiscoverApi.md#listdiscoverassets) | **GET** /v1/discover/assets | 
[**listGrimoires**](DiscoverApi.md#listgrimoires) | **GET** /v1/discover/grimoires | 
[**listSeededCreators**](DiscoverApi.md#listseededcreators) | **GET** /v1/discover/creators | 


# **getCircleTemplate**
> CircleTemplateDetailResponse getCircleTemplate(templateId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getDiscoverApi();
final String templateId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getCircleTemplate(templateId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DiscoverApi->getCircleTemplate: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **templateId** | **String**|  | 

### Return type

[**CircleTemplateDetailResponse**](CircleTemplateDetailResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getGrimoire**
> GrimoireDetailResponse getGrimoire(id)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

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

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getSeededCreator**
> CreatorResponse getSeededCreator(id)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getDiscoverApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getSeededCreator(id);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DiscoverApi->getSeededCreator: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 

### Return type

[**CreatorResponse**](CreatorResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listCircleTemplates**
> CircleTemplateCollectionResponse listCircleTemplates(cursor, limit, creator)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getDiscoverApi();
final String cursor = cursor_example; // String | 
final int limit = 56; // int | 
final String creator = creator_example; // String | 

try {
    final response = api.listCircleTemplates(cursor, limit, creator);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DiscoverApi->listCircleTemplates: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **cursor** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 25]
 **creator** | **String**|  | [optional] 

### Return type

[**CircleTemplateCollectionResponse**](CircleTemplateCollectionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listDiscover**
> DiscoverResponse listDiscover(cursor, limit, section)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

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
 **limit** | **int**|  | [optional] [default to 25]
 **section** | **String**|  | [optional] 

### Return type

[**DiscoverResponse**](DiscoverResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listDiscoverAssets**
> DiscoverAssetCollectionResponse listDiscoverAssets(cursor, limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getDiscoverApi();
final String cursor = cursor_example; // String | 
final int limit = 56; // int | 

try {
    final response = api.listDiscoverAssets(cursor, limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DiscoverApi->listDiscoverAssets: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **cursor** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 25]

### Return type

[**DiscoverAssetCollectionResponse**](DiscoverAssetCollectionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listGrimoires**
> GrimoireCollectionResponse listGrimoires(cursor, limit, theme)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

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
 **limit** | **int**|  | [optional] [default to 25]
 **theme** | **String**|  | [optional] 

### Return type

[**GrimoireCollectionResponse**](GrimoireCollectionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listSeededCreators**
> CreatorCollectionResponse listSeededCreators(cursor, limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

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
 **limit** | **int**|  | [optional] [default to 25]

### Return type

[**CreatorCollectionResponse**](CreatorCollectionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

