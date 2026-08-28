# ritual_investing_api_client.api.ModerationApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**reportContent**](ModerationApi.md#reportcontent) | **POST** /v1/moderation/reports | 


# **reportContent**
> GetAccount200Response reportContent(reportContentRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getModerationApi();
final ReportContentRequest reportContentRequest = ; // ReportContentRequest | 

try {
    final response = api.reportContent(reportContentRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling ModerationApi->reportContent: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **reportContentRequest** | [**ReportContentRequest**](ReportContentRequest.md)|  | 

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

