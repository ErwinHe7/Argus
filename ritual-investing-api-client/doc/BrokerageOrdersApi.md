# ritual_investing_api_client.api.BrokerageOrdersApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**cancelWebullOrder**](BrokerageOrdersApi.md#cancelwebullorder) | **POST** /v1/brokerage/accounts/{account_id}/orders/{order_id}/cancel | 
[**getWebullOrder**](BrokerageOrdersApi.md#getwebullorder) | **GET** /v1/brokerage/accounts/{account_id}/orders/{order_id} | 
[**getWebullOrderCommand**](BrokerageOrdersApi.md#getwebullordercommand) | **GET** /v1/brokerage/order-commands/{command_id} | 
[**listWebullOrders**](BrokerageOrdersApi.md#listwebullorders) | **GET** /v1/brokerage/accounts/{account_id}/orders | 
[**modifyWebullOrder**](BrokerageOrdersApi.md#modifywebullorder) | **PATCH** /v1/brokerage/accounts/{account_id}/orders/{order_id} | 
[**placeWebullOrder**](BrokerageOrdersApi.md#placewebullorder) | **POST** /v1/brokerage/accounts/{account_id}/orders | 
[**previewWebullOrder**](BrokerageOrdersApi.md#previewwebullorder) | **POST** /v1/brokerage/accounts/{account_id}/orders/previews | 
[**previewWebullOrderCancellation**](BrokerageOrdersApi.md#previewwebullordercancellation) | **POST** /v1/brokerage/accounts/{account_id}/orders/{order_id}/cancel-preview | 
[**previewWebullOrderModification**](BrokerageOrdersApi.md#previewwebullordermodification) | **POST** /v1/brokerage/accounts/{account_id}/orders/{order_id}/modify-preview | 


# **cancelWebullOrder**
> BrokerageOrderCommandResponse cancelWebullOrder(accountId, orderId, idempotencyKey, confirmCancelBrokerageOrder)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageOrdersApi();
final String accountId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String orderId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = idempotencyKey_example; // String | 
final ConfirmCancelBrokerageOrder confirmCancelBrokerageOrder = ; // ConfirmCancelBrokerageOrder | 

try {
    final response = api.cancelWebullOrder(accountId, orderId, idempotencyKey, confirmCancelBrokerageOrder);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageOrdersApi->cancelWebullOrder: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accountId** | **String**|  | 
 **orderId** | **String**|  | 
 **idempotencyKey** | **String**|  | 
 **confirmCancelBrokerageOrder** | [**ConfirmCancelBrokerageOrder**](ConfirmCancelBrokerageOrder.md)|  | 

### Return type

[**BrokerageOrderCommandResponse**](BrokerageOrderCommandResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getWebullOrder**
> BrokerageOrderDetailResponse getWebullOrder(accountId, orderId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageOrdersApi();
final String accountId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String orderId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getWebullOrder(accountId, orderId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageOrdersApi->getWebullOrder: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accountId** | **String**|  | 
 **orderId** | **String**|  | 

### Return type

[**BrokerageOrderDetailResponse**](BrokerageOrderDetailResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getWebullOrderCommand**
> BrokerageOrderCommandResponse getWebullOrderCommand(commandId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageOrdersApi();
final String commandId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getWebullOrderCommand(commandId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageOrdersApi->getWebullOrderCommand: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **commandId** | **String**|  | 

### Return type

[**BrokerageOrderCommandResponse**](BrokerageOrderCommandResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listWebullOrders**
> BrokerageOrdersResponse listWebullOrders(accountId, refresh)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageOrdersApi();
final String accountId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String refresh = refresh_example; // String | 

try {
    final response = api.listWebullOrders(accountId, refresh);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageOrdersApi->listWebullOrders: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accountId** | **String**|  | 
 **refresh** | **String**|  | [optional] 

### Return type

[**BrokerageOrdersResponse**](BrokerageOrdersResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **modifyWebullOrder**
> BrokerageOrderCommandResponse modifyWebullOrder(accountId, orderId, idempotencyKey, confirmModifyBrokerageOrder)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageOrdersApi();
final String accountId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String orderId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = idempotencyKey_example; // String | 
final ConfirmModifyBrokerageOrder confirmModifyBrokerageOrder = ; // ConfirmModifyBrokerageOrder | 

try {
    final response = api.modifyWebullOrder(accountId, orderId, idempotencyKey, confirmModifyBrokerageOrder);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageOrdersApi->modifyWebullOrder: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accountId** | **String**|  | 
 **orderId** | **String**|  | 
 **idempotencyKey** | **String**|  | 
 **confirmModifyBrokerageOrder** | [**ConfirmModifyBrokerageOrder**](ConfirmModifyBrokerageOrder.md)|  | 

### Return type

[**BrokerageOrderCommandResponse**](BrokerageOrderCommandResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **placeWebullOrder**
> BrokerageOrderCommandResponse placeWebullOrder(accountId, idempotencyKey, confirmPlaceBrokerageOrder)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageOrdersApi();
final String accountId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String idempotencyKey = idempotencyKey_example; // String | 
final ConfirmPlaceBrokerageOrder confirmPlaceBrokerageOrder = ; // ConfirmPlaceBrokerageOrder | 

try {
    final response = api.placeWebullOrder(accountId, idempotencyKey, confirmPlaceBrokerageOrder);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageOrdersApi->placeWebullOrder: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accountId** | **String**|  | 
 **idempotencyKey** | **String**|  | 
 **confirmPlaceBrokerageOrder** | [**ConfirmPlaceBrokerageOrder**](ConfirmPlaceBrokerageOrder.md)|  | 

### Return type

[**BrokerageOrderCommandResponse**](BrokerageOrderCommandResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **previewWebullOrder**
> BrokerageOrderPreviewResponse previewWebullOrder(accountId, placeBrokerageOrderIntent)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageOrdersApi();
final String accountId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final PlaceBrokerageOrderIntent placeBrokerageOrderIntent = ; // PlaceBrokerageOrderIntent | 

try {
    final response = api.previewWebullOrder(accountId, placeBrokerageOrderIntent);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageOrdersApi->previewWebullOrder: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accountId** | **String**|  | 
 **placeBrokerageOrderIntent** | [**PlaceBrokerageOrderIntent**](PlaceBrokerageOrderIntent.md)|  | 

### Return type

[**BrokerageOrderPreviewResponse**](BrokerageOrderPreviewResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **previewWebullOrderCancellation**
> BrokerageOrderPreviewResponse previewWebullOrderCancellation(accountId, orderId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageOrdersApi();
final String accountId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String orderId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.previewWebullOrderCancellation(accountId, orderId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageOrdersApi->previewWebullOrderCancellation: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accountId** | **String**|  | 
 **orderId** | **String**|  | 

### Return type

[**BrokerageOrderPreviewResponse**](BrokerageOrderPreviewResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **previewWebullOrderModification**
> BrokerageOrderPreviewResponse previewWebullOrderModification(accountId, orderId, modifyBrokerageOrderIntent)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getBrokerageOrdersApi();
final String accountId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String orderId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final ModifyBrokerageOrderIntent modifyBrokerageOrderIntent = ; // ModifyBrokerageOrderIntent | 

try {
    final response = api.previewWebullOrderModification(accountId, orderId, modifyBrokerageOrderIntent);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BrokerageOrdersApi->previewWebullOrderModification: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accountId** | **String**|  | 
 **orderId** | **String**|  | 
 **modifyBrokerageOrderIntent** | [**ModifyBrokerageOrderIntent**](ModifyBrokerageOrderIntent.md)|  | 

### Return type

[**BrokerageOrderPreviewResponse**](BrokerageOrderPreviewResponse.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

