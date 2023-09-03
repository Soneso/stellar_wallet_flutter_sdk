@Timeout(const Duration(seconds: 400))
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

void main() {

  String anchorToml = '''
      # Sample stellar.toml
      VERSION="2.0.0"
      
      NETWORK_PASSPHRASE="Test SDF Network ; September 2015"
      WEB_AUTH_ENDPOINT="https://api.anchor.org/auth"
      TRANSFER_SERVER_SEP0024="http://api.stellar.org/transfer-sep24/"
      KYC_SERVER = "http://api.stellar.org/kyc-sep-12/"
      SIGNING_KEY="GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
      
      [[CURRENCIES]]
      code="USDC"
      issuer="GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM"
      display_decimals=2
      
      [[CURRENCIES]]
      code="ETH"
      issuer="GAOO3LWBC4XF6VWRP5ESJ6IBHAISVJMSBTALHOQM2EZG7Q477UWA6L7U"
      display_decimals=7
     ''';

  const anchorDomain = "place.anchor.com";

  const serviceAddress = "http://api.stellar.org/kyc";
  const jwtToken =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJHQTZVSVhYUEVXWUZJTE5VSVdBQzM3WTRRUEVaTVFWREpIREtWV0ZaSjJLQ1dVQklVNUlYWk5EQSIsImp0aSI6IjE0NGQzNjdiY2IwZTcyY2FiZmRiZGU2MGVhZTBhZDczM2NjNjVkMmE2NTg3MDgzZGFiM2Q2MTZmODg1MTkwMjQiLCJpc3MiOiJodHRwczovL2ZsYXBweS1iaXJkLWRhcHAuZmlyZWJhc2VhcHAuY29tLyIsImlhdCI6MTUzNDI1Nzk5NCwiZXhwIjoxNTM0MzQ0Mzk0fQ.8nbB83Z6vGBgC1X9r3N6oQCFTBzDiITAfCJasRft0z0";
  const customerId = "d1ce2f48-3ff1-495d-9240-7a50d806cfed";
  const accountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP";

  String requestGetCustomerSuccess() {
    return "{\"id\": \"d1ce2f48-3ff1-495d-9240-7a50d806cfed\",\"status\": \"ACCEPTED\",\"provided_fields\": {   \"first_name\": {      \"description\": \"The customer's first name\",      \"type\": \"string\",      \"status\": \"ACCEPTED\"   },   \"last_name\": {      \"description\": \"The customer's last name\",      \"type\": \"string\",      \"status\": \"ACCEPTED\"   },   \"email_address\": {      \"description\": \"The customer's email address\",      \"type\": \"string\",      \"status\": \"ACCEPTED\"   }}}";
  }

  String requestGetCustomerNotAllRequiredInfo() {
    return "{\"id\": \"d1ce2f48-3ff1-495d-9240-7a50d806cfed\",\"status\": \"NEEDS_INFO\",\"fields\": {   \"mobile_number\": {      \"description\": \"phone number of the customer\",      \"type\": \"string\"   },   \"email_address\": {      \"description\": \"email address of the customer\",      \"type\": \"string\",      \"optional\": true   }},\"provided_fields\": {   \"first_name\": {      \"description\": \"The customer's first name\",      \"type\": \"string\",      \"status\": \"ACCEPTED\"   },   \"last_name\": {      \"description\": \"The customer's last name\",      \"type\": \"string\",      \"status\": \"ACCEPTED\"   }}}";
  }

  String requestGetCustomerRequiresInfo() {
    return "{\"status\": \"NEEDS_INFO\",\"fields\": {   \"email_address\": {      \"description\": \"Email address of the customer\",      \"type\": \"string\",      \"optional\": true   },   \"id_type\": {      \"description\": \"Government issued ID\",      \"type\": \"string\",      \"choices\": [         \"Passport\",         \"Drivers License\",         \"State ID\"      ]   },   \"photo_id_front\": {      \"description\": \"A clear photo of the front of the government issued ID\",      \"type\": \"binary\"  }}}";
  }

  String requestGetCustomerProcessing() {
    return "{ \"id\": \"d1ce2f48-3ff1-495d-9240-7a50d806cfed\", \"status\": \"PROCESSING\", \"message\": \"Photo ID requires manual review. This process typically takes 1-2 business days.\", \"provided_fields\": {   \"photo_id_front\": {      \"description\": \"A clear photo of the front of the government issued ID\",      \"type\": \"binary\",      \"status\": \"PROCESSING\"   } }}";
  }

  String requestGetCustomerRejected() {
    return "{\"id\": \"d1ce2f48-3ff1-495d-9240-7a50d806cfed\",\"status\": \"REJECTED\",\"message\": \"This person is on a sanctions list\"}";
  }

  String requestGetCustomerRequiresVerification() {
    return "{\"id\": \"d1ce2f48-3ff1-495d-9240-7a50d806cfed\",\"status\": \"NEEDS_INFO\",\"provided_fields\": {   \"mobile_number\": {      \"description\": \"phone number of the customer\",      \"type\": \"string\",      \"status\": \"VERIFICATION_REQUIRED\"   }}}";
  }

  String requestPutCustomerInfo() {
    return "{\"id\": \"d1ce2f48-3ff1-495d-9240-7a50d806cfed\"}";
  }

  String requestPutCustomerVerification() {
    return "{\"id\": \"d1ce2f48-3ff1-495d-9240-7a50d806cfed\",\"status\": \"ACCEPTED\",\"provided_fields\": {   \"mobile_number\": {      \"description\": \"phone number of the customer\",      \"type\": \"string\",      \"status\": \"ACCEPTED\"   }}}";
  }

  test('test get customer info success', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("customer") &&
          authHeader.contains(jwtToken)) {
        return http.Response(requestGetCustomerSuccess(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet(StellarConfiguration.testNet);
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);
    AuthToken authToken = AuthToken(jwtToken);
    Sep12 sep12 = await anchor.sep12(authToken);
    GetCustomerResponse infoResponse = await sep12.getByIdAndType(customerId, "small-transaction-amount");

    assert(infoResponse.id == customerId);
    assert(infoResponse.sep12Status == Sep12Status.accepted);
    assert(infoResponse.providedFields != null);

    Map<String, ProvidedField?>? providedFields = infoResponse.providedFields;
    assert(providedFields!.length == 3);

    ProvidedField? firstName = providedFields!["first_name"];
    assert(firstName != null);
    assert(firstName!.description == "The customer's first name");
    assert(firstName!.type == FieldType.string);
    assert(firstName!.status == Sep12Status.accepted);

    ProvidedField? lastName = providedFields["last_name"];
    assert(lastName != null);
    assert(lastName!.description == "The customer's last name");
    assert(lastName!.type == FieldType.string);
    assert(lastName!.status == Sep12Status.accepted);

    ProvidedField? emailAddress = providedFields["email_address"];
    assert(emailAddress != null);
    assert(emailAddress!.description == "The customer's email address");
    assert(emailAddress!.type == FieldType.string);
    assert(emailAddress!.status == Sep12Status.accepted);
  });

  test('test get customer not all required info', () async {

    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("customer") &&
          authHeader.contains(jwtToken)) {
        return http.Response(requestGetCustomerNotAllRequiredInfo(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet(StellarConfiguration.testNet);
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);
    AuthToken authToken = AuthToken(jwtToken);
    Sep12 sep12 = await anchor.sep12(authToken);
    GetCustomerResponse infoResponse = await sep12.getByIdAndType(customerId, "small-transaction-amount");

    assert(infoResponse.id == customerId);
    assert(infoResponse.sep12Status == Sep12Status.needsInfo);
    assert(infoResponse.fields != null);

    Map<String, Field?>? fields = infoResponse.fields;
    assert(fields!.length == 2);

    Field? mobileNr = fields!["mobile_number"];
    assert(mobileNr != null);
    assert(mobileNr!.description == "phone number of the customer");
    assert(mobileNr!.type == FieldType.string);

    Field? emailAddress = fields["email_address"];
    assert(emailAddress != null);
    assert(emailAddress!.description == "email address of the customer");
    assert(emailAddress!.type == FieldType.string);
    assert(emailAddress!.optional!);

    assert(infoResponse.providedFields != null);

    Map<String, ProvidedField?>? providedFields = infoResponse.providedFields;
    assert(providedFields!.length == 2);

    ProvidedField? firstName = providedFields!["first_name"];
    assert(firstName != null);
    assert(firstName!.description == "The customer's first name");
    assert(firstName!.type == FieldType.string);
    assert(firstName!.status == Sep12Status.accepted);

    ProvidedField? lastName = providedFields["last_name"];
    assert(lastName != null);
    assert(lastName!.description == "The customer's last name");
    assert(lastName!.type == FieldType.string);
    assert(lastName!.status == Sep12Status.accepted);
  });

  test('test get customer requires info', () async {

    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("customer") &&
          authHeader.contains(jwtToken)) {
        return http.Response(requestGetCustomerRequiresInfo(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet(StellarConfiguration.testNet);
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);
    AuthToken authToken = AuthToken(jwtToken);
    Sep12 sep12 = await anchor.sep12(authToken);
    GetCustomerResponse infoResponse = await sep12.getByIdAndType(customerId, "small-transaction-amount");

    assert(infoResponse.sep12Status == Sep12Status.needsInfo);
    assert(infoResponse.fields != null);

    Map<String, Field?>? fields = infoResponse.fields;
    assert(fields!.length == 3);

    Field? emailAddress = fields!["email_address"];
    assert(emailAddress != null);
    assert(emailAddress!.description == "Email address of the customer");
    assert(emailAddress!.type == FieldType.string);
    assert(emailAddress!.optional!);

    Field? idType = fields["id_type"];
    assert(idType != null);
    assert(idType!.description == "Government issued ID");
    assert(idType!.type == FieldType.string);
    assert(idType!.choices != null);
    List<String?>? idTypeChoices = idType!.choices;
    assert(idTypeChoices!.length == 3);
    assert(idTypeChoices!.contains("Passport"));
    assert(idTypeChoices!.contains("Drivers License"));
    assert(idTypeChoices!.contains("State ID"));

    Field? photoIdFront = fields["photo_id_front"];
    assert(photoIdFront != null);
    assert(photoIdFront!.description == "A clear photo of the front of the government issued ID");
    assert(photoIdFront!.type == FieldType.binary);
  });

  test('test get customer processing', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("customer") &&
          authHeader.contains(jwtToken)) {
        return http.Response(requestGetCustomerProcessing(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet(StellarConfiguration.testNet);
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);
    AuthToken authToken = AuthToken(jwtToken);
    Sep12 sep12 = await anchor.sep12(authToken);
    GetCustomerResponse infoResponse = await sep12.getByIdAndType(customerId, "small-transaction-amount");

    assert(infoResponse.id == customerId);
    assert(infoResponse.sep12Status == Sep12Status.processing);
    assert(infoResponse.message ==
        "Photo ID requires manual review. This process typically takes 1-2 business days.");
    assert(infoResponse.providedFields != null);

    Map<String, ProvidedField?>? providedFields = infoResponse.providedFields;
    assert(providedFields!.length == 1);

    ProvidedField? photoIdFront = providedFields!["photo_id_front"];
    assert(photoIdFront != null);
    assert(photoIdFront!.description == "A clear photo of the front of the government issued ID");
    assert(photoIdFront!.type == FieldType.binary);
    assert(photoIdFront!.status == Sep12Status.processing);
  });

  test('test get customer rejected', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("customer") &&
          authHeader.contains(jwtToken)) {
        return http.Response(requestGetCustomerRejected(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet(StellarConfiguration.testNet);
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);
    AuthToken authToken = AuthToken(jwtToken);
    Sep12 sep12 = await anchor.sep12(authToken);
    GetCustomerResponse infoResponse = await sep12.getByIdAndType(customerId, "small-transaction-amount");

    assert(infoResponse.id == customerId);
    assert(infoResponse.sep12Status == Sep12Status.rejected);
    assert(infoResponse.message == "This person is on a sanctions list");
  });

  test('test get customer requires verification', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("customer") &&
          authHeader.contains(jwtToken)) {
        return http.Response(requestGetCustomerRequiresVerification(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet(StellarConfiguration.testNet);
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);
    AuthToken authToken = AuthToken(jwtToken);
    Sep12 sep12 = await anchor.sep12(authToken);
    GetCustomerResponse infoResponse = await sep12.getByIdAndType(customerId, "small-transaction-amount");

    assert(infoResponse.id == customerId);
    assert(infoResponse.sep12Status == Sep12Status.needsInfo);
    assert(infoResponse.providedFields != null);

    Map<String, ProvidedField?>? providedFields = infoResponse.providedFields;
    assert(providedFields!.length == 1);

    ProvidedField? mobileNr = providedFields!["mobile_number"];
    assert(mobileNr != null);
    assert(mobileNr!.description == "phone number of the customer");
    assert(mobileNr!.type == FieldType.string);
    assert(mobileNr!.status == Sep12Status.verificationRequired);
  });

  test('add customer', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      String authHeader = request.headers["Authorization"]!;
      String contentType = request.headers["content-type"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "PUT" &&
          request.url.toString().contains("customer") &&
          authHeader.contains(jwtToken) &&
          contentType.startsWith("multipart/form-data;")) {
        return http.Response(requestPutCustomerInfo(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet(StellarConfiguration.testNet);
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);
    AuthToken authToken = AuthToken(jwtToken);
    Sep12 sep12 = await anchor.sep12(authToken);
    AddCustomerResponse addResponse = await sep12.add({"account_id" : accountId});
    assert(addResponse.id == customerId);

  });

  test('update customer', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      String authHeader = request.headers["Authorization"]!;
      String contentType = request.headers["content-type"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "PUT" &&
          request.url.toString().contains("customer") &&
          authHeader.contains(jwtToken) &&
          contentType.startsWith("multipart/form-data;")) {
        return http.Response(requestPutCustomerInfo(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet(StellarConfiguration.testNet);
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);
    AuthToken authToken = AuthToken(jwtToken);
    Sep12 sep12 = await anchor.sep12(authToken);
    Map<String, String> sep9Info = {
      "email_address" : "john@doe.com",
      "first_name" : "john",
      "last_name" : "doe"
    };
    AddCustomerResponse addResponse = await sep12.update(sep9Info, customerId);
    assert(addResponse.id == customerId);
  });

  test('customer verification', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      String authHeader = request.headers["Authorization"]!;
      String contentType = request.headers["content-type"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "PUT" &&
          request.url.toString().contains("customer/verification") &&
          authHeader.contains(jwtToken) &&
          contentType.startsWith("multipart/form-data;")) {
        return http.Response(requestPutCustomerVerification(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet(StellarConfiguration.testNet);
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);
    AuthToken authToken = AuthToken(jwtToken);
    Sep12 sep12 = await anchor.sep12(authToken);

    Map<String, String> verificationFields = {};
    verificationFields["id"] = customerId;
    verificationFields["mobile_number_verification"] = "2735021";

    GetCustomerResponse infoResponse = await sep12.verify(verificationFields, customerId);

    assert(infoResponse.id == customerId);
    assert(infoResponse.sep12Status == Sep12Status.accepted);
    assert(infoResponse.providedFields != null);

    Map<String, ProvidedField?>? providedFields =  infoResponse.providedFields;
    assert(providedFields!.length == 1);

    ProvidedField? mobileNr = providedFields!["mobile_number"];
    assert(mobileNr != null);
    assert(mobileNr!.description == "phone number of the customer");
    assert(mobileNr!.type == FieldType.string);
    assert(mobileNr!.status == Sep12Status.accepted);
  });

  test('delete customer', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      String authHeader = request.headers["Authorization"]!;
      String contentType = request.headers["content-type"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "DELETE" &&
          request.url.toString().contains("customer/" + accountId) &&
          authHeader.contains(jwtToken) &&
          contentType.startsWith("multipart/form-data;")) {
        return http.Response("", 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet(StellarConfiguration.testNet);
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);
    AuthToken authToken = AuthToken(jwtToken);
    Sep12 sep12 = await anchor.sep12(authToken);
    http.Response? response = await sep12.delete(accountId);
    assert(response.statusCode == 200);
  });
}
