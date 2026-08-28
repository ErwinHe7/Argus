# ritual_investing_api_client.api.AdminApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getAdminSession**](AdminApi.md#getadminsession) | **GET** /v1/admin/session | 
[**listAdminAudit**](AdminApi.md#listadminaudit) | **GET** /v1/admin/audit | 
[**listAdminEditorial**](AdminApi.md#listadmineditorial) | **GET** /v1/admin/editorial | 


# **getAdminSession**
> GetAccount200Response getAdminSession()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminApi();

try {
    final response = api.getAdminSession();
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminApi->getAdminSession: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminAudit**
> GetAccount200Response listAdminAudit(limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminApi();
final int limit = 56; // int | 

try {
    final response = api.listAdminAudit(limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminApi->listAdminAudit: $e\n');
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

# **listAdminEditorial**
> GetAccount200Response listAdminEditorial(limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminApi();
final int limit = 56; // int | 

try {
    final response = api.listAdminEditorial(limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminApi->listAdminEditorial: $e\n');
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

