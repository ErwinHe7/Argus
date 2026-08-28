# ritual_investing_api_client.api.CovenApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getCoven**](CovenApi.md#getcoven) | **GET** /v1/coven/{entry_id} | 
[**getCovenEvidence**](CovenApi.md#getcovenevidence) | **GET** /v1/coven/{entry_id}/evidence | 
[**listCoven**](CovenApi.md#listcoven) | **GET** /v1/coven | 


# **getCoven**
> CovenDetailResponse getCoven(entryId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getCovenApi();
final String entryId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getCoven(entryId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CovenApi->getCoven: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **entryId** | **String**|  | 

### Return type

[**CovenDetailResponse**](CovenDetailResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getCovenEvidence**
> CovenEvidenceResponse getCovenEvidence(entryId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getCovenApi();
final String entryId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getCovenEvidence(entryId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CovenApi->getCovenEvidence: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **entryId** | **String**|  | 

### Return type

[**CovenEvidenceResponse**](CovenEvidenceResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listCoven**
> CovenCollectionResponse listCoven(cursor, limit, category, verifiedAsOf)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getCovenApi();
final String cursor = cursor_example; // String | 
final int limit = 56; // int | 
final String category = category_example; // String | 
final DateTime verifiedAsOf = 2013-10-20; // DateTime | 

try {
    final response = api.listCoven(cursor, limit, category, verifiedAsOf);
    print(response);
} on DioException catch (e) {
    print('Exception when calling CovenApi->listCoven: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **cursor** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 25]
 **category** | **String**|  | [optional] 
 **verifiedAsOf** | **DateTime**|  | [optional] 

### Return type

[**CovenCollectionResponse**](CovenCollectionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

