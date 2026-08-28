# ritual_investing_api_client.api.AdminBrokerageApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getStaffWebullOrderReconciliation**](AdminBrokerageApi.md#getstaffwebullorderreconciliation) | **GET** /v1/admin/brokerage/order-commands/{command_id} | 


# **getStaffWebullOrderReconciliation**
> BrokerageOrderReconciliationResponse getStaffWebullOrderReconciliation(commandId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminBrokerageApi();
final String commandId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getStaffWebullOrderReconciliation(commandId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminBrokerageApi->getStaffWebullOrderReconciliation: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **commandId** | **String**|  | 

### Return type

[**BrokerageOrderReconciliationResponse**](BrokerageOrderReconciliationResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

