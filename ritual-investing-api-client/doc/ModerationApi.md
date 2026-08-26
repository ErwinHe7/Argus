# ritual_investing_api_client.api.ModerationApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createContentReport**](ModerationApi.md#createcontentreport) | **POST** /v1/content-reports | 


# **createContentReport**
> CreateContentReport201Response createContentReport(idempotencyKey, createContentReportRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getModerationApi();
final String idempotencyKey = order-01JY7W4M5GYJ2E47KCEPD88N2K; // String | A retry-stable, tenant-and-operation-scoped command key.
final CreateContentReportRequest createContentReportRequest = ; // CreateContentReportRequest | 

try {
    final response = api.createContentReport(idempotencyKey, createContentReportRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling ModerationApi->createContentReport: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| A retry-stable, tenant-and-operation-scoped command key. | 
 **createContentReportRequest** | [**CreateContentReportRequest**](CreateContentReportRequest.md)|  | 

### Return type

[**CreateContentReport201Response**](CreateContentReport201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

