# ritual_investing_api_client.api.NotificationsApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getNotificationPreferences**](NotificationsApi.md#getnotificationpreferences) | **GET** /v1/notification-preferences | 
[**listNotifications**](NotificationsApi.md#listnotifications) | **GET** /v1/notifications | 
[**markNotificationRead**](NotificationsApi.md#marknotificationread) | **PATCH** /v1/notifications/{notification_id}/read | 
[**updateNotificationPreferences**](NotificationsApi.md#updatenotificationpreferences) | **PATCH** /v1/notification-preferences | 


# **getNotificationPreferences**
> GetAccount200Response getNotificationPreferences()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getNotificationsApi();

try {
    final response = api.getNotificationPreferences();
    print(response);
} on DioException catch (e) {
    print('Exception when calling NotificationsApi->getNotificationPreferences: $e\n');
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

# **listNotifications**
> GetAccount200Response listNotifications(limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getNotificationsApi();
final int limit = 56; // int | 

try {
    final response = api.listNotifications(limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling NotificationsApi->listNotifications: $e\n');
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

# **markNotificationRead**
> GetAccount200Response markNotificationRead(notificationId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getNotificationsApi();
final String notificationId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.markNotificationRead(notificationId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling NotificationsApi->markNotificationRead: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **notificationId** | **String**|  | 

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateNotificationPreferences**
> GetAccount200Response updateNotificationPreferences(ifMatch, requestBody)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getNotificationsApi();
final String ifMatch = ifMatch_example; // String | 
final Map<String, Object?> requestBody = Object; // Map<String, Object?> | 

try {
    final response = api.updateNotificationPreferences(ifMatch, requestBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling NotificationsApi->updateNotificationPreferences: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **ifMatch** | **String**|  | 
 **requestBody** | [**Map&lt;String, Object?&gt;**](Object.md)|  | 

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

