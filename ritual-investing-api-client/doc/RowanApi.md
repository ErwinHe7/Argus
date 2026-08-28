# ritual_investing_api_client.api.RowanApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**resolveRowan**](RowanApi.md#resolverowan) | **GET** /v1/rowan/{surface}/{context_key} | 


# **resolveRowan**
> RowanCounselResponse resolveRowan(surface, contextKey)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getRowanApi();
final String surface = surface_example; // String | 
final String contextKey = contextKey_example; // String | 

try {
    final response = api.resolveRowan(surface, contextKey);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RowanApi->resolveRowan: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **surface** | **String**|  | 
 **contextKey** | **String**|  | 

### Return type

[**RowanCounselResponse**](RowanCounselResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

