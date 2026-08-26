# ritual_investing_api_client.api.PortfoliosApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**archivePortfolio**](PortfoliosApi.md#archiveportfolio) | **DELETE** /v1/portfolios/{portfolio_id} | 
[**createDemoFundingSource**](PortfoliosApi.md#createdemofundingsource) | **POST** /v1/demo-funding-sources | 
[**createPortfolio**](PortfoliosApi.md#createportfolio) | **POST** /v1/portfolios | 
[**deleteDemoFundingSource**](PortfoliosApi.md#deletedemofundingsource) | **DELETE** /v1/demo-funding-sources/{source_id} | 
[**getPortfolio**](PortfoliosApi.md#getportfolio) | **GET** /v1/portfolios/{portfolio_id} | 
[**listDemoFundingSources**](PortfoliosApi.md#listdemofundingsources) | **GET** /v1/demo-funding-sources | 
[**listPortfolioActivity**](PortfoliosApi.md#listportfolioactivity) | **GET** /v1/portfolios/{portfolio_id}/activity | 
[**listPortfolioHoldings**](PortfoliosApi.md#listportfolioholdings) | **GET** /v1/portfolios/{portfolio_id}/holdings | 
[**listPortfolioSnapshots**](PortfoliosApi.md#listportfoliosnapshots) | **GET** /v1/portfolios/{portfolio_id}/snapshots | 
[**listPortfolios**](PortfoliosApi.md#listportfolios) | **GET** /v1/portfolios | 
[**patchPortfolio**](PortfoliosApi.md#patchportfolio) | **PATCH** /v1/portfolios/{portfolio_id} | 


# **archivePortfolio**
> archivePortfolio(portfolioId, ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getPortfoliosApi();
final String portfolioId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 

try {
    api.archivePortfolio(portfolioId, ifMatch);
} on DioException catch (e) {
    print('Exception when calling PortfoliosApi->archivePortfolio: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **portfolioId** | **String**|  | 
 **ifMatch** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createDemoFundingSource**
> CreateDemoFundingSource201Response createDemoFundingSource(idempotencyKey, createDemoFundingSourceRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getPortfoliosApi();
final String idempotencyKey = idempotencyKey_example; // String | 
final CreateDemoFundingSourceRequest createDemoFundingSourceRequest = ; // CreateDemoFundingSourceRequest | 

try {
    final response = api.createDemoFundingSource(idempotencyKey, createDemoFundingSourceRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PortfoliosApi->createDemoFundingSource: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**|  | 
 **createDemoFundingSourceRequest** | [**CreateDemoFundingSourceRequest**](CreateDemoFundingSourceRequest.md)|  | 

### Return type

[**CreateDemoFundingSource201Response**](CreateDemoFundingSource201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createPortfolio**
> CreatePortfolio201Response createPortfolio(idempotencyKey, createPortfolioRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getPortfoliosApi();
final String idempotencyKey = idempotencyKey_example; // String | 
final CreatePortfolioRequest createPortfolioRequest = ; // CreatePortfolioRequest | 

try {
    final response = api.createPortfolio(idempotencyKey, createPortfolioRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PortfoliosApi->createPortfolio: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**|  | 
 **createPortfolioRequest** | [**CreatePortfolioRequest**](CreatePortfolioRequest.md)|  | 

### Return type

[**CreatePortfolio201Response**](CreatePortfolio201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteDemoFundingSource**
> deleteDemoFundingSource(sourceId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getPortfoliosApi();
final String sourceId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.deleteDemoFundingSource(sourceId);
} on DioException catch (e) {
    print('Exception when calling PortfoliosApi->deleteDemoFundingSource: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sourceId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getPortfolio**
> CreatePortfolio201Response getPortfolio(portfolioId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getPortfoliosApi();
final String portfolioId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getPortfolio(portfolioId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PortfoliosApi->getPortfolio: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **portfolioId** | **String**|  | 

### Return type

[**CreatePortfolio201Response**](CreatePortfolio201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listDemoFundingSources**
> ListDemoFundingSources200Response listDemoFundingSources()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getPortfoliosApi();

try {
    final response = api.listDemoFundingSources();
    print(response);
} on DioException catch (e) {
    print('Exception when calling PortfoliosApi->listDemoFundingSources: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**ListDemoFundingSources200Response**](ListDemoFundingSources200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listPortfolioActivity**
> ListPortfolioActivity200Response listPortfolioActivity(portfolioId, limit, cursor, from, to)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getPortfoliosApi();
final String portfolioId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 
final DateTime from = 2013-10-20; // DateTime | 
final DateTime to = 2013-10-20; // DateTime | 

try {
    final response = api.listPortfolioActivity(portfolioId, limit, cursor, from, to);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PortfoliosApi->listPortfolioActivity: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **portfolioId** | **String**|  | 
 **limit** | **int**|  | [optional] [default to 20]
 **cursor** | **String**|  | [optional] 
 **from** | **DateTime**|  | [optional] 
 **to** | **DateTime**|  | [optional] 

### Return type

[**ListPortfolioActivity200Response**](ListPortfolioActivity200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listPortfolioHoldings**
> ListPortfolioHoldings200Response listPortfolioHoldings(portfolioId, limit, cursor)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getPortfoliosApi();
final String portfolioId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 

try {
    final response = api.listPortfolioHoldings(portfolioId, limit, cursor);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PortfoliosApi->listPortfolioHoldings: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **portfolioId** | **String**|  | 
 **limit** | **int**|  | [optional] [default to 20]
 **cursor** | **String**|  | [optional] 

### Return type

[**ListPortfolioHoldings200Response**](ListPortfolioHoldings200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listPortfolioSnapshots**
> ListPortfolioSnapshots200Response listPortfolioSnapshots(portfolioId, limit, cursor, from, to)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getPortfoliosApi();
final String portfolioId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 
final DateTime from = 2013-10-20; // DateTime | 
final DateTime to = 2013-10-20; // DateTime | 

try {
    final response = api.listPortfolioSnapshots(portfolioId, limit, cursor, from, to);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PortfoliosApi->listPortfolioSnapshots: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **portfolioId** | **String**|  | 
 **limit** | **int**|  | [optional] [default to 20]
 **cursor** | **String**|  | [optional] 
 **from** | **DateTime**|  | [optional] 
 **to** | **DateTime**|  | [optional] 

### Return type

[**ListPortfolioSnapshots200Response**](ListPortfolioSnapshots200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listPortfolios**
> ListPortfolios200Response listPortfolios(limit, cursor)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getPortfoliosApi();
final int limit = 56; // int | 
final String cursor = cursor_example; // String | 

try {
    final response = api.listPortfolios(limit, cursor);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PortfoliosApi->listPortfolios: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **limit** | **int**|  | [optional] [default to 20]
 **cursor** | **String**|  | [optional] 

### Return type

[**ListPortfolios200Response**](ListPortfolios200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **patchPortfolio**
> CreatePortfolio201Response patchPortfolio(portfolioId, ifMatch, patchPortfolioRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getPortfoliosApi();
final String portfolioId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 
final PatchPortfolioRequest patchPortfolioRequest = ; // PatchPortfolioRequest | 

try {
    final response = api.patchPortfolio(portfolioId, ifMatch, patchPortfolioRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PortfoliosApi->patchPortfolio: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **portfolioId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **patchPortfolioRequest** | [**PatchPortfolioRequest**](PatchPortfolioRequest.md)|  | 

### Return type

[**CreatePortfolio201Response**](CreatePortfolio201Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

