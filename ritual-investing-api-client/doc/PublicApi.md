# ritual_investing_api_client.api.PublicApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getPublicEditorial**](PublicApi.md#getpubliceditorial) | **GET** /v1/public/editorial/items/{slug} | 
[**listPublicEditorial**](PublicApi.md#listpubliceditorial) | **GET** /v1/public/editorial/{kind} | 


# **getPublicEditorial**
> ListAdminAudit200Response getPublicEditorial(slug)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getPublicApi();
final String slug = slug_example; // String | 

try {
    final response = api.getPublicEditorial(slug);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PublicApi->getPublicEditorial: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listPublicEditorial**
> ListAdminAudit200Response listPublicEditorial(kind, limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getPublicApi();
final String kind = kind_example; // String | 
final int limit = 56; // int | 

try {
    final response = api.listPublicEditorial(kind, limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PublicApi->listPublicEditorial: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **kind** | **String**|  | 
 **limit** | **int**|  | [optional] [default to 25]

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

