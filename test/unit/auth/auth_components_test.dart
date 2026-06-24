// Copyright 2026 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart'
    as wallet_sdk;

/// Encodes a JSON map as an unpadded base64url segment, as used in a JWT.
String _b64UrlSegment(Map<String, dynamic> claims) {
  final jsonBytes = utf8.encode(json.encode(claims));
  // JWT segments use base64url WITHOUT padding.
  return base64Url.encode(jsonBytes).replaceAll('=', '');
}

/// Builds a syntactically valid JWT string (header.payload.signature) carrying
/// the given [payload] claims. The signature segment is an opaque placeholder:
/// AuthToken only decodes the payload, it does not verify the signature.
String _buildJwt(Map<String, dynamic> payload,
    {Map<String, dynamic>? header}) {
  final headerSegment =
      _b64UrlSegment(header ?? {'alg': 'HS256', 'typ': 'JWT'});
  final payloadSegment = _b64UrlSegment(payload);
  // A real signature would be base64url of the HMAC; for decoding tests the
  // exact bytes are irrelevant, only that a third segment is present.
  const signatureSegment = 'c2lnbmF0dXJl';
  return '$headerSegment.$payloadSegment.$signatureSegment';
}

void main() {
  // Fixed Stellar account used as the JWT subject (sub) in several tests.
  const accountId =
      'GA6UIXXPEWYFILNUIWAC37Y4QPEZMQVDJHDKVWFZJ2KCWUBIU5IXZNDA';
  // A valid TESTNET secret seed and its corresponding account id, used for the
  // signer tests. These are fixed so signatures are deterministic.
  const signerSecret =
      'SBAYNYLQFXVLVAHW4BXDQYNJLMDQMZ5NQDDOHVJD3PTBAUIJRNRK5LGX';
  const signerAccountId =
      'GB4L7JUU5DENUXYH3ANTLVYQL66KQLDDJTN5SF7MWEDGWSGUA375V44V';

  group('AuthToken Tests', () {
    // exp = 2099-01-01T00:00:00Z, iat = a fixed past instant. Using a far-future
    // expiry keeps the values stable and unambiguous.
    const int expEpochSeconds = 4070908800; // 2099-01-01T00:00:00Z
    const int iatEpochSeconds = 1534257994; // 2018-08-14T14:46:34Z

    test('decodes issuer (iss), principalAccount (sub) and exp from payload',
        () {
      final jwt = _buildJwt({
        'iss': 'https://anchor.example.com/auth',
        'sub': accountId,
        'iat': iatEpochSeconds,
        'exp': expEpochSeconds,
      });

      final authToken = wallet_sdk.AuthToken(jwt);

      expect(authToken.jwt, jwt);
      expect(authToken.issuer, 'https://anchor.example.com/auth');
      expect(authToken.principalAccount, accountId);
      // expiresAt is derived from epoch 0 + exp seconds, independent of the
      // local timezone, so compare on the absolute epoch in milliseconds.
      expect(authToken.expiresAt.millisecondsSinceEpoch,
          expEpochSeconds * 1000);
    });

    test('exposes the raw decoded payload map', () {
      final jwt = _buildJwt({
        'iss': 'issuer-value',
        'sub': accountId,
        'iat': iatEpochSeconds,
        'exp': expEpochSeconds,
        'jti': 'unique-token-id',
      });

      final authToken = wallet_sdk.AuthToken(jwt);

      expect(authToken.decodedToken['iss'], 'issuer-value');
      expect(authToken.decodedToken['sub'], accountId);
      expect(authToken.decodedToken['jti'], 'unique-token-id');
      expect(authToken.decodedToken['exp'], expEpochSeconds);
    });

    test('account returns the part of sub before the first ":" separator', () {
      // A muxed/memo-style subject "account:memo" must yield only the account.
      final jwt = _buildJwt({
        'iss': 'https://anchor.example.com/auth',
        'sub': '$accountId:1234567890',
        'iat': iatEpochSeconds,
        'exp': expEpochSeconds,
      });

      final authToken = wallet_sdk.AuthToken(jwt);

      expect(authToken.principalAccount, '$accountId:1234567890');
      expect(authToken.account, accountId);
    });

    test('account equals principalAccount when sub contains no ":" separator',
        () {
      final jwt = _buildJwt({
        'iss': 'https://anchor.example.com/auth',
        'sub': accountId,
        'iat': iatEpochSeconds,
        'exp': expEpochSeconds,
      });

      final authToken = wallet_sdk.AuthToken(jwt);

      expect(authToken.account, accountId);
      expect(authToken.account, authToken.principalAccount);
    });

    test('clientDomain returns the claim value when client_domain is present',
        () {
      final jwt = _buildJwt({
        'iss': 'https://anchor.example.com/auth',
        'sub': accountId,
        'iat': iatEpochSeconds,
        'exp': expEpochSeconds,
        'client_domain': 'wallet.example.com',
      });

      final authToken = wallet_sdk.AuthToken(jwt);

      expect(authToken.clientDomain, 'wallet.example.com');
    });

    test('clientDomain returns null when the client_domain claim is absent',
        () {
      final jwt = _buildJwt({
        'iss': 'https://anchor.example.com/auth',
        'sub': accountId,
        'iat': iatEpochSeconds,
        'exp': expEpochSeconds,
      });

      final authToken = wallet_sdk.AuthToken(jwt);

      expect(authToken.clientDomain, isNull);
    });

    test('constructor throws on a malformed JWT with too few segments', () {
      // Only two segments (header.payload), missing the signature segment.
      const malformed = 'aaa.bbb';

      expect(() => wallet_sdk.AuthToken(malformed),
          throwsA(isA<FormatException>()));
    });

    test('constructor throws on a JWT whose payload is not valid base64/JSON',
        () {
      // Three segments present, but the payload segment is not decodable JSON.
      const malformed = 'aaa.!!!notbase64!!!.ccc';

      expect(() => wallet_sdk.AuthToken(malformed),
          throwsA(isA<FormatException>()));
    });

    test('constructor throws on an empty token string', () {
      expect(() => wallet_sdk.AuthToken(''),
          throwsA(isA<FormatException>()));
    });

    // A structurally valid JWT that omits a required claim must surface a
    // meaningful ValidationException, never a low-level TypeError.
    test('issuer throws ValidationException when the iss claim is missing', () {
      final jwt = _buildJwt({
        'sub': accountId,
        'iat': iatEpochSeconds,
        'exp': expEpochSeconds,
      });
      final authToken = wallet_sdk.AuthToken(jwt);

      expect(() => authToken.issuer,
          throwsA(isA<wallet_sdk.ValidationException>()));
    });

    test('principalAccount throws ValidationException when the sub claim is missing',
        () {
      final jwt = _buildJwt({
        'iss': 'https://anchor.example.com/auth',
        'iat': iatEpochSeconds,
        'exp': expEpochSeconds,
      });
      final authToken = wallet_sdk.AuthToken(jwt);

      expect(() => authToken.principalAccount,
          throwsA(isA<wallet_sdk.ValidationException>()));
    });

    test('account throws ValidationException when the sub claim is missing', () {
      final jwt = _buildJwt({
        'iss': 'https://anchor.example.com/auth',
        'iat': iatEpochSeconds,
        'exp': expEpochSeconds,
      });
      final authToken = wallet_sdk.AuthToken(jwt);

      expect(() => authToken.account,
          throwsA(isA<wallet_sdk.ValidationException>()));
    });
  });

  group('DefaultSigner Tests', () {
    late wallet_sdk.DefaultSigner signer;
    late flutter_sdk.Transaction transaction;
    late flutter_sdk.KeyPair sourceKeyPair;

    /// Builds a minimal but valid unsigned TESTNET transaction.
    flutter_sdk.Transaction buildTransaction(String sourceAccountId) {
      final account = flutter_sdk.Account(sourceAccountId, BigInt.from(1));
      final operation = flutter_sdk.PaymentOperationBuilder(
              sourceAccountId, flutter_sdk.Asset.NATIVE, '100')
          .build();
      return flutter_sdk.TransactionBuilder(account)
          .addOperation(operation)
          .build();
    }

    setUp(() {
      signer = wallet_sdk.DefaultSigner();
      sourceKeyPair = flutter_sdk.KeyPair.fromSecretSeed(signerSecret);
      transaction = buildTransaction(sourceKeyPair.accountId);
    });

    test(
        'signWithClientAccount appends a valid signature for a SigningKeyPair',
        () {
      final signingKeyPair =
          wallet_sdk.SigningKeyPair.fromSecret(signerSecret);

      expect(transaction.signatures, isEmpty);

      signer.signWithClientAccount(
          tnx: transaction,
          network: flutter_sdk.Network.TESTNET,
          account: signingKeyPair);

      expect(transaction.signatures.length, 1);

      // The appended signature must verify against the signer's public key over
      // the TESTNET transaction hash.
      final txHash = transaction.hash(flutter_sdk.Network.TESTNET);
      final rawSignature = transaction.signatures.first.signature.signature;
      final verifyKeyPair =
          flutter_sdk.KeyPair.fromAccountId(signerAccountId);
      expect(verifyKeyPair.verify(txHash, rawSignature), isTrue);
    });

    test(
        'signWithClientAccount throws ArgumentError for a PublicKeyPair '
        '(cannot sign)', () {
      final publicKeyPair = wallet_sdk.PublicKeyPair.fromAccountId(accountId);

      expect(
          () => signer.signWithClientAccount(
              tnx: transaction,
              network: flutter_sdk.Network.TESTNET,
              account: publicKeyPair),
          throwsA(isA<ArgumentError>()));

      // No signature must have been appended on the failed attempt.
      expect(transaction.signatures, isEmpty);
    });

    test('signWithDomainAccount throws UnimplementedError', () {
      expect(
          () => signer.signWithDomainAccount(
              transactionXDR: 'AAAA',
              networkPassPhrase:
                  flutter_sdk.Network.TESTNET.networkPassphrase),
          throwsA(isA<UnimplementedError>()));
    });
  });

  group('DomainSigner Tests', () {
    test('defaults Content-Type to application/json when no headers are given',
        () {
      final signer =
          wallet_sdk.DomainSigner('https://signer.example.com/sign');

      expect(signer.url, 'https://signer.example.com/sign');
      expect(signer.requestHeaders, {'Content-Type': 'application/json'});
    });

    test('copies provided request headers without the default Content-Type',
        () {
      final provided = {'Authorization': 'Bearer token-123'};
      final signer = wallet_sdk.DomainSigner(
          'https://signer.example.com/sign',
          requestHeaders: provided);

      expect(signer.requestHeaders, {'Authorization': 'Bearer token-123'});
      // When custom headers are supplied, the default Content-Type is not added.
      expect(signer.requestHeaders.containsKey('Content-Type'), isFalse);
    });

    test(
        'copies the provided headers map independently (mutating the original '
        'does not affect the signer, and vice versa)', () {
      final provided = {'Authorization': 'Bearer token-123'};
      final signer = wallet_sdk.DomainSigner(
          'https://signer.example.com/sign',
          requestHeaders: provided);

      // Mutating the original map after construction must not leak in.
      provided['X-Injected'] = 'should-not-appear';
      expect(signer.requestHeaders.containsKey('X-Injected'), isFalse);

      // Mutating the signer's map must not write back to the original.
      signer.requestHeaders['X-Added'] = 'value';
      expect(provided.containsKey('X-Added'), isFalse);
    });

    test('uses the provided http client instance', () {
      final client = http.Client();
      final signer = wallet_sdk.DomainSigner(
          'https://signer.example.com/sign',
          httpClient: client);

      expect(identical(signer.httpClient, client), isTrue);
      client.close();
    });

    test('creates a default http client when none is provided', () {
      final signer =
          wallet_sdk.DomainSigner('https://signer.example.com/sign');

      // A usable client must be created so the signer can perform requests.
      expect(signer.httpClient, isA<http.Client>());
    });

    test('is a DefaultSigner and inherits client-account signing', () {
      final signer =
          wallet_sdk.DomainSigner('https://signer.example.com/sign');
      final signingKeyPair =
          wallet_sdk.SigningKeyPair.fromSecret(signerSecret);

      final account = flutter_sdk.Account(signerAccountId, BigInt.from(1));
      final operation = flutter_sdk.PaymentOperationBuilder(
              signerAccountId, flutter_sdk.Asset.NATIVE, '100')
          .build();
      final transaction = flutter_sdk.TransactionBuilder(account)
          .addOperation(operation)
          .build();

      expect(signer, isA<wallet_sdk.DefaultSigner>());

      signer.signWithClientAccount(
          tnx: transaction,
          network: flutter_sdk.Network.TESTNET,
          account: signingKeyPair);

      expect(transaction.signatures.length, 1);
    });
  });
}
