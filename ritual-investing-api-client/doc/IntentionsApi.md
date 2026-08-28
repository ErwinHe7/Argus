# ritual_investing_api_client.api.IntentionsApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**archiveIntention**](IntentionsApi.md#archiveintention) | **DELETE** /v1/intentions/{intention_id} | 
[**createIntention**](IntentionsApi.md#createintention) | **POST** /v1/intentions | 
[**getIntention**](IntentionsApi.md#getintention) | **GET** /v1/intentions/{intention_id} | 
[**listIntentions**](IntentionsApi.md#listintentions) | **GET** /v1/intentions | 
[**patchIntention**](IntentionsApi.md#patchintention) | **PATCH** /v1/intentions/{intention_id} | 


# **archiveIntention**
> MemberIntentionResponse archiveIntention(intentionId, ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getIntentionsApi();
final String intentionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 

try {
    final response = api.archiveIntention(intentionId, ifMatch);
    print(response);
} on DioException catch (e) {
    print('Exception when calling IntentionsApi->archiveIntention: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **intentionId** | **String**|  | 
 **ifMatch** | **String**|  | 

### Return type

[**MemberIntentionResponse**](MemberIntentionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createIntention**
> MemberIntentionResponse createIntention(idempotencyKey, createMemberIntention)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getIntentionsApi();
final String idempotencyKey = idempotencyKey_example; // String | 
final CreateMemberIntention createMemberIntention = ; // CreateMemberIntention | 

try {
    final response = api.createIntention(idempotencyKey, createMemberIntention);
    print(response);
} on DioException catch (e) {
    print('Exception when calling IntentionsApi->createIntention: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**|  | 
 **createMemberIntention** | [**CreateMemberIntention**](CreateMemberIntention.md)|  | 

### Return type

[**MemberIntentionResponse**](MemberIntentionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getIntention**
> MemberIntentionResponse getIntention(intentionId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getIntentionsApi();
final String intentionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getIntention(intentionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling IntentionsApi->getIntention: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **intentionId** | **String**|  | 

### Return type

[**MemberIntentionResponse**](MemberIntentionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listIntentions**
> MemberIntentionPageResponse listIntentions(status, limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getIntentionsApi();
final String status = status_example; // String | 
final int limit = 56; // int | 

try {
    final response = api.listIntentions(status, limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling IntentionsApi->listIntentions: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **status** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 25]

### Return type

[**MemberIntentionPageResponse**](MemberIntentionPageResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **patchIntention**
> MemberIntentionResponse patchIntention(intentionId, ifMatch, patchMemberIntention)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getIntentionsApi();
final String intentionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 
final PatchMemberIntention patchMemberIntention = ; // PatchMemberIntention | 

try {
    final response = api.patchIntention(intentionId, ifMatch, patchMemberIntention);
    print(response);
} on DioException catch (e) {
    print('Exception when calling IntentionsApi->patchIntention: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **intentionId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **patchMemberIntention** | [**PatchMemberIntention**](PatchMemberIntention.md)|  | 

### Return type

[**MemberIntentionResponse**](MemberIntentionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

