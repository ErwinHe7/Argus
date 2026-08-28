# ritual_investing_api_client.api.BrokerageConnectionsApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**disconnectWebullConnection**](BrokerageConnectionsApi.md#disconnectwebullconnection) | **POST** /v1/brokerage/connections/disconnect | 
[**getWebullConnection**](BrokerageConnectionsApi.md#getwebullconnection) | **GET** /v1/brokerage/connection | 
[**reconnectWebullConnection**](BrokerageConnectionsApi.md#reconnectwebullconnection) | **POST** /v1/brokerage/connections/reconnect | 
[**redeemWebullCompletion**](BrokerageConnectionsApi.md#redeemwebullcompletion) | **POST** /v1/brokerage/connections/completions/redeem | 
[**selectWebullAccount**](BrokerageConnectionsApi.md#selectwebullaccount) | **PATCH** /v1/brokerage/accounts/selection | 
[**startWebullConnection**](BrokerageConnectionsApi.md#startwebullconnection) | **POST** /v1/brokerage/connections/start | 


# **disconnectWebullConnection**
> WebullDisconnectResponse disconnectWebullConnection(disconnectWebullConnectionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageConnectionsApi();
final DisconnectWebullConnectionRequest disconnectWebullConnectionRequest = ; // DisconnectWebullConnectionRequest | 

try {
    final response = api.disconnectWebullConnection(disconnectWebullConnectionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageConnectionsApi->disconnectWebullConnection: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **disconnectWebullConnectionRequest** | [**DisconnectWebullConnectionRequest**](DisconnectWebullConnectionRequest.md)|  | 

### Return type

[**WebullDisconnectResponse**](WebullDisconnectResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getWebullConnection**
> WebullConnectionResponse getWebullConnection()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageConnectionsApi();

try {
    final response = api.getWebullConnection();
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageConnectionsApi->getWebullConnection: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**WebullConnectionResponse**](WebullConnectionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **reconnectWebullConnection**
> WebullAuthorizationSessionResponse reconnectWebullConnection(reconnectWebullConnectionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageConnectionsApi();
final ReconnectWebullConnectionRequest reconnectWebullConnectionRequest = ; // ReconnectWebullConnectionRequest | 

try {
    final response = api.reconnectWebullConnection(reconnectWebullConnectionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageConnectionsApi->reconnectWebullConnection: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **reconnectWebullConnectionRequest** | [**ReconnectWebullConnectionRequest**](ReconnectWebullConnectionRequest.md)|  | 

### Return type

[**WebullAuthorizationSessionResponse**](WebullAuthorizationSessionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **redeemWebullCompletion**
> WebullCompletionResponse redeemWebullCompletion(redeemWebullCompletionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageConnectionsApi();
final RedeemWebullCompletionRequest redeemWebullCompletionRequest = ; // RedeemWebullCompletionRequest | 

try {
    final response = api.redeemWebullCompletion(redeemWebullCompletionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageConnectionsApi->redeemWebullCompletion: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **redeemWebullCompletionRequest** | [**RedeemWebullCompletionRequest**](RedeemWebullCompletionRequest.md)|  | 

### Return type

[**WebullCompletionResponse**](WebullCompletionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **selectWebullAccount**
> WebullAccountSelectionResponse selectWebullAccount(selectWebullAccountRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageConnectionsApi();
final SelectWebullAccountRequest selectWebullAccountRequest = ; // SelectWebullAccountRequest | 

try {
    final response = api.selectWebullAccount(selectWebullAccountRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageConnectionsApi->selectWebullAccount: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **selectWebullAccountRequest** | [**SelectWebullAccountRequest**](SelectWebullAccountRequest.md)|  | 

### Return type

[**WebullAccountSelectionResponse**](WebullAccountSelectionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **startWebullConnection**
> WebullAuthorizationSessionResponse startWebullConnection(reconnectWebullConnectionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageConnectionsApi();
final ReconnectWebullConnectionRequest reconnectWebullConnectionRequest = ; // ReconnectWebullConnectionRequest | 

try {
    final response = api.startWebullConnection(reconnectWebullConnectionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageConnectionsApi->startWebullConnection: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **reconnectWebullConnectionRequest** | [**ReconnectWebullConnectionRequest**](ReconnectWebullConnectionRequest.md)|  | 

### Return type

[**WebullAuthorizationSessionResponse**](WebullAuthorizationSessionResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

