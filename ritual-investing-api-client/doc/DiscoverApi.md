# ritual_investing_api_client.api.DiscoverApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**listCircleTemplates**](DiscoverApi.md#listcircletemplates) | **GET** /v1/discover/circle-templates | 
[**listDiscoverAssets**](DiscoverApi.md#listdiscoverassets) | **GET** /v1/discover/assets | 
[**listGrimoires**](DiscoverApi.md#listgrimoires) | **GET** /v1/discover/grimoires | 


# **listCircleTemplates**
> GetAccount200Response listCircleTemplates(limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getDiscoverApi();
final int limit = 56; // int | 

try {
    final response = api.listCircleTemplates(limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DiscoverApi->listCircleTemplates: $e\n');
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

# **listDiscoverAssets**
> GetAccount200Response listDiscoverAssets(limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getDiscoverApi();
final int limit = 56; // int | 

try {
    final response = api.listDiscoverAssets(limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DiscoverApi->listDiscoverAssets: $e\n');
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

# **listGrimoires**
> GetAccount200Response listGrimoires(limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getDiscoverApi();
final int limit = 56; // int | 

try {
    final response = api.listGrimoires(limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DiscoverApi->listGrimoires: $e\n');
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

