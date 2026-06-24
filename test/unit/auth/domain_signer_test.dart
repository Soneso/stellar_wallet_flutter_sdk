// Copyright 2026 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart'
    as wallet_sdk;

void main() {
  // Endpoint a client-domain server would expose. Only used to build the
  // request; the MockClient intercepts before any real network call happens.
  const signerUrl = 'https://client-domain.example.com/sign';

  // A representative (well-formed) base64 transaction envelope XDR. The signer
  // treats the transaction value as an opaque string, so any non-empty value
  // round-trips; this one is a real TESTNET payment envelope.
  const inputXdr =
      'AAAAAgAAAACz6ZBSkpVrW6Pg5LM2BvJ1Lf2hcUhVu6zR0vNvN5l5KAAAAAGQDXJxAAAAAEAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAEAAAAAs+mQUpKVa1uj4OSzNgbydS39oXFI'
      'Vbus0dLzbzeZeSgAAAAAAAAAAACYloAAAAAAAAAAAA==';

  // The signed envelope the client-domain server returns. Distinct from the
  // input so tests can prove the returned value comes from the response body.
  const signedXdr = 'c2lnbmVkLWVudmVsb3BlLXhkcg==';

  group('DomainSigner.signWithDomainAccount', () {
    test('200 with transaction field returns the signed XDR and posts the '
        'expected JSON body and Content-Type header', () async {
      late http.Request capturedRequest;
      late String capturedBody;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        capturedBody = request.body;
        return http.Response(
          json.encode({'transaction': signedXdr}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final signer = wallet_sdk.DomainSigner(signerUrl, httpClient: mockClient);

      final result = await signer.signWithDomainAccount(
        transactionXDR: inputXdr,
        networkPassPhrase: flutter_sdk.Network.TESTNET.networkPassphrase,
      );

      // The returned value is exactly the transaction from the response body,
      // not the input.
      expect(result, signedXdr);

      // The request is a POST to the configured URL.
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.toString(), signerUrl);

      // The body is exactly {"transaction":...,"network_passphrase":...}.
      final Map<String, dynamic> decodedBody = json.decode(capturedBody);
      expect(decodedBody.keys.toSet(),
          {'transaction', 'network_passphrase'});
      expect(decodedBody['transaction'], inputXdr);
      expect(decodedBody['network_passphrase'],
          flutter_sdk.Network.TESTNET.networkPassphrase);

      // The default Content-Type header is sent as application/json. http
      // appends a charset to the Content-Type, so match on the prefix.
      final contentType = capturedRequest.headers['content-type'];
      expect(contentType, isNotNull);
      expect(contentType, startsWith('application/json'));
    });

    test('200 response body missing the transaction field throws '
        'DomainSignerUnexpectedResponseException', () async {
      final mockClient = MockClient((request) async {
        // Valid JSON, but no "transaction" key.
        return http.Response(
          json.encode({'error': 'invalid_request'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final signer = wallet_sdk.DomainSigner(signerUrl, httpClient: mockClient);

      expect(
        () => signer.signWithDomainAccount(
          transactionXDR: inputXdr,
          networkPassPhrase: flutter_sdk.Network.TESTNET.networkPassphrase,
        ),
        throwsA(
            isA<wallet_sdk.DomainSignerUnexpectedResponseException>()),
      );
    });

    test('200 response with an explicit null transaction value throws '
        'DomainSignerUnexpectedResponseException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({'transaction': null}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final signer = wallet_sdk.DomainSigner(signerUrl, httpClient: mockClient);

      expect(
        () => signer.signWithDomainAccount(
          transactionXDR: inputXdr,
          networkPassPhrase: flutter_sdk.Network.TESTNET.networkPassphrase,
        ),
        throwsA(
            isA<wallet_sdk.DomainSignerUnexpectedResponseException>()),
      );
    });

    test('400 response throws DomainSignerUnexpectedResponseException carrying '
        'the response', () async {
      const errorBody = '{"error":"bad request"}';
      final mockClient = MockClient((request) async {
        return http.Response(errorBody, 400);
      });

      final signer = wallet_sdk.DomainSigner(signerUrl, httpClient: mockClient);

      try {
        await signer.signWithDomainAccount(
          transactionXDR: inputXdr,
          networkPassPhrase: flutter_sdk.Network.TESTNET.networkPassphrase,
        );
        fail('Expected DomainSignerUnexpectedResponseException');
      } on wallet_sdk.DomainSignerUnexpectedResponseException catch (e) {
        expect(e.response.statusCode, 400);
        expect(e.response.body, errorBody);
      }
    });

    test('500 response throws DomainSignerUnexpectedResponseException carrying '
        'the response', () async {
      const errorBody = 'internal server error';
      final mockClient = MockClient((request) async {
        return http.Response(errorBody, 500);
      });

      final signer = wallet_sdk.DomainSigner(signerUrl, httpClient: mockClient);

      try {
        await signer.signWithDomainAccount(
          transactionXDR: inputXdr,
          networkPassPhrase: flutter_sdk.Network.TESTNET.networkPassphrase,
        );
        fail('Expected DomainSignerUnexpectedResponseException');
      } on wallet_sdk.DomainSignerUnexpectedResponseException catch (e) {
        expect(e.response.statusCode, 500);
        expect(e.response.body, errorBody);
      }
    });

    test('the network passphrase sent in the body is the value supplied by the '
        'caller (PUBLIC)', () async {
      late String capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(json.encode({'transaction': signedXdr}), 200);
      });

      final signer = wallet_sdk.DomainSigner(signerUrl, httpClient: mockClient);

      await signer.signWithDomainAccount(
        transactionXDR: inputXdr,
        networkPassPhrase: flutter_sdk.Network.PUBLIC.networkPassphrase,
      );

      final Map<String, dynamic> decodedBody = json.decode(capturedBody);
      expect(decodedBody['network_passphrase'],
          flutter_sdk.Network.PUBLIC.networkPassphrase);
    });
  });

  group('DomainSigner constructor header logic', () {
    test('with no requestHeaders, Content-Type defaults to application/json '
        'and is the only header sent', () async {
      Map<String, String> capturedHeaders = {};
      final mockClient = MockClient((request) async {
        capturedHeaders = request.headers;
        return http.Response(json.encode({'transaction': signedXdr}), 200);
      });

      final signer = wallet_sdk.DomainSigner(signerUrl, httpClient: mockClient);

      // The signer stores the default Content-Type header.
      expect(signer.requestHeaders, {'Content-Type': 'application/json'});

      await signer.signWithDomainAccount(
        transactionXDR: inputXdr,
        networkPassPhrase: flutter_sdk.Network.TESTNET.networkPassphrase,
      );

      // http lowercases header names; the request carries application/json.
      expect(capturedHeaders['content-type'], startsWith('application/json'));
    });

    test('custom requestHeaders are used as given and sent on the request',
        () async {
      Map<String, String> capturedHeaders = {};
      final mockClient = MockClient((request) async {
        capturedHeaders = request.headers;
        return http.Response(json.encode({'transaction': signedXdr}), 200);
      });

      final customHeaders = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer domain-token',
        'X-Custom': 'custom-value',
      };

      final signer = wallet_sdk.DomainSigner(
        signerUrl,
        httpClient: mockClient,
        requestHeaders: customHeaders,
      );

      // The stored headers match the provided custom headers.
      expect(signer.requestHeaders, customHeaders);

      await signer.signWithDomainAccount(
        transactionXDR: inputXdr,
        networkPassPhrase: flutter_sdk.Network.TESTNET.networkPassphrase,
      );

      // Custom headers reach the wire (header names are lowercased by http).
      expect(capturedHeaders['authorization'], 'Bearer domain-token');
      expect(capturedHeaders['x-custom'], 'custom-value');
      expect(capturedHeaders['content-type'], startsWith('application/json'));
    });

    test('when custom requestHeaders are provided, Content-Type is NOT '
        'auto-added by the signer', () async {
      final mockClient = MockClient((request) async {
        return http.Response(json.encode({'transaction': signedXdr}), 200);
      });

      // Custom headers without a Content-Type entry.
      final customHeaders = <String, String>{
        'Authorization': 'Bearer domain-token',
      };

      final signer = wallet_sdk.DomainSigner(
        signerUrl,
        httpClient: mockClient,
        requestHeaders: customHeaders,
      );

      // The signer copies the provided headers verbatim and does NOT inject a
      // Content-Type. With custom headers the caller is responsible for setting
      // Content-Type explicitly.
      expect(signer.requestHeaders, {'Authorization': 'Bearer domain-token'});
      expect(signer.requestHeaders.containsKey('Content-Type'), isFalse);
    });

    test('the provided requestHeaders map is copied: mutating the original '
        'afterwards does not affect the signer', () {
      final originalHeaders = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer original',
      };

      final signer = wallet_sdk.DomainSigner(
        signerUrl,
        requestHeaders: originalHeaders,
      );

      // Mutate the caller's map after construction.
      originalHeaders['Authorization'] = 'Bearer mutated';
      originalHeaders['X-Injected'] = 'late';
      originalHeaders.remove('Content-Type');

      // The signer holds its own copy, unaffected by the post-construction
      // mutations.
      expect(signer.requestHeaders, {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer original',
      });
      expect(signer.requestHeaders.containsKey('X-Injected'), isFalse);
    });

    test('an empty requestHeaders map is honored as-is (no default '
        'Content-Type injected)', () {
      final signer = wallet_sdk.DomainSigner(
        signerUrl,
        requestHeaders: <String, String>{},
      );

      // An empty (non-null) map means custom headers were supplied, so the
      // default branch is not taken and no Content-Type is added.
      expect(signer.requestHeaders, isEmpty);
    });
  });
}