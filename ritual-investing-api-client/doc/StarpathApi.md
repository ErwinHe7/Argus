# ritual_investing_api_client.api.StarpathApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**answerStarpathQuestion**](StarpathApi.md#answerstarpathquestion) | **POST** /v1/starpath/answers | 
[**getStarpath**](StarpathApi.md#getstarpath) | **GET** /v1/starpath | 
[**skipStarpathRecall**](StarpathApi.md#skipstarpathrecall) | **POST** /v1/starpath/recall/skip | 
[**startOrResumeStarpath**](StarpathApi.md#startorresumestarpath) | **POST** /v1/starpath/sessions | 


# **answerStarpathQuestion**
> StarpathSnapshotResponse answerStarpathQuestion(idempotencyKey, ifMatch, answerStarpathQuestion)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getStarpathApi();
final String idempotencyKey = idempotencyKey_example; // String | 
final String ifMatch = ifMatch_example; // String | 
final AnswerStarpathQuestion answerStarpathQuestion = ; // AnswerStarpathQuestion | 

try {
    final response = api.answerStarpathQuestion(idempotencyKey, ifMatch, answerStarpathQuestion);
    print(response);
} on DioException catch (e) {
    print('Exception when calling StarpathApi->answerStarpathQuestion: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**|  | 
 **ifMatch** | **String**|  | 
 **answerStarpathQuestion** | [**AnswerStarpathQuestion**](AnswerStarpathQuestion.md)|  | 

### Return type

[**StarpathSnapshotResponse**](StarpathSnapshotResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getStarpath**
> StarpathSnapshotResponse getStarpath()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getStarpathApi();

try {
    final response = api.getStarpath();
    print(response);
} on DioException catch (e) {
    print('Exception when calling StarpathApi->getStarpath: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**StarpathSnapshotResponse**](StarpathSnapshotResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **skipStarpathRecall**
> StarpathSnapshotResponse skipStarpathRecall(idempotencyKey, ifMatch, skipStarpathRecall)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getStarpathApi();
final String idempotencyKey = idempotencyKey_example; // String | 
final String ifMatch = ifMatch_example; // String | 
final SkipStarpathRecall skipStarpathRecall = ; // SkipStarpathRecall | 

try {
    final response = api.skipStarpathRecall(idempotencyKey, ifMatch, skipStarpathRecall);
    print(response);
} on DioException catch (e) {
    print('Exception when calling StarpathApi->skipStarpathRecall: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**|  | 
 **ifMatch** | **String**|  | 
 **skipStarpathRecall** | [**SkipStarpathRecall**](SkipStarpathRecall.md)|  | 

### Return type

[**StarpathSnapshotResponse**](StarpathSnapshotResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **startOrResumeStarpath**
> StarpathSnapshotResponse startOrResumeStarpath(idempotencyKey)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getStarpathApi();
final String idempotencyKey = idempotencyKey_example; // String | 

try {
    final response = api.startOrResumeStarpath(idempotencyKey);
    print(response);
} on DioException catch (e) {
    print('Exception when calling StarpathApi->startOrResumeStarpath: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**|  | 

### Return type

[**StarpathSnapshotResponse**](StarpathSnapshotResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

