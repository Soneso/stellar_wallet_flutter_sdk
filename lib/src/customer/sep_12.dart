// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:stellar_wallet_flutter_sdk/src/auth/sep_10.dart';
import 'package:http/http.dart' as http;
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;

class Sep12 {
  AuthToken token;
  String serviceAddress;
  http.Client? httpClient;
  Map<String, String>? httpRequestHeaders;
  late flutter_sdk.KYCService kycService;

  Sep12(this.token, this.serviceAddress,
      {this.httpClient, this.httpRequestHeaders}) {
    kycService = flutter_sdk.KYCService(serviceAddress,
        httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);
  }

  /// Get customer information by customer [id] and [type].
  Future<GetCustomerResponse> getByIdAndType(String id, String type) async {
    return await get(id: id, type: type);
  }

  /// Get customer information only by using the auth token.
  Future<GetCustomerResponse> getByAuthTokenOnly() async {
    return await get();
  }

  /// Get customer information by different parameters. See Sep-12.
  /// If all parameters are null, it loads by auth token only.
  Future<GetCustomerResponse> get(
      {String? id,
      String? account,
      String? memo,
      String? type,
      String? transactionId,
      String? lang}) async {
    flutter_sdk.GetCustomerInfoRequest request =
        flutter_sdk.GetCustomerInfoRequest();

    request.id = id;
    request.account = account;
    request.memo = memo;
    request.type = type;
    request.transactionId = transactionId;
    request.jwt = token.jwt;

    flutter_sdk.GetCustomerInfoResponse infoResponse =
        await kycService.getCustomerInfo(request);
    return GetCustomerResponse.from(infoResponse);
  }

  /// Create a new customer. Pass a map containing customer [sep9Info]. To create a new customer fields
  /// first_name, last_name, and email_address are required. You can also pass [sep9Files].
  /// The [type] of action the customer is being KYC for can optionally be passed.
  /// [memo] and [transactionId] are also optional parameters. See the
  /// Specification on SEP-12 definition.
  Future<AddCustomerResponse> add(Map<String, String> sep9Info,
      {Map<String, Uint8List>? sep9Files,
      String? memo,
      String? type,
      String? transactionId}) async {
    flutter_sdk.PutCustomerInfoRequest request =
        flutter_sdk.PutCustomerInfoRequest();
    request.jwt = token.jwt;
    request.customFields = sep9Info;
    request.customFiles = sep9Files;
    request.memo = memo;
    request.type = type;
    request.transactionId = transactionId;
    flutter_sdk.PutCustomerInfoResponse infoResponse =
        await kycService.putCustomerInfo(request);
    return AddCustomerResponse.from(infoResponse);
  }

  /// Update a customer by [id] of the customer as returned in the response of an add request. If the
  /// customer has not been registered, they do not yet have an id. You can pass a map containing
  /// customer [sep9Info] and [sep9Files]. The [type] of action the customer is being KYC for can
  /// optionally be passed. [memo] and [transactionId] are also optional parameters. See the
  /// Specification on SEP-12 definition.
  Future<AddCustomerResponse> update(Map<String, String> sep9Info, String id,
      {Map<String, Uint8List>? sep9Files,
      String? memo,
      String? type,
      String? transactionId}) async {
    flutter_sdk.PutCustomerInfoRequest request =
        flutter_sdk.PutCustomerInfoRequest();
    request.jwt = token.jwt;
    request.id = id;
    request.customFields = sep9Info;
    request.customFiles = sep9Files;
    request.memo = memo;
    request.type = type;
    request.transactionId = transactionId;
    flutter_sdk.PutCustomerInfoResponse infoResponse =
        await kycService.putCustomerInfo(request);
    return AddCustomerResponse.from(infoResponse);
  }

  /// This endpoint allows servers to accept data values, usually confirmation codes, that verify a previously provided field via add.
  /// Pass a map containing the sep 9 [verificationFields] for the customer identified by [id].
  Future<GetCustomerResponse> verify(
      Map<String, String> verificationFields, String id) async {
    flutter_sdk.PutCustomerVerificationRequest request =
        flutter_sdk.PutCustomerVerificationRequest();
    request.jwt = token.jwt;
    request.id = id;
    request.verificationFields = verificationFields;

    flutter_sdk.GetCustomerInfoResponse infoResponse =
        await kycService.putCustomerVerification(request);
    return GetCustomerResponse.from(infoResponse);
  }

  /// Delete a customer using [account] address.
  Future<http.Response> delete(String account,
      {String? memo, String? memoType}) async {
    return await kycService.deleteCustomer(account, memo, memoType, token.jwt);
  }
}

class AddCustomerResponse {
  String id;
  AddCustomerResponse(this.id);

  static AddCustomerResponse from(
      flutter_sdk.PutCustomerInfoResponse infoResponse) {
    return AddCustomerResponse(infoResponse.id);
  }
}

class GetCustomerResponse {
  String? id;
  Sep12Status sep12Status;
  Map<String, Field>? fields;
  Map<String, ProvidedField>? providedFields;
  String? message;

  GetCustomerResponse(
      {required this.sep12Status,
      this.id,
      this.fields,
      this.providedFields,
      this.message});

  static GetCustomerResponse from(
      flutter_sdk.GetCustomerInfoResponse infoResponse) {
    GetCustomerResponse result =
        GetCustomerResponse(sep12Status: Sep12Status(infoResponse.status));
    result.id = infoResponse.id;

    if (infoResponse.fields != null) {
      result.fields = <String, Field>{};
      for (String key in infoResponse.fields!.keys) {
        result.fields![key] = Field.from(infoResponse.fields![key]!);
      }
    }

    if (infoResponse.providedFields != null) {
      result.providedFields = <String, ProvidedField>{};
      for (String key in infoResponse.providedFields!.keys) {
        result.providedFields![key] =
            ProvidedField.from(infoResponse.providedFields![key]!);
      }
    }
    result.message = infoResponse.message;
    return result;
  }
}

class Field {
  FieldType type;
  String? description;
  List<String>? choices;
  bool? optional;

  Field({required this.type, this.description, this.choices, this.optional});

  static Field from(flutter_sdk.GetCustomerInfoField infoField) {
    Field result = Field(type: FieldType.fromString(infoField.type));
    result.description = infoField.description;
    result.choices = infoField.choices;
    result.optional = infoField.optional;
    return result;
  }
}

class ProvidedField {
  FieldType type;
  String? description;
  List<String>? choices;
  bool? optional;
  Sep12Status? status;
  String? error;

  ProvidedField(
      {required this.type,
      this.description,
      this.choices,
      this.optional,
      this.status,
      this.error});

  static ProvidedField from(
      flutter_sdk.GetCustomerInfoProvidedField infoProvidedField) {

    ProvidedField result = ProvidedField(type: FieldType.fromString(infoProvidedField.type));
    result.description = infoProvidedField.description;
    result.choices = infoProvidedField.choices;
    result.optional = infoProvidedField.optional;
    if (infoProvidedField.status != null) {
      result.status = Sep12Status(infoProvidedField.status!);
    }

    result.error = infoProvidedField.error;

    return result;
  }
}

class FieldType {
  final String _value;
  const FieldType._internal(this._value);
  @override
  toString() => _value;
  FieldType(this._value);
  get value => _value;

  static const string = FieldType._internal("string");
  static const binary = FieldType._internal("binary");
  static const number = FieldType._internal("number");
  static const date = FieldType._internal("date");

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return (other is FieldType && other.value == value);
  }

  @override
  int get hashCode => Object.hash(value, value);

  static FieldType fromString(String typeString) {

    if (binary.value == typeString) {
      return binary;
    }
    if (number.value == typeString) {
      return number;
    }
    if (date.value == typeString) {
      return date;
    }

    return string;
  }
}

class Sep12Status {
  final String _value;
  const Sep12Status._internal(this._value);
  @override
  toString() => value;
  Sep12Status(this._value);
  get value => _value;

  static const needsInfo = Sep12Status._internal("NEEDS_INFO");
  static const accepted = Sep12Status._internal("ACCEPTED");
  static const processing = Sep12Status._internal("PROCESSING");
  static const rejected = Sep12Status._internal("REJECTED");
  static const verificationRequired =
      Sep12Status._internal("VERIFICATION_REQUIRED");

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return (other is Sep12Status && other.value == value);
  }

  @override
  int get hashCode => Object.hash(value, value);
}
