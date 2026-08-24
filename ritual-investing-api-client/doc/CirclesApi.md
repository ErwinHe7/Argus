# ritual_investing_api_client.api.CirclesApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**archiveCircle**](CirclesApi.md#archivecircle) | **DELETE** /v1/circles/{id} | 
[**copyCircleTemplate**](CirclesApi.md#copycircletemplate) | **POST** /v1/circle-templates/{id}/copies | 
[**createCircle**](CirclesApi.md#createcircle) | **POST** /v1/circles | 
[**deleteCircleAsset**](CirclesApi.md#deletecircleasset) | **DELETE** /v1/circles/{id}/assets/{asset_id} | 
[**getCircle**](CirclesApi.md#getcircle) | **GET** /v1/circles/{id} | 
[**listCircles**](CirclesApi.md#listcircles) | **GET** /v1/circles | 
[**patchCircle**](CirclesApi.md#patchcircle) | **PATCH** /v1/circles/{id} | 
[**putCircleAsset**](CirclesApi.md#putcircleasset) | **PUT** /v1/circles/{id}/assets/{asset_id} | 
[**replaceCircleAssets**](CirclesApi.md#replacecircleassets) | **PUT** /v1/circles/{id}/assets | 


# **archiveCircle**
> archiveCircle(id, ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getCirclesApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = "v3"; // String | 

try {
    api.archiveCircle(id, ifMatch);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->archiveCircle: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 
 **ifMatch** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **copyCircleTemplate**
> CopyCircleTemplate201Response copyCircleTemplate(id, idempotencyKey, copyCircleTemplateRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getCirclesApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CopyCircleTemplateRequest copyCircleTemplateRequest = ; // CopyCircleTemplateRequest | 

try {
    final response = api.copyCircleTemplate(id, idempotencyKey, copyCircleTemplateRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->copyCircleTemplate: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **copyCircleTemplateRequest** | [**CopyCircleTemplateRequest**](CopyCircleTemplateRequest.md)|  | [optional] 

### Return type

[**CopyCircleTemplate201Response**](CopyCircleTemplate201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createCircle**
> CopyCircleTemplate201Response createCircle(idempotencyKey, createCircleRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getCirclesApi();
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
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
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createCircleRequest** | [**CreateCircleRequest**](CreateCircleRequest.md)|  | 

### Return type

[**CopyCircleTemplate201Response**](CopyCircleTemplate201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteCircleAsset**
> CopyCircleTemplate201Response deleteCircleAsset(id, assetId, ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getCirclesApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String assetId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = "v3"; // String | 

try {
    final response = api.deleteCircleAsset(id, assetId, ifMatch);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->deleteCircleAsset: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 
 **assetId** | **String**|  | 
 **ifMatch** | **String**|  | 

### Return type

[**CopyCircleTemplate201Response**](CopyCircleTemplate201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getCircle**
> CircleResponse getCircle(id)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getCirclesApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getCircle(id);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->getCircle: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 

### Return type

[**CircleResponse**](CircleResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listCircles**
> CircleCollectionResponse listCircles(archived, limit, cursor)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getCirclesApi();
final String archived = archived_example; // String | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 

try {
    final response = api.listCircles(archived, limit, cursor);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->listCircles: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **archived** | **String**|  | [optional] [default to 'exclude']
 **limit** | **int**|  | [optional] [default to 20]
 **cursor** | **String**|  | [optional] 

### Return type

[**CircleCollectionResponse**](CircleCollectionResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **patchCircle**
> CopyCircleTemplate201Response patchCircle(id, ifMatch, patchCircleRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getCirclesApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = "v3"; // String | 
final PatchCircleRequest patchCircleRequest = ; // PatchCircleRequest | 

try {
    final response = api.patchCircle(id, ifMatch, patchCircleRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->patchCircle: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 
 **ifMatch** | **String**|  | 
 **patchCircleRequest** | [**PatchCircleRequest**](PatchCircleRequest.md)|  | 

### Return type

[**CopyCircleTemplate201Response**](CopyCircleTemplate201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **putCircleAsset**
> CopyCircleTemplate201Response putCircleAsset(id, assetId, ifMatch, putCircleAssetRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getCirclesApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String assetId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = "v3"; // String | 
final PutCircleAssetRequest putCircleAssetRequest = ; // PutCircleAssetRequest | 

try {
    final response = api.putCircleAsset(id, assetId, ifMatch, putCircleAssetRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->putCircleAsset: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 
 **assetId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **putCircleAssetRequest** | [**PutCircleAssetRequest**](PutCircleAssetRequest.md)|  | 

### Return type

[**CopyCircleTemplate201Response**](CopyCircleTemplate201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **replaceCircleAssets**
> CopyCircleTemplate201Response replaceCircleAssets(id, ifMatch, replaceCircleAssetsRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getCirclesApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = "v3"; // String | 
final ReplaceCircleAssetsRequest replaceCircleAssetsRequest = ; // ReplaceCircleAssetsRequest | 

try {
    final response = api.replaceCircleAssets(id, ifMatch, replaceCircleAssetsRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CirclesApi->replaceCircleAssets: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 
 **ifMatch** | **String**|  | 
 **replaceCircleAssetsRequest** | [**ReplaceCircleAssetsRequest**](ReplaceCircleAssetsRequest.md)|  | 

### Return type

[**CopyCircleTemplate201Response**](CopyCircleTemplate201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

