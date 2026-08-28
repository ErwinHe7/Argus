# ritual_investing_api_client.api.SavedApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**listSaved**](SavedApi.md#listsaved) | **GET** /v1/saved | 
[**saveItem**](SavedApi.md#saveitem) | **POST** /v1/saved/{item_kind}/{item_id} | 
[**unsaveItem**](SavedApi.md#unsaveitem) | **DELETE** /v1/saved/{item_kind}/{item_id} | 


# **listSaved**
> GetAccount200Response listSaved(limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getSavedApi();
final int limit = 56; // int | 

try {
    final response = api.listSaved(limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling SavedApi->listSaved: $e\n');
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

# **saveItem**
> GetAccount200Response saveItem(itemKind, itemId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getSavedApi();
final String itemKind = itemKind_example; // String | 
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.saveItem(itemKind, itemId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling SavedApi->saveItem: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemKind** | **String**|  | 
 **itemId** | **String**|  | 

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **unsaveItem**
> GetAccount200Response unsaveItem(itemKind, itemId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getSavedApi();
final String itemKind = itemKind_example; // String | 
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.unsaveItem(itemKind, itemId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling SavedApi->unsaveItem: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemKind** | **String**|  | 
 **itemId** | **String**|  | 

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

