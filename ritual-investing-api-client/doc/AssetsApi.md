# ritual_investing_api_client.api.AssetsApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**compareAssets**](AssetsApi.md#compareassets) | **POST** /v1/assets/compare | 
[**getAsset**](AssetsApi.md#getasset) | **GET** /v1/assets/{asset_id} | 
[**getAssetEvidence**](AssetsApi.md#getassetevidence) | **GET** /v1/assets/{asset_id}/evidence | 
[**getAssetMetrics**](AssetsApi.md#getassetmetrics) | **GET** /v1/assets/{asset_id}/metrics | 
[**listAssets**](AssetsApi.md#listassets) | **GET** /v1/assets | 


# **compareAssets**
> AssetComparisonResponse compareAssets(compareAssetsRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAssetsApi();
final CompareAssetsRequest compareAssetsRequest = ; // CompareAssetsRequest | 

try {
    final response = api.compareAssets(compareAssetsRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AssetsApi->compareAssets: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **compareAssetsRequest** | [**CompareAssetsRequest**](CompareAssetsRequest.md)|  | 

### Return type

[**AssetComparisonResponse**](AssetComparisonResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAsset**
> AssetDetailResponse getAsset(assetId)



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

[**AssetDetailResponse**](AssetDetailResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAssetEvidence**
> AssetEvidenceResponse getAssetEvidence(assetId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAssetsApi();
final String assetId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAssetEvidence(assetId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AssetsApi->getAssetEvidence: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **assetId** | **String**|  | 

### Return type

[**AssetEvidenceResponse**](AssetEvidenceResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAssetMetrics**
> AssetMetricsResponse getAssetMetrics(assetId, asOf)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAssetsApi();
final String assetId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final DateTime asOf = 2013-10-20T19:20:30+01:00; // DateTime | 

try {
    final response = api.getAssetMetrics(assetId, asOf);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AssetsApi->getAssetMetrics: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **assetId** | **String**|  | 
 **asOf** | **DateTime**|  | [optional] 

### Return type

[**AssetMetricsResponse**](AssetMetricsResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAssets**
> AssetCollectionResponse listAssets(limit, assetType, symbolPrefix)



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

[**AssetCollectionResponse**](AssetCollectionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

