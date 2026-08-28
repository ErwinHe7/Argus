# ritual_investing_api_client.api.SessionApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**bootstrapSession**](SessionApi.md#bootstrapsession) | **POST** /v1/session/bootstrap | 


# **bootstrapSession**
> GetAccount200Response bootstrapSession()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getSessionApi();

try {
    final response = api.bootstrapSession();
    print(response);
} on DioException catch (e) {
    print('Exception when calling SessionApi->bootstrapSession: $e\n');
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

