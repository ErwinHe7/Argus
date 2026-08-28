# ritual_investing_api_client.api.AdminModerationApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**decideModeration**](AdminModerationApi.md#decidemoderation) | **POST** /v1/admin/moderation/{case_id}/decision | 


# **decideModeration**
> ListAdminAudit200Response decideModeration(caseId, ifMatch, idempotencyKey, decideModerationRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminModerationApi();
final String caseId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 
final String idempotencyKey = idempotencyKey_example; // String | 
final DecideModerationRequest decideModerationRequest = ; // DecideModerationRequest | 

try {
    final response = api.decideModeration(caseId, ifMatch, idempotencyKey, decideModerationRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminModerationApi->decideModeration: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **caseId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **idempotencyKey** | **String**|  | 
 **decideModerationRequest** | [**DecideModerationRequest**](DecideModerationRequest.md)|  | 

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

