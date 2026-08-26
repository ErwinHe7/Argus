# ritual_investing_api_client.api.RitualsApi

## Load the API package
```dart
import 'package:ritual_investing_api_client/api.dart';
```

All URIs are relative to *https://api.ritual-investing.example*

Method | HTTP request | Description
------------- | ------------- | -------------
[**completeRitual**](RitualsApi.md#completeritual) | **POST** /v1/rituals/{assignment_id}/complete | 
[**getDailyRitual**](RitualsApi.md#getdailyritual) | **GET** /v1/rituals/daily | 
[**getRitualAssignment**](RitualsApi.md#getritualassignment) | **GET** /v1/rituals/{assignment_id} | 
[**getRitualEvidence**](RitualsApi.md#getritualevidence) | **GET** /v1/rituals/{assignment_id}/evidence | 
[**listRitualHistory**](RitualsApi.md#listritualhistory) | **GET** /v1/rituals/history | 
[**revealRitual**](RitualsApi.md#revealritual) | **POST** /v1/rituals/{assignment_id}/reveal | 


# **completeRitual**
> GetRitualAssignment200Response completeRitual(assignmentId, ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getRitualsApi();
final String assignmentId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 

try {
    final response = api.completeRitual(assignmentId, ifMatch);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RitualsApi->completeRitual: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **assignmentId** | **String**|  | 
 **ifMatch** | **String**|  | 

### Return type

[**GetRitualAssignment200Response**](GetRitualAssignment200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getDailyRitual**
> DailyRitualResponse getDailyRitual(date, mode)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getRitualsApi();
final DateTime date = 2013-10-20; // DateTime | 
final String mode = mode_example; // String | 

try {
    final response = api.getDailyRitual(date, mode);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RitualsApi->getDailyRitual: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **date** | **DateTime**|  | [optional] 
 **mode** | **String**|  | [optional] [default to 'tarot']

### Return type

[**DailyRitualResponse**](DailyRitualResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getRitualAssignment**
> GetRitualAssignment200Response getRitualAssignment(assignmentId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getRitualsApi();
final String assignmentId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getRitualAssignment(assignmentId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RitualsApi->getRitualAssignment: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **assignmentId** | **String**|  | 

### Return type

[**GetRitualAssignment200Response**](GetRitualAssignment200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getRitualEvidence**
> RitualEvidenceResponse getRitualEvidence(assignmentId)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getRitualsApi();
final String assignmentId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getRitualEvidence(assignmentId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RitualsApi->getRitualEvidence: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **assignmentId** | **String**|  | 

### Return type

[**RitualEvidenceResponse**](RitualEvidenceResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listRitualHistory**
> RitualHistoryResponse listRitualHistory(mode, from, to, cursor, limit)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getRitualsApi();
final String mode = mode_example; // String | 
final DateTime from = 2013-10-20; // DateTime | 
final DateTime to = 2013-10-20; // DateTime | 
final String cursor = cursor_example; // String | 
final int limit = 56; // int | 

try {
    final response = api.listRitualHistory(mode, from, to, cursor, limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RitualsApi->listRitualHistory: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **mode** | **String**|  | [optional] 
 **from** | **DateTime**|  | [optional] 
 **to** | **DateTime**|  | [optional] 
 **cursor** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 20]

### Return type

[**RitualHistoryResponse**](RitualHistoryResponse.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **revealRitual**
> GetRitualAssignment200Response revealRitual(assignmentId, ifMatch)



### Example
```dart
import 'package:ritual_investing_api_client/api.dart';
// TODO Configure OAuth2 access token for authorization: Auth0OAuth
//defaultApiClient.getAuthentication<OAuth>('Auth0OAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = RitualInvestingApiClient().getRitualsApi();
final String assignmentId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String ifMatch = ifMatch_example; // String | 

try {
    final response = api.revealRitual(assignmentId, ifMatch);
    print(response);
} on DioException catch (e) {
    print('Exception when calling RitualsApi->revealRitual: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **assignmentId** | **String**|  | 
 **ifMatch** | **String**|  | 

### Return type

[**GetRitualAssignment200Response**](GetRitualAssignment200Response.md)

### Authorization

[Auth0OAuth](../README.md#Auth0OAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

