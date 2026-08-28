# ritual_investing_api_client.api.MemberSecurityApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**issueMemberStepUp**](MemberSecurityApi.md#issuememberstepup) | **POST** /v1/member/step-up | 


# **issueMemberStepUp**
> GetAccount200Response issueMemberStepUp(issueMemberStepUpRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getMemberSecurityApi();
final IssueMemberStepUpRequest issueMemberStepUpRequest = ; // IssueMemberStepUpRequest | 

try {
    final response = api.issueMemberStepUp(issueMemberStepUpRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling MemberSecurityApi->issueMemberStepUp: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **issueMemberStepUpRequest** | [**IssueMemberStepUpRequest**](IssueMemberStepUpRequest.md)|  | 

### Return type

[**GetAccount200Response**](GetAccount200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

