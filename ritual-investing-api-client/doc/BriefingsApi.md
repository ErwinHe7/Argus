# ritual_investing_api_client.api.BriefingsApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getBriefing**](BriefingsApi.md#getbriefing) | **GET** /v1/briefings/{briefing_id} | 
[**getDailyBriefing**](BriefingsApi.md#getdailybriefing) | **GET** /v1/briefings/daily | 
[**listBriefings**](BriefingsApi.md#listbriefings) | **GET** /v1/briefings | 
[**setBriefingReadState**](BriefingsApi.md#setbriefingreadstate) | **PUT** /v1/briefings/{briefing_id}/read-state | 


# **getBriefing**
> BriefingDetailResponse getBriefing(briefingId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBriefingsApi();
final String briefingId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getBriefing(briefingId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BriefingsApi->getBriefing: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **briefingId** | **String**|  | 

### Return type

[**BriefingDetailResponse**](BriefingDetailResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getDailyBriefing**
> BriefingDetailResponse getDailyBriefing(localDate)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBriefingsApi();
final DateTime localDate = 2013-10-20; // DateTime | 

try {
    final response = api.getDailyBriefing(localDate);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BriefingsApi->getDailyBriefing: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **localDate** | **DateTime**|  | [optional] 

### Return type

[**BriefingDetailResponse**](BriefingDetailResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listBriefings**
> BriefingCollectionResponse listBriefings(type, periodStart, periodEnd, cursor, limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBriefingsApi();
final String type = type_example; // String | 
final DateTime periodStart = 2013-10-20; // DateTime | 
final DateTime periodEnd = 2013-10-20; // DateTime | 
final String cursor = cursor_example; // String | 
final int limit = 56; // int | 

try {
    final response = api.listBriefings(type, periodStart, periodEnd, cursor, limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BriefingsApi->listBriefings: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **type** | **String**|  | [optional] 
 **periodStart** | **DateTime**|  | [optional] 
 **periodEnd** | **DateTime**|  | [optional] 
 **cursor** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 25]

### Return type

[**BriefingCollectionResponse**](BriefingCollectionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setBriefingReadState**
> BriefingSummaryResponse setBriefingReadState(briefingId, setBriefingReadStateRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBriefingsApi();
final String briefingId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final SetBriefingReadStateRequest setBriefingReadStateRequest = ; // SetBriefingReadStateRequest | 

try {
    final response = api.setBriefingReadState(briefingId, setBriefingReadStateRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BriefingsApi->setBriefingReadState: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **briefingId** | **String**|  | 
 **setBriefingReadStateRequest** | [**SetBriefingReadStateRequest**](SetBriefingReadStateRequest.md)|  | 

### Return type

[**BriefingSummaryResponse**](BriefingSummaryResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

