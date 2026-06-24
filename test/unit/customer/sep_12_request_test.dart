// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

@Timeout(Duration(seconds: 120))
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

/// Outbound-request forwarding tests for [Sep12].
///
/// These tests inject a [MockClient] directly into [Sep12] and capture the
/// outbound HTTP request so that the parameters assembled by `sep_12.dart`
/// (and threaded through the base SDK KYCService) can be asserted exactly.
///
/// GET /customer carries its parameters as URL query parameters. PUT and
/// DELETE use multipart/form-data, so the form fields are recovered by parsing
/// the multipart body of the captured request.
void main() {
  const serviceAddress = "https://api.stellar.org/kyc";
  const jwtToken =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJHQTZVSVhYUEVXWUZJTE5VSVdBQzM3WTRRUEVaTVFWREpIREtWV0ZaSjJLQ1dVQklVNUlYWk5EQSIsImp0aSI6IjE0NGQzNjdiY2IwZTcyY2FiZmRiZGU2MGVhZTBhZDczM2NjNjVkMmE2NTg3MDgzZGFiM2Q2MTZmODg1MTkwMjQiLCJpc3MiOiJodHRwczovL2ZsYXBweS1iaXJkLWRhcHAuZmlyZWJhc2VhcHAuY29tLyIsImlhdCI6MTUzNDI1Nzk5NCwiZXhwIjoxNTM0MzQ0Mzk0fQ.8nbB83Z6vGBgC1X9r3N6oQCFTBzDiITAfCJasRft0z0";
  const customerId = "d1ce2f48-3ff1-495d-9240-7a50d806cfed";
  const accountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP";

  /// Minimal valid GET /customer response body the base SDK can parse.
  String getCustomerInfoJson() {
    return json.encode({
      "id": customerId,
      "status": "ACCEPTED",
    });
  }

  /// Minimal valid PUT /customer response body the base SDK can parse.
  String putCustomerInfoJson() {
    return json.encode({"id": customerId});
  }

  /// Minimal valid PUT /customer/verification response the base SDK can parse.
  String putCustomerVerificationJson() {
    return json.encode({
      "id": customerId,
      "status": "ACCEPTED",
    });
  }

  /// Parses the form fields out of a multipart/form-data request body.
  ///
  /// The base SDK serialises PUT/DELETE form fields as multipart parts with a
  /// `Content-Disposition: form-data; name="..."` header. This extracts each
  /// named non-file part and returns it as a name -> value map. File parts
  /// (those carrying a `filename="..."`) are skipped.
  Map<String, String> parseMultipartFields(http.Request request) {
    final contentType = request.headers['content-type'] ??
        request.headers['Content-Type'] ??
        '';
    final boundaryMarker = 'boundary=';
    final boundaryIndex = contentType.indexOf(boundaryMarker);
    expect(boundaryIndex, isNonNegative,
        reason: 'multipart request must declare a boundary');
    final boundary =
        contentType.substring(boundaryIndex + boundaryMarker.length);
    final delimiter = '--$boundary';

    final body = request.body;
    final result = <String, String>{};
    for (final rawPart in body.split(delimiter)) {
      final part = rawPart.trim();
      if (part.isEmpty || part == '--') {
        continue;
      }
      final headerBodySplit = part.indexOf('\r\n\r\n');
      if (headerBodySplit < 0) {
        continue;
      }
      final headerSection = part.substring(0, headerBodySplit);
      final valueSection = part.substring(headerBodySplit + 4);
      final nameMatch =
          RegExp(r'name="([^"]*)"').firstMatch(headerSection);
      if (nameMatch == null) {
        continue;
      }
      // Skip file parts: they carry their own filename in the disposition.
      if (headerSection.contains('filename=')) {
        continue;
      }
      result[nameMatch.group(1)!] = valueSection.trimRight();
    }
    return result;
  }

  group('Sep12 get() request forwarding', () {
    test('forwards lang as a query parameter (regression guard)', () async {
      late Uri capturedUri;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(getCustomerInfoJson(), 200);
      });

      final sep12 = Sep12(AuthToken(jwtToken), serviceAddress, httpClient: mock);
      await sep12.get(lang: 'de');

      expect(capturedUri.queryParameters.containsKey('lang'), isTrue,
          reason:
              'lang must be forwarded as a query parameter to GET /customer');
      expect(capturedUri.queryParameters['lang'], 'de');
    });

    test('forwards all identifying query parameters', () async {
      late Uri capturedUri;
      late Map<String, String> capturedHeaders;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        return http.Response(getCustomerInfoJson(), 200);
      });

      final sep12 = Sep12(AuthToken(jwtToken), serviceAddress, httpClient: mock);
      await sep12.get(
        id: customerId,
        account: accountId,
        memo: '1234567890',
        type: 'sep31-sender',
        transactionId: 'tx-abc-123',
        lang: 'pt',
      );

      final params = capturedUri.queryParameters;
      expect(params['id'], customerId);
      expect(params['account'], accountId);
      expect(params['memo'], '1234567890');
      expect(params['type'], 'sep31-sender');
      expect(params['transaction_id'], 'tx-abc-123');
      expect(params['lang'], 'pt');

      // jwt is forwarded as a Bearer authorization header, not a query param.
      expect(capturedUri.path, endsWith('/customer'));
      expect(capturedHeaders['Authorization'] ?? capturedHeaders['authorization'],
          'Bearer $jwtToken');
      expect(params.containsKey('jwt'), isFalse);
    });

    test('omits query parameters that were not supplied', () async {
      late Uri capturedUri;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(getCustomerInfoJson(), 200);
      });

      final sep12 = Sep12(AuthToken(jwtToken), serviceAddress, httpClient: mock);
      await sep12.get(id: customerId);

      final params = capturedUri.queryParameters;
      expect(params['id'], customerId);
      expect(params.containsKey('account'), isFalse);
      expect(params.containsKey('memo'), isFalse);
      expect(params.containsKey('type'), isFalse);
      expect(params.containsKey('transaction_id'), isFalse);
      expect(params.containsKey('lang'), isFalse);
    });

    test('getByIdAndType forwards id and type only', () async {
      late Uri capturedUri;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(getCustomerInfoJson(), 200);
      });

      final sep12 = Sep12(AuthToken(jwtToken), serviceAddress, httpClient: mock);
      await sep12.getByIdAndType(customerId, 'sep6-deposit');

      final params = capturedUri.queryParameters;
      expect(params['id'], customerId);
      expect(params['type'], 'sep6-deposit');
      expect(params.containsKey('account'), isFalse);
      expect(params.containsKey('lang'), isFalse);
    });

    test('getByAuthTokenOnly sends no identifying query parameters', () async {
      late Uri capturedUri;
      late Map<String, String> capturedHeaders;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        return http.Response(getCustomerInfoJson(), 200);
      });

      final sep12 = Sep12(AuthToken(jwtToken), serviceAddress, httpClient: mock);
      await sep12.getByAuthTokenOnly();

      expect(capturedUri.queryParameters, isEmpty);
      expect(capturedHeaders['Authorization'] ?? capturedHeaders['authorization'],
          'Bearer $jwtToken');
    });
  });

  group('Sep12 add() request forwarding', () {
    test('forwards sep9 info as form fields plus memo/type/transactionId',
        () async {
      late http.Request captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(putCustomerInfoJson(), 200);
      });

      final sep12 = Sep12(AuthToken(jwtToken), serviceAddress, httpClient: mock);
      final response = await sep12.add(
        {
          'first_name': 'John',
          'last_name': 'Doe',
          'email_address': 'john@doe.com',
        },
        memo: '9876543210',
        type: 'sep31-sender',
        transactionId: 'tx-add-1',
      );

      expect(response.id, customerId);
      expect(captured.method, 'PUT');
      expect(captured.url.path, endsWith('/customer'));
      expect(
          captured.headers['Authorization'] ?? captured.headers['authorization'],
          'Bearer $jwtToken');

      final fields = parseMultipartFields(captured);
      expect(fields['first_name'], 'John');
      expect(fields['last_name'], 'Doe');
      expect(fields['email_address'], 'john@doe.com');
      expect(fields['memo'], '9876543210');
      expect(fields['type'], 'sep31-sender');
      expect(fields['transaction_id'], 'tx-add-1');
      // add() must not send an id; the customer is created here.
      expect(fields.containsKey('id'), isFalse);
    });

    test('omits memo/type/transactionId when not supplied', () async {
      late http.Request captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(putCustomerInfoJson(), 200);
      });

      final sep12 = Sep12(AuthToken(jwtToken), serviceAddress, httpClient: mock);
      await sep12.add({'first_name': 'Jane'});

      final fields = parseMultipartFields(captured);
      expect(fields['first_name'], 'Jane');
      expect(fields.containsKey('memo'), isFalse);
      expect(fields.containsKey('type'), isFalse);
      expect(fields.containsKey('transaction_id'), isFalse);
      expect(fields.containsKey('id'), isFalse);
    });

    test('forwards sep9 files as multipart file parts', () async {
      late http.Request captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(putCustomerInfoJson(), 200);
      });

      final sep12 = Sep12(AuthToken(jwtToken), serviceAddress, httpClient: mock);
      final fileBytes = Uint8List.fromList(utf8.encode('binary-id-photo'));
      await sep12.add(
        {'first_name': 'John'},
        sep9Files: {'photo_id_front': fileBytes},
      );

      // The non-file fields still carry the sep9 info.
      final fields = parseMultipartFields(captured);
      expect(fields['first_name'], 'John');
      // The file content is present in the multipart body as a file part.
      expect(captured.body.contains('name="photo_id_front"'), isTrue);
      expect(captured.body.contains('binary-id-photo'), isTrue);
    });
  });

  group('Sep12 update() request forwarding', () {
    test('forwards id plus sep9 info and memo/type/transactionId', () async {
      late http.Request captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(putCustomerInfoJson(), 200);
      });

      final sep12 = Sep12(AuthToken(jwtToken), serviceAddress, httpClient: mock);
      final response = await sep12.update(
        {
          'first_name': 'John',
          'last_name': 'Doe',
        },
        customerId,
        memo: '111222',
        type: 'sep6-withdraw',
        transactionId: 'tx-upd-1',
      );

      expect(response.id, customerId);
      expect(captured.method, 'PUT');
      expect(captured.url.path, endsWith('/customer'));

      final fields = parseMultipartFields(captured);
      expect(fields['id'], customerId);
      expect(fields['first_name'], 'John');
      expect(fields['last_name'], 'Doe');
      expect(fields['memo'], '111222');
      expect(fields['type'], 'sep6-withdraw');
      expect(fields['transaction_id'], 'tx-upd-1');
    });

    test('forwards id even when only sep9 info is supplied', () async {
      late http.Request captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(putCustomerInfoJson(), 200);
      });

      final sep12 = Sep12(AuthToken(jwtToken), serviceAddress, httpClient: mock);
      await sep12.update({'email_address': 'new@doe.com'}, customerId);

      final fields = parseMultipartFields(captured);
      expect(fields['id'], customerId);
      expect(fields['email_address'], 'new@doe.com');
      expect(fields.containsKey('memo'), isFalse);
      expect(fields.containsKey('type'), isFalse);
      expect(fields.containsKey('transaction_id'), isFalse);
    });
  });

  group('Sep12 verify() request forwarding', () {
    test('forwards id and verification fields to /customer/verification',
        () async {
      late http.Request captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(putCustomerVerificationJson(), 200);
      });

      final sep12 = Sep12(AuthToken(jwtToken), serviceAddress, httpClient: mock);
      final response = await sep12.verify(
        {'mobile_number_verification': '2735021'},
        customerId,
      );

      expect(response.id, customerId);
      expect(response.sep12Status, Sep12Status.accepted);
      expect(captured.method, 'PUT');
      expect(captured.url.path, endsWith('/customer/verification'));
      expect(
          captured.headers['Authorization'] ?? captured.headers['authorization'],
          'Bearer $jwtToken');

      final fields = parseMultipartFields(captured);
      expect(fields['id'], customerId);
      expect(fields['mobile_number_verification'], '2735021');
    });

    test('forwards multiple verification fields verbatim', () async {
      late http.Request captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(putCustomerVerificationJson(), 200);
      });

      final sep12 = Sep12(AuthToken(jwtToken), serviceAddress, httpClient: mock);
      await sep12.verify(
        {
          'mobile_number_verification': '111111',
          'email_address_verification': '222222',
        },
        customerId,
      );

      final fields = parseMultipartFields(captured);
      expect(fields['id'], customerId);
      expect(fields['mobile_number_verification'], '111111');
      expect(fields['email_address_verification'], '222222');
    });
  });

  group('Sep12 delete() request forwarding', () {
    test('targets /customer/{account} and forwards memo and memoType',
        () async {
      late http.Request captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('', 200);
      });

      final sep12 = Sep12(AuthToken(jwtToken), serviceAddress, httpClient: mock);
      final response = await sep12.delete(
        accountId,
        memo: '4242',
        memoType: 'id',
      );

      expect(response.statusCode, 200);
      expect(captured.method, 'DELETE');
      expect(captured.url.path, endsWith('/customer/$accountId'));
      expect(
          captured.headers['Authorization'] ?? captured.headers['authorization'],
          'Bearer $jwtToken');

      final fields = parseMultipartFields(captured);
      expect(fields['memo'], '4242');
      expect(fields['memo_type'], 'id');
    });

    test('omits memo and memoType when not supplied', () async {
      late http.Request captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('', 200);
      });

      final sep12 = Sep12(AuthToken(jwtToken), serviceAddress, httpClient: mock);
      await sep12.delete(accountId);

      expect(captured.method, 'DELETE');
      expect(captured.url.path, endsWith('/customer/$accountId'));

      final fields = parseMultipartFields(captured);
      expect(fields.containsKey('memo'), isFalse);
      expect(fields.containsKey('memo_type'), isFalse);
    });
  });
}