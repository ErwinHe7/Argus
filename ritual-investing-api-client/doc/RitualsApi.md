# ritual_investing_api_client.api.RitualsApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getRitual**](RitualsApi.md#getritual) | **GET** /v1/rituals/{assignment_id} | 
[**transitionRitual**](RitualsApi.md#transitionritual) | **POST** /v1/rituals/{assignment_id}/transition | 


# **getRitual**
> GetAccount200Response getRitual(assignmentId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getRitualsApi();
final String assignmentId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getRitual(assignmentId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RitualsApi->getRitual: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **assignmentId** | **String**|  | 

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **transitionRitual**
> GetAccount200Response transitionRitual(assignmentId, ifMatch, transitionRitualRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getRitualsApi();
final String assignmentId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 
final TransitionRitualRequest transitionRitualRequest = ; // TransitionRitualRequest | 

try {
    final response = api.transitionRitual(assignmentId, ifMatch, transitionRitualRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RitualsApi->transitionRitual: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **assignmentId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **transitionRitualRequest** | [**TransitionRitualRequest**](TransitionRitualRequest.md)|  | 

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

