# ritual_investing_api_client.api.CirclesApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**archiveCircle**](CirclesApi.md#archivecircle) | **DELETE** /v1/circles/{circle_id} | 
[**copyCircleTemplate**](CirclesApi.md#copycircletemplate) | **POST** /v1/circle-templates/{template_id}/copy | 
[**createCircle**](CirclesApi.md#createcircle) | **POST** /v1/circles | 
[**deleteCircleAsset**](CirclesApi.md#deletecircleasset) | **DELETE** /v1/circles/{circle_id}/assets/{asset_id} | 
[**getCircle**](CirclesApi.md#getcircle) | **GET** /v1/circles/{circle_id} | 
[**listCircles**](CirclesApi.md#listcircles) | **GET** /v1/circles | 
[**putCircleAsset**](CirclesApi.md#putcircleasset) | **PUT** /v1/circles/{circle_id}/assets/{asset_id} | 
[**replaceCircleAssets**](CirclesApi.md#replacecircleassets) | **PUT** /v1/circles/{circle_id}/assets | 
[**updateCircle**](CirclesApi.md#updatecircle) | **PATCH** /v1/circles/{circle_id} | 


# **archiveCircle**
> CircleDetailResponse archiveCircle(circleId, ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getCirclesApi();
final String circleId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 

try {
    final response = api.archiveCircle(circleId, ifMatch);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->archiveCircle: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **circleId** | **String**|  | 
 **ifMatch** | **String**|  | 

### Return type

[**CircleDetailResponse**](CircleDetailResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **copyCircleTemplate**
> CircleDetailResponse copyCircleTemplate(templateId, idempotencyKey, copyCircleTemplateRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getCirclesApi();
final String templateId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = idempotencyKey_example; // String | 
final CopyCircleTemplateRequest copyCircleTemplateRequest = ; // CopyCircleTemplateRequest | 

try {
    final response = api.copyCircleTemplate(templateId, idempotencyKey, copyCircleTemplateRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->copyCircleTemplate: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **templateId** | **String**|  | 
 **idempotencyKey** | **String**|  | 
 **copyCircleTemplateRequest** | [**CopyCircleTemplateRequest**](CopyCircleTemplateRequest.md)|  | 

### Return type

[**CircleDetailResponse**](CircleDetailResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createCircle**
> CircleDetailResponse createCircle(idempotencyKey, createCircleRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getCirclesApi();
final String idempotencyKey = idempotencyKey_example; // String | 
final CreateCircleRequest createCircleRequest = ; // CreateCircleRequest | 

try {
    final response = api.createCircle(idempotencyKey, createCircleRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->createCircle: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**|  | 
 **createCircleRequest** | [**CreateCircleRequest**](CreateCircleRequest.md)|  | 

### Return type

[**CircleDetailResponse**](CircleDetailResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteCircleAsset**
> CircleDetailResponse deleteCircleAsset(circleId, assetId, ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getCirclesApi();
final String circleId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String assetId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 

try {
    final response = api.deleteCircleAsset(circleId, assetId, ifMatch);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->deleteCircleAsset: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **circleId** | **String**|  | 
 **assetId** | **String**|  | 
 **ifMatch** | **String**|  | 

### Return type

[**CircleDetailResponse**](CircleDetailResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getCircle**
> CircleDetailResponse getCircle(circleId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getCirclesApi();
final String circleId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getCircle(circleId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->getCircle: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **circleId** | **String**|  | 

### Return type

[**CircleDetailResponse**](CircleDetailResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listCircles**
> CircleCollectionResponse listCircles(archived, cursor, limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getCirclesApi();
final String archived = archived_example; // String | 
final String cursor = cursor_example; // String | 
final int limit = 56; // int | 

try {
    final response = api.listCircles(archived, cursor, limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->listCircles: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **archived** | **String**|  | [optional] 
 **cursor** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 25]

### Return type

[**CircleCollectionResponse**](CircleCollectionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **putCircleAsset**
> CircleDetailResponse putCircleAsset(circleId, assetId, ifMatch, putCircleAssetRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getCirclesApi();
final String circleId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String assetId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 
final PutCircleAssetRequest putCircleAssetRequest = ; // PutCircleAssetRequest | 

try {
    final response = api.putCircleAsset(circleId, assetId, ifMatch, putCircleAssetRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->putCircleAsset: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **circleId** | **String**|  | 
 **assetId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **putCircleAssetRequest** | [**PutCircleAssetRequest**](PutCircleAssetRequest.md)|  | 

### Return type

[**CircleDetailResponse**](CircleDetailResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **replaceCircleAssets**
> CircleDetailResponse replaceCircleAssets(circleId, ifMatch, replaceCircleAssetsRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getCirclesApi();
final String circleId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 
final ReplaceCircleAssetsRequest replaceCircleAssetsRequest = ; // ReplaceCircleAssetsRequest | 

try {
    final response = api.replaceCircleAssets(circleId, ifMatch, replaceCircleAssetsRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->replaceCircleAssets: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **circleId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **replaceCircleAssetsRequest** | [**ReplaceCircleAssetsRequest**](ReplaceCircleAssetsRequest.md)|  | 

### Return type

[**CircleDetailResponse**](CircleDetailResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateCircle**
> CircleDetailResponse updateCircle(circleId, ifMatch, updateCircleRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getCirclesApi();
final String circleId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 
final UpdateCircleRequest updateCircleRequest = ; // UpdateCircleRequest | 

try {
    final response = api.updateCircle(circleId, ifMatch, updateCircleRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->updateCircle: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **circleId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **updateCircleRequest** | [**UpdateCircleRequest**](UpdateCircleRequest.md)|  | 

### Return type

[**CircleDetailResponse**](CircleDetailResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

