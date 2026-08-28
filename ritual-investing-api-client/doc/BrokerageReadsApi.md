# ritual_investing_api_client.api.BrokerageReadsApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getWebullAccountCapabilities**](BrokerageReadsApi.md#getwebullaccountcapabilities) | **GET** /v1/brokerage/accounts/{account_id}/capabilities | 
[**getWebullBalances**](BrokerageReadsApi.md#getwebullbalances) | **GET** /v1/brokerage/accounts/{account_id}/balances | 
[**getWebullPositions**](BrokerageReadsApi.md#getwebullpositions) | **GET** /v1/brokerage/accounts/{account_id}/positions | 
[**getWebullRestrictions**](BrokerageReadsApi.md#getwebullrestrictions) | **GET** /v1/brokerage/accounts/{account_id}/restrictions | 
[**listWebullAccounts**](BrokerageReadsApi.md#listwebullaccounts) | **GET** /v1/brokerage/accounts | 


# **getWebullAccountCapabilities**
> BrokerageCapabilitiesResponse getWebullAccountCapabilities(accountId, refresh)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageReadsApi();
final String accountId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String refresh = refresh_example; // String | 

try {
    final response = api.getWebullAccountCapabilities(accountId, refresh);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageReadsApi->getWebullAccountCapabilities: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accountId** | **String**|  | 
 **refresh** | **String**|  | [optional] 

### Return type

[**BrokerageCapabilitiesResponse**](BrokerageCapabilitiesResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getWebullBalances**
> BrokerageBalancesResponse getWebullBalances(accountId, refresh)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageReadsApi();
final String accountId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String refresh = refresh_example; // String | 

try {
    final response = api.getWebullBalances(accountId, refresh);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageReadsApi->getWebullBalances: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accountId** | **String**|  | 
 **refresh** | **String**|  | [optional] 

### Return type

[**BrokerageBalancesResponse**](BrokerageBalancesResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getWebullPositions**
> BrokeragePositionsResponse getWebullPositions(accountId, refresh)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageReadsApi();
final String accountId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String refresh = refresh_example; // String | 

try {
    final response = api.getWebullPositions(accountId, refresh);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageReadsApi->getWebullPositions: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accountId** | **String**|  | 
 **refresh** | **String**|  | [optional] 

### Return type

[**BrokeragePositionsResponse**](BrokeragePositionsResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getWebullRestrictions**
> BrokerageRestrictionsResponse getWebullRestrictions(accountId, refresh)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageReadsApi();
final String accountId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String refresh = refresh_example; // String | 

try {
    final response = api.getWebullRestrictions(accountId, refresh);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageReadsApi->getWebullRestrictions: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accountId** | **String**|  | 
 **refresh** | **String**|  | [optional] 

### Return type

[**BrokerageRestrictionsResponse**](BrokerageRestrictionsResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listWebullAccounts**
> BrokerageAccountsResponse listWebullAccounts()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageReadsApi();

try {
    final response = api.listWebullAccounts();
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageReadsApi->listWebullAccounts: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**BrokerageAccountsResponse**](BrokerageAccountsResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

