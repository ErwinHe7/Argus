# ritual_investing_api_client.api.AdminApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://PROJECT_REF.supabase.co/functions/v1/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**commandAdminEditorial**](AdminApi.md#commandadmineditorial) | **POST** /v1/admin/editorial/{item_id}/commands | 
[**createAdminEditorial**](AdminApi.md#createadmineditorial) | **POST** /v1/admin/editorial | 
[**createAdminEditorialRevision**](AdminApi.md#createadmineditorialrevision) | **POST** /v1/admin/editorial/{item_id}/revisions | 
[**getAdminEditorial**](AdminApi.md#getadmineditorial) | **GET** /v1/admin/editorial/{item_id} | 
[**getAdminSession**](AdminApi.md#getadminsession) | **GET** /v1/admin/session | 
[**issueAdminStepUp**](AdminApi.md#issueadminstepup) | **POST** /v1/admin/step-up | 
[**listAdminAudit**](AdminApi.md#listadminaudit) | **GET** /v1/admin/audit | 
[**listAdminEditorial**](AdminApi.md#listadmineditorial) | **GET** /v1/admin/editorial | 
[**patchAdminEditorialRevision**](AdminApi.md#patchadmineditorialrevision) | **PATCH** /v1/admin/editorial/{item_id}/revisions/{revision_id} | 


# **commandAdminEditorial**
> ListAdminAudit200Response commandAdminEditorial(itemId, commandAdminEditorialRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final CommandAdminEditorialRequest commandAdminEditorialRequest = ; // CommandAdminEditorialRequest | 

try {
    final response = api.commandAdminEditorial(itemId, commandAdminEditorialRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminApi->commandAdminEditorial: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **commandAdminEditorialRequest** | [**CommandAdminEditorialRequest**](CommandAdminEditorialRequest.md)|  | 

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createAdminEditorial**
> ListAdminAudit200Response createAdminEditorial(createAdminEditorialRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminApi();
final CreateAdminEditorialRequest createAdminEditorialRequest = ; // CreateAdminEditorialRequest | 

try {
    final response = api.createAdminEditorial(createAdminEditorialRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminApi->createAdminEditorial: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **createAdminEditorialRequest** | [**CreateAdminEditorialRequest**](CreateAdminEditorialRequest.md)|  | 

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createAdminEditorialRevision**
> ListAdminAudit200Response createAdminEditorialRevision(itemId, createAdminEditorialRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final CreateAdminEditorialRevisionRequest createAdminEditorialRevisionRequest = ; // CreateAdminEditorialRevisionRequest | 

try {
    final response = api.createAdminEditorialRevision(itemId, createAdminEditorialRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminApi->createAdminEditorialRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **createAdminEditorialRevisionRequest** | [**CreateAdminEditorialRevisionRequest**](CreateAdminEditorialRevisionRequest.md)|  | 

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAdminEditorial**
> ListAdminAudit200Response getAdminEditorial(itemId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getAdminEditorial(itemId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminApi->getAdminEditorial: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAdminSession**
> ListAdminAudit200Response getAdminSession()



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminApi();

try {
    final response = api.getAdminSession();
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminApi->getAdminSession: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **issueAdminStepUp**
> ListAdminAudit200Response issueAdminStepUp(issueAdminStepUpRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminApi();
final IssueAdminStepUpRequest issueAdminStepUpRequest = ; // IssueAdminStepUpRequest | 

try {
    final response = api.issueAdminStepUp(issueAdminStepUpRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminApi->issueAdminStepUp: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **issueAdminStepUpRequest** | [**IssueAdminStepUpRequest**](IssueAdminStepUpRequest.md)|  | 

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminAudit**
> ListAdminAudit200Response listAdminAudit(limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminApi();
final int limit = 56; // int | 

try {
    final response = api.listAdminAudit(limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminApi->listAdminAudit: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **limit** | **int**|  | [optional] [default to 25]

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminEditorial**
> ListAdminAudit200Response listAdminEditorial(limit, kind)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminApi();
final int limit = 56; // int | 
final String kind = kind_example; // String | 

try {
    final response = api.listAdminEditorial(limit, kind);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminApi->listAdminEditorial: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **limit** | **int**|  | [optional] [default to 25]
 **kind** | **String**|  | [optional] 

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **patchAdminEditorialRevision**
> ListAdminAudit200Response patchAdminEditorialRevision(itemId, revisionId, ifMatch, createAdminEditorialRevisionRequest)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';

final api = RitualInvestingApiClient().getAdminApi();
final String itemId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String revisionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 
final CreateAdminEditorialRevisionRequest createAdminEditorialRevisionRequest = ; // CreateAdminEditorialRevisionRequest | 

try {
    final response = api.patchAdminEditorialRevision(itemId, revisionId, ifMatch, createAdminEditorialRevisionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdminApi->patchAdminEditorialRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **revisionId** | **String**|  | 
 **ifMatch** | **String**|  | 
 **createAdminEditorialRevisionRequest** | [**CreateAdminEditorialRevisionRequest**](CreateAdminEditorialRevisionRequest.md)|  | 

### Return type

[**ListAdminAudit200Response**](ListAdminAudit200Response.md)

### Authorization

[SupabaseBearer](../README.md#SupabaseBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

