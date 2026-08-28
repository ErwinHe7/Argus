# ritual_investing_api_client.api.EditorialApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getEditorial**](EditorialApi.md#geteditorial) | **GET** /v1/editorial/items/{slug} | 
[**listEditorial**](EditorialApi.md#listeditorial) | **GET** /v1/editorial/{kind} | 


# **getEditorial**
> ListAdminAudit200Response getEditorial(slug)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getEditorialApi();
final String slug = slug_example; // String | 

try {
    final response = api.getEditorial(slug);
    print(response);
} on DioException catch (e) {
    print('Exception when calling EditorialApi->getEditorial: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listEditorial**
> ListAdminAudit200Response listEditorial(kind, limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getEditorialApi();
final String kind = kind_example; // String | 
final int limit = 56; // int | 

try {
    final response = api.listEditorial(kind, limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling EditorialApi->listEditorial: $e\n');
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

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

