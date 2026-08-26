# ritual_investing_api_client.api.NotificationsApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getNotificationPreferences**](NotificationsApi.md#getnotificationpreferences) | **GET** /v1/me/notification-preferences | 
[**listNotifications**](NotificationsApi.md#listnotifications) | **GET** /v1/notifications | 
[**patchNotificationPreferences**](NotificationsApi.md#patchnotificationpreferences) | **PATCH** /v1/me/notification-preferences | 
[**readAllNotifications**](NotificationsApi.md#readallnotifications) | **POST** /v1/notifications/read-all | 
[**registerNotificationDevice**](NotificationsApi.md#registernotificationdevice) | **POST** /v1/me/devices | 
[**revokeNotificationDevice**](NotificationsApi.md#revokenotificationdevice) | **DELETE** /v1/me/devices/{installation_id} | 
[**setNotificationReadState**](NotificationsApi.md#setnotificationreadstate) | **PUT** /v1/notifications/{notification_id}/read-state | 


# **getNotificationPreferences**
> GetNotificationPreferences200Response getNotificationPreferences()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

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

[**GetNotificationPreferences200Response**](GetNotificationPreferences200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listNotifications**
> ListNotifications200Response listNotifications(read, limit, cursor)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getNotificationsApi();
final String read = read_example; // String | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 

try {
    final response = api.listNotifications(read, limit, cursor);
    print(response);
} on DioException catch (e) {
    print('Exception when calling NotificationsApi->listNotifications: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **read** | **String**|  | [optional] [default to 'all']
 **limit** | **int**|  | [optional] [default to 20]
 **cursor** | **String**|  | [optional] 

### Return type

[**ListNotifications200Response**](ListNotifications200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **patchNotificationPreferences**
> GetNotificationPreferences200Response patchNotificationPreferences(ifMatch, patchNotificationPreferencesRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getNotificationsApi();
final String ifMatch = "v3"; // String | 
final PatchNotificationPreferencesRequest patchNotificationPreferencesRequest = ; // PatchNotificationPreferencesRequest | 

try {
    final response = api.patchNotificationPreferences(ifMatch, patchNotificationPreferencesRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling NotificationsApi->patchNotificationPreferences: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **ifMatch** | **String**|  | 
 **patchNotificationPreferencesRequest** | [**PatchNotificationPreferencesRequest**](PatchNotificationPreferencesRequest.md)|  | 

### Return type

[**GetNotificationPreferences200Response**](GetNotificationPreferences200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **readAllNotifications**
> ReadAllNotifications200Response readAllNotifications(idempotencyKey, readAllNotificationsRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getNotificationsApi();
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final ReadAllNotificationsRequest readAllNotificationsRequest = ; // ReadAllNotificationsRequest | 

try {
    final response = api.readAllNotifications(idempotencyKey, readAllNotificationsRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling NotificationsApi->readAllNotifications: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **readAllNotificationsRequest** | [**ReadAllNotificationsRequest**](ReadAllNotificationsRequest.md)|  | [optional] 

### Return type

[**ReadAllNotifications200Response**](ReadAllNotifications200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **registerNotificationDevice**
> RegisterNotificationDevice201Response registerNotificationDevice(idempotencyKey, registerNotificationDeviceRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getNotificationsApi();
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final RegisterNotificationDeviceRequest registerNotificationDeviceRequest = ; // RegisterNotificationDeviceRequest | 

try {
    final response = api.registerNotificationDevice(idempotencyKey, registerNotificationDeviceRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling NotificationsApi->registerNotificationDevice: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **registerNotificationDeviceRequest** | [**RegisterNotificationDeviceRequest**](RegisterNotificationDeviceRequest.md)|  | 

### Return type

[**RegisterNotificationDevice201Response**](RegisterNotificationDevice201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **revokeNotificationDevice**
> revokeNotificationDevice(installationId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getNotificationsApi();
final String installationId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.revokeNotificationDevice(installationId);
} on DioException catch (e) {
    print('Exception when calling NotificationsApi->revokeNotificationDevice: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **installationId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setNotificationReadState**
> SetNotificationReadState200Response setNotificationReadState(notificationId, setBriefingReadStateRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getNotificationsApi();
final String notificationId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final SetBriefingReadStateRequest setBriefingReadStateRequest = ; // SetBriefingReadStateRequest | 

try {
    final response = api.setNotificationReadState(notificationId, setBriefingReadStateRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling NotificationsApi->setNotificationReadState: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **notificationId** | **String**|  | 
 **setBriefingReadStateRequest** | [**SetBriefingReadStateRequest**](SetBriefingReadStateRequest.md)|  | 

### Return type

[**SetNotificationReadState200Response**](SetNotificationReadState200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

