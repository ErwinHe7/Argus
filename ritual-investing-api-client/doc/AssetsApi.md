# ritual_investing_api_client.api.AssetsApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getAsset**](AssetsApi.md#getasset) | **GET** /v1/assets/{asset_id} | 
[**listAssets**](AssetsApi.md#listassets) | **GET** /v1/assets | 


# **getAsset**
> GetAccount200Response getAsset(assetId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAssetsApi();
final String assetId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAsset(assetId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AssetsApi->getAsset: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **assetId** | **String**|  | 

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAssets**
> GetAccount200Response listAssets(limit, assetType, symbolPrefix)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAssetsApi();
final int limit = 56; // int | 
final String assetType = assetType_example; // String | 
final String symbolPrefix = symbolPrefix_example; // String | 

try {
    final response = api.listAssets(limit, assetType, symbolPrefix);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AssetsApi->listAssets: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **limit** | **int**|  | [optional] [default to 25]
 **assetType** | **String**|  | [optional] 
 **symbolPrefix** | **String**|  | [optional] 

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

