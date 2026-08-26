# ritual_investing_api_client.api.PublicPreviewApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getPublicCoven**](PublicPreviewApi.md#getpubliccoven) | **GET** /v1/public/coven/{slug} | 
[**getPublicDailyRitual**](PublicPreviewApi.md#getpublicdailyritual) | **GET** /v1/public/rituals/daily | 
[**listPublicCoven**](PublicPreviewApi.md#listpubliccoven) | **GET** /v1/public/coven | 
[**listPublicDiscover**](PublicPreviewApi.md#listpublicdiscover) | **GET** /v1/public/discover | 


# **getPublicCoven**
> PublicCovenDetailResponse getPublicCoven(slug)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getPublicPreviewApi();
final String slug = slug_example; // String | 

try {
    final response = api.getPublicCoven(slug);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PublicPreviewApi->getPublicCoven: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 

### Return type

[**PublicCovenDetailResponse**](PublicCovenDetailResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getPublicDailyRitual**
> PublicDailyRitualResponse getPublicDailyRitual(date, mode)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getPublicPreviewApi();
final DateTime date = 2013-10-20; // DateTime | 
final String mode = mode_example; // String | 

try {
    final response = api.getPublicDailyRitual(date, mode);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PublicPreviewApi->getPublicDailyRitual: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **date** | **DateTime**|  | [optional] 
 **mode** | **String**|  | [optional] [default to 'tarot']

### Return type

[**PublicDailyRitualResponse**](PublicDailyRitualResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listPublicCoven**
> PublicCovenResponse listPublicCoven(cursor, limit, category)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getPublicPreviewApi();
final String cursor = cursor_example; // String | 
final int limit = 56; // int | 
final String category = category_example; // String | 

try {
    final response = api.listPublicCoven(cursor, limit, category);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PublicPreviewApi->listPublicCoven: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **cursor** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 20]
 **category** | **String**|  | [optional] 

### Return type

[**PublicCovenResponse**](PublicCovenResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listPublicDiscover**
> PublicDiscoverResponse listPublicDiscover(cursor, limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getPublicPreviewApi();
final String cursor = cursor_example; // String | 
final int limit = 56; // int | 

try {
    final response = api.listPublicDiscover(cursor, limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PublicPreviewApi->listPublicDiscover: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **cursor** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 20]

### Return type

[**PublicDiscoverResponse**](PublicDiscoverResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

