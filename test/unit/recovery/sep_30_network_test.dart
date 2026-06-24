// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

/// Network-level tests for SEP-30 recovery (lib/src/recovery/sep_30.dart).
///
/// The recovery server HTTP is mocked by passing a package:http client into
/// `wallet.recovery(servers, httpClient: mock)`, which threads it into the base
/// SDK `SEP30RecoveryService` (a package:http consumer): this works and the
/// getAccountInfo / pre-network guard tests pass.
///
/// The Horizon path is mocked by injecting `defaultClient` into the wallet's
/// `ApplicationConfiguration`; Recovery forwards that client into
/// `flutter_sdk.StellarSDK(stellar.horizonUrl, httpClient: httpClient)`. That
/// constructor parameter is typed `Object?` and, on native/VM, is wrapped via
/// `IOClient(httpClient as HttpClient)` - i.e. it expects a dart:io HttpClient,
/// not a package:http Client. Passing the package:http `defaultClient` therefore
/// throws a TypeError before any request is made, so every replaceDeviceKey test
/// below currently fails. These are correct-behavior tests left failing on a
/// real bug; see the suspected-bugs report. The fix belongs in the wallet SDK
/// (use the `StellarSDK.httpClient` setter, which accepts a package:http Client,
/// instead of the constructor parameter), not in these tests.
///
/// A single MockClient dispatches by host: horizon-testnet.stellar.org ->
/// Horizon, recovery.example.com -> SEP-30.
const horizonHost = 'horizon-testnet.stellar.org';
const recoveryHost = 'recovery.example.com';
const recoveryEndpoint = 'https://recovery.example.com';
const recoveryAuthEndpoint = 'https://auth.example.com';

/// Builds a valid single-account Horizon JSON body with the supplied signers.
///
/// Each entry of [signers] is a (publicKey, weight) pair and is rendered as an
/// `ed25519_public_key` signer, matching the shape the base SDK
/// `AccountResponse.fromJson` / `Signer.fromJson` expects.
String horizonAccountBody(
    String accountId, List<MapEntry<String, int>> signers,
    {String sequence = '123456789012345',
    Thresholds thresholds = const Thresholds(1, 1, 1)}) {
  final base = 'https://$horizonHost/accounts/$accountId';
  return json.encode({
    '_links': {
      'self': {'href': base},
      'transactions': {'href': '$base/transactions{?cursor,limit,order}'},
      'operations': {'href': '$base/operations{?cursor,limit,order}'},
      'payments': {'href': '$base/payments{?cursor,limit,order}'},
      'effects': {'href': '$base/effects{?cursor,limit,order}'},
      'offers': {'href': '$base/offers{?cursor,limit,order}'},
      'trades': {'href': '$base/trades{?cursor,limit,order}'},
      'data': {'href': '$base/data/{key}', 'templated': true},
    },
    'id': accountId,
    'account_id': accountId,
    'sequence': sequence,
    'subentry_count': signers.length,
    'last_modified_ledger': 12345,
    'last_modified_time': '2024-01-01T00:00:00Z',
    'thresholds': {
      'low_threshold': thresholds.low,
      'med_threshold': thresholds.medium,
      'high_threshold': thresholds.high,
    },
    'flags': {
      'auth_required': false,
      'auth_revocable': false,
      'auth_immutable': false,
      'auth_clawback_enabled': false,
    },
    'balances': [
      {
        'balance': '1000.0000000',
        'buying_liabilities': '0.0000000',
        'selling_liabilities': '0.0000000',
        'asset_type': 'native',
      }
    ],
    'signers': [
      for (final s in signers)
        {
          'weight': s.value,
          'key': s.key,
          'type': 'ed25519_public_key',
        }
    ],
    'data': {},
    'num_sponsoring': 0,
    'num_sponsored': 0,
    'paging_token': accountId,
  });
}

/// Simple value holder for low/medium/high threshold weights used by the helper.
class Thresholds {
  final int low;
  final int medium;
  final int high;
  const Thresholds(this.low, this.medium, this.high);
}

/// Base64 of a deterministic 64-byte signature blob. The recovery flow only
/// base64-decodes this and wraps it in an XdrDecoratedSignature; the bytes do
/// not need to verify cryptographically, only to round-trip through base64.
String fakeRecoverySignature() {
  final bytes = Uint8List(64);
  for (var i = 0; i < 64; i++) {
    bytes[i] = (i * 3 + 7) % 256;
  }
  return base64Encode(bytes);
}

/// Resolves the Stellar account id of the ed25519 signer carried by a
/// SetOptions operation.
String signerAccountId(flutter_sdk.SetOptionsOperation op) {
  final ed = op.signer!.ed25519!;
  return flutter_sdk.KeyPair.fromPublicKey(ed.uint256).accountId;
}

Wallet walletWithClient(http.Client client) {
  return Wallet(StellarConfiguration.testNet,
      applicationConfiguration: ApplicationConfiguration(defaultClient: client));
}

Map<RecoveryServerKey, RecoveryServer> singleServer() {
  return <RecoveryServerKey, RecoveryServer>{
    RecoveryServerKey('first'): RecoveryServer(
        recoveryEndpoint, recoveryAuthEndpoint, recoveryHost),
  };
}

void main() {
  group('getAccountInfo', () {
    test('maps the recovery server account response to RecoverableAccountInfo',
        () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final signer1Kp = flutter_sdk.KeyPair.random();
      final signer2Kp = flutter_sdk.KeyPair.random();

      String? capturedPath;
      String? capturedMethod;
      String? capturedAuth;

      final client = MockClient((request) async {
        capturedPath = request.url.path;
        capturedMethod = request.method;
        capturedAuth = request.headers['Authorization'];
        expect(request.url.host, recoveryHost);
        return http.Response(
            json.encode({
              'address': accountKp.accountId,
              'identities': [
                {'role': 'owner', 'authenticated': true},
                {'role': 'sender', 'authenticated': false},
              ],
              'signers': [
                {'key': signer1Kp.accountId},
                {'key': signer2Kp.accountId},
              ],
            }),
            200);
      });

      final recovery = walletWithClient(client)
          .recovery(singleServer(), httpClient: client);

      final result = await recovery.getAccountInfo(
        PublicKeyPair(accountKp),
        {RecoveryServerKey('first'): 'jwt-token-abc'},
      );

      // Request shape.
      expect(capturedMethod, 'GET');
      expect(capturedPath, endsWith('/accounts/${accountKp.accountId}'));
      expect(capturedAuth, 'Bearer jwt-token-abc');

      // Mapping.
      expect(result.length, 1);
      final info = result[RecoveryServerKey('first')]!;
      expect(info.address, isA<PublicKeyPair>());
      expect(info.address.address, accountKp.accountId);

      expect(info.identities.length, 2);
      expect(info.identities[0].role, RecoveryRole.owner);
      expect(info.identities[0].authenticated, isTrue);
      expect(info.identities[1].role, RecoveryRole.sender);
      expect(info.identities[1].authenticated, isFalse);

      expect(info.signers.length, 2);
      expect(info.signers[0].key, isA<PublicKeyPair>());
      expect(info.signers[0].key.address, signer1Kp.accountId);
      expect(info.signers[1].key.address, signer2Kp.accountId);
      // The base SDK signer carries no `added` timestamp.
      expect(info.signers[0].added, isNull);
      expect(info.signers[1].added, isNull);
    });

    test('queries every server in the auth map and keys results by server key',
        () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final signerAKp = flutter_sdk.KeyPair.random();
      final signerBKp = flutter_sdk.KeyPair.random();

      final servers = <RecoveryServerKey, RecoveryServer>{
        RecoveryServerKey('first'): RecoveryServer(
            'https://first.example.com', recoveryAuthEndpoint, 'first.example.com'),
        RecoveryServerKey('second'): RecoveryServer(
            'https://second.example.com', recoveryAuthEndpoint, 'second.example.com'),
      };

      final client = MockClient((request) async {
        if (request.url.host == 'first.example.com') {
          return http.Response(
              json.encode({
                'address': accountKp.accountId,
                'identities': [
                  {'role': 'owner'}
                ],
                'signers': [
                  {'key': signerAKp.accountId}
                ],
              }),
              200);
        } else if (request.url.host == 'second.example.com') {
          return http.Response(
              json.encode({
                'address': accountKp.accountId,
                'identities': [
                  {'role': 'sender'}
                ],
                'signers': [
                  {'key': signerBKp.accountId}
                ],
              }),
              200);
        }
        fail('unexpected host ${request.url.host}');
      });

      final recovery =
          walletWithClient(client).recovery(servers, httpClient: client);

      final result = await recovery.getAccountInfo(
        PublicKeyPair(accountKp),
        {
          RecoveryServerKey('first'): 'jwt-first',
          RecoveryServerKey('second'): 'jwt-second',
        },
      );

      expect(result.length, 2);
      expect(result[RecoveryServerKey('first')]!.signers.single.key.address,
          signerAKp.accountId);
      expect(result[RecoveryServerKey('first')]!.identities.single.role,
          RecoveryRole.owner);
      expect(result[RecoveryServerKey('second')]!.signers.single.key.address,
          signerBKp.accountId);
      expect(result[RecoveryServerKey('second')]!.identities.single.role,
          RecoveryRole.sender);
    });

    test('throws ValidationException when the auth key is not in servers map',
        () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final client = MockClient((request) async {
        fail('no network call expected for an unknown server key');
      });

      final recovery = walletWithClient(client)
          .recovery(singleServer(), httpClient: client);

      expect(
        () => recovery.getAccountInfo(
          PublicKeyPair(accountKp),
          {RecoveryServerKey('unknown'): 'jwt'},
        ),
        throwsA(isA<ValidationException>().having(
            (e) => e.message, 'message', 'key not found in servers map')),
      );
    });

    test('wraps SEP30 server errors in RecoveryServerResponseError', () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final client = MockClient((request) async {
        return http.Response(json.encode({'error': 'Account not found'}), 404);
      });

      final recovery = walletWithClient(client)
          .recovery(singleServer(), httpClient: client);

      expect(
        () => recovery.getAccountInfo(
          PublicKeyPair(accountKp),
          {RecoveryServerKey('first'): 'jwt'},
        ),
        throwsA(isA<RecoveryServerResponseError>()),
      );
    });
  });

  group('replaceDeviceKey with explicit lostKey', () {
    test(
        'fetches the account, appends a recovery server signature and returns the signed transaction',
        () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final lostKp = flutter_sdk.KeyPair.random();
      final newKp = flutter_sdk.KeyPair.random();
      final recoverySignerKp = flutter_sdk.KeyPair.random();
      final signatureB64 = fakeRecoverySignature();

      String? horizonAccountPath;
      String? signPath;
      String? signMethod;
      String? signAuth;
      String? signedTxXdr;

      final client = MockClient((request) async {
        if (request.url.host == horizonHost) {
          horizonAccountPath = request.url.path;
          return http.Response(
              horizonAccountBody(accountKp.accountId, [
                MapEntry(accountKp.accountId, 0),
                MapEntry(lostKp.accountId, 10),
                MapEntry(recoverySignerKp.accountId, 5),
              ]),
              200);
        }
        if (request.url.host == recoveryHost) {
          signPath = request.url.path;
          signMethod = request.method;
          signAuth = request.headers['Authorization'];
          signedTxXdr = json.decode(request.body)['transaction'];
          return http.Response(
              json.encode({
                'signature': signatureB64,
                'network_passphrase': 'Test SDF Network ; September 2015',
              }),
              200);
        }
        fail('unexpected host ${request.url.host}');
      });

      final recovery = walletWithClient(client)
          .recovery(singleServer(), httpClient: client);

      final tx = await recovery.replaceDeviceKey(
        PublicKeyPair(accountKp),
        PublicKeyPair(newKp),
        {
          RecoveryServerKey('first'):
              RecoveryServerSigning(recoverySignerKp.accountId, 'jwt-sign'),
        },
        lostKey: PublicKeyPair(lostKp),
      );

      // Horizon was queried for the target account.
      expect(horizonAccountPath, endsWith('/accounts/${accountKp.accountId}'));

      // The recovery server sign endpoint was hit with the right path/auth.
      expect(signMethod, 'POST');
      expect(
          signPath,
          endsWith(
              '/accounts/${accountKp.accountId}/sign/${recoverySignerKp.accountId}'));
      expect(signAuth, 'Bearer jwt-sign');

      // The transaction sent to the recovery server contains the two SetOptions
      // operations (remove lost key, add new key).
      expect(signedTxXdr, isNotNull);
      final sentTx = flutter_sdk.AbstractTransaction.fromEnvelopeXdrString(
          signedTxXdr!) as flutter_sdk.Transaction;
      expect(sentTx.operations.length, 2);
      expect(sentTx.operations[0], isA<flutter_sdk.SetOptionsOperation>());
      expect(sentTx.operations[1], isA<flutter_sdk.SetOptionsOperation>());

      // The returned transaction carries the appended recovery signature.
      expect(tx.signatures.length, 1);
      final appended = tx.signatures.first;
      expect(appended.signature.signature, base64Decode(signatureB64));
      expect(appended.hint.signatureHint,
          recoverySignerKp.signatureHint.signatureHint);
    });

    test('removes the lost signer and adds the new signer with the lost weight',
        () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final lostKp = flutter_sdk.KeyPair.random();
      final newKp = flutter_sdk.KeyPair.random();
      final recoverySignerKp = flutter_sdk.KeyPair.random();

      String? signedTxXdr;
      final client = MockClient((request) async {
        if (request.url.host == horizonHost) {
          return http.Response(
              horizonAccountBody(accountKp.accountId, [
                MapEntry(lostKp.accountId, 17),
                MapEntry(recoverySignerKp.accountId, 5),
              ]),
              200);
        }
        signedTxXdr = json.decode(request.body)['transaction'];
        return http.Response(
            json.encode({
              'signature': fakeRecoverySignature(),
              'network_passphrase': 'Test SDF Network ; September 2015',
            }),
            200);
      });

      final recovery = walletWithClient(client)
          .recovery(singleServer(), httpClient: client);

      await recovery.replaceDeviceKey(
        PublicKeyPair(accountKp),
        PublicKeyPair(newKp),
        {
          RecoveryServerKey('first'):
              RecoveryServerSigning(recoverySignerKp.accountId, 'jwt'),
        },
        lostKey: PublicKeyPair(lostKp),
      );

      final sentTx = flutter_sdk.AbstractTransaction.fromEnvelopeXdrString(
          signedTxXdr!) as flutter_sdk.Transaction;
      final removeOp = sentTx.operations[0] as flutter_sdk.SetOptionsOperation;
      final addOp = sentTx.operations[1] as flutter_sdk.SetOptionsOperation;

      // First op removes the lost key (weight 0), second adds the new key with
      // the weight the lost key had on the account (17).
      expect(removeOp.signer, isNotNull);
      expect(removeOp.signerWeight, 0);
      expect(signerAccountId(removeOp), lostKp.accountId);

      expect(addOp.signerWeight, 17);
      expect(signerAccountId(addOp), newKp.accountId);
    });

    test('throws ValidationException when the lost key is not a signer',
        () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final lostKp = flutter_sdk.KeyPair.random();
      final newKp = flutter_sdk.KeyPair.random();
      final recoverySignerKp = flutter_sdk.KeyPair.random();

      final client = MockClient((request) async {
        if (request.url.host == horizonHost) {
          // The lost key is intentionally absent from the signer list.
          return http.Response(
              horizonAccountBody(accountKp.accountId, [
                MapEntry(accountKp.accountId, 1),
                MapEntry(recoverySignerKp.accountId, 5),
              ]),
              200);
        }
        fail('recovery server must not be contacted when validation fails');
      });

      final recovery = walletWithClient(client)
          .recovery(singleServer(), httpClient: client);

      expect(
        () => recovery.replaceDeviceKey(
          PublicKeyPair(accountKp),
          PublicKeyPair(newKp),
          {
            RecoveryServerKey('first'):
                RecoveryServerSigning(recoverySignerKp.accountId, 'jwt'),
          },
          lostKey: PublicKeyPair(lostKp),
        ),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message',
            "Lost key doesn't belong to the account")),
      );
    });

    test('maps a Horizon 404 to ValidationException "Account doesn\'t exist"',
        () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final lostKp = flutter_sdk.KeyPair.random();
      final newKp = flutter_sdk.KeyPair.random();
      final recoverySignerKp = flutter_sdk.KeyPair.random();

      final client = MockClient((request) async {
        if (request.url.host == horizonHost) {
          return http.Response(
              json.encode({
                'type': 'https://stellar.org/horizon-errors/not_found',
                'title': 'Resource Missing',
                'status': 404,
              }),
              404);
        }
        fail('recovery server must not be contacted when the account is missing');
      });

      final recovery = walletWithClient(client)
          .recovery(singleServer(), httpClient: client);

      expect(
        () => recovery.replaceDeviceKey(
          PublicKeyPair(accountKp),
          PublicKeyPair(newKp),
          {
            RecoveryServerKey('first'):
                RecoveryServerSigning(recoverySignerKp.accountId, 'jwt'),
          },
          lostKey: PublicKeyPair(lostKp),
        ),
        throwsA(isA<ValidationException>().having(
            (e) => e.message, 'message', "Account doesn't exist")),
      );
    });

    test('maps a non-404 Horizon error to HorizonRequestFailedException',
        () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final lostKp = flutter_sdk.KeyPair.random();
      final newKp = flutter_sdk.KeyPair.random();
      final recoverySignerKp = flutter_sdk.KeyPair.random();

      final client = MockClient((request) async {
        if (request.url.host == horizonHost) {
          return http.Response(
              json.encode({
                'type': 'https://stellar.org/horizon-errors/server_error',
                'title': 'Internal Server Error',
                'status': 500,
              }),
              500);
        }
        fail('recovery server must not be contacted on a Horizon failure');
      });

      final recovery = walletWithClient(client)
          .recovery(singleServer(), httpClient: client);

      expect(
        () => recovery.replaceDeviceKey(
          PublicKeyPair(accountKp),
          PublicKeyPair(newKp),
          {
            RecoveryServerKey('first'):
                RecoveryServerSigning(recoverySignerKp.accountId, 'jwt'),
          },
          lostKey: PublicKeyPair(lostKp),
        ),
        throwsA(isA<HorizonRequestFailedException>()),
      );
    });
  });

  group('replaceDeviceKey with deduced lost key (_deduceKey)', () {
    test('uses the single non-recovery signer when exactly one is present',
        () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final deviceKp = flutter_sdk.KeyPair.random();
      final newKp = flutter_sdk.KeyPair.random();
      final recoverySignerKp = flutter_sdk.KeyPair.random();

      String? signedTxXdr;
      final client = MockClient((request) async {
        if (request.url.host == horizonHost) {
          // master key weight 0 (ignored), one recovery signer, exactly one
          // non-recovery device signer.
          return http.Response(
              horizonAccountBody(accountKp.accountId, [
                MapEntry(accountKp.accountId, 0),
                MapEntry(recoverySignerKp.accountId, 5),
                MapEntry(deviceKp.accountId, 10),
              ]),
              200);
        }
        signedTxXdr = json.decode(request.body)['transaction'];
        return http.Response(
            json.encode({
              'signature': fakeRecoverySignature(),
              'network_passphrase': 'Test SDF Network ; September 2015',
            }),
            200);
      });

      final recovery = walletWithClient(client)
          .recovery(singleServer(), httpClient: client);

      await recovery.replaceDeviceKey(
        PublicKeyPair(accountKp),
        PublicKeyPair(newKp),
        {
          RecoveryServerKey('first'):
              RecoveryServerSigning(recoverySignerKp.accountId, 'jwt'),
        },
      );

      // The deduced lost key is the single non-recovery signer (deviceKp).
      final sentTx = flutter_sdk.AbstractTransaction.fromEnvelopeXdrString(
          signedTxXdr!) as flutter_sdk.Transaction;
      final removeOp = sentTx.operations[0] as flutter_sdk.SetOptionsOperation;
      final addOp = sentTx.operations[1] as flutter_sdk.SetOptionsOperation;
      expect(removeOp.signerWeight, 0);
      expect(signerAccountId(removeOp), deviceKp.accountId);
      // The new key inherits the deduced key's weight (10).
      expect(addOp.signerWeight, 10);
    });

    test(
        'throws ValidationException when no non-recovery signer can be deduced',
        () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final newKp = flutter_sdk.KeyPair.random();
      final recoverySignerKp = flutter_sdk.KeyPair.random();

      final client = MockClient((request) async {
        if (request.url.host == horizonHost) {
          // Only the (weight 0) master key and the recovery signer: no device
          // key candidate.
          return http.Response(
              horizonAccountBody(accountKp.accountId, [
                MapEntry(accountKp.accountId, 0),
                MapEntry(recoverySignerKp.accountId, 5),
              ]),
              200);
        }
        fail('recovery server must not be contacted when deduction fails');
      });

      final recovery = walletWithClient(client)
          .recovery(singleServer(), httpClient: client);

      expect(
        () => recovery.replaceDeviceKey(
          PublicKeyPair(accountKp),
          PublicKeyPair(newKp),
          {
            RecoveryServerKey('first'):
                RecoveryServerSigning(recoverySignerKp.accountId, 'jwt'),
          },
        ),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message',
            'No device key is setup for this account')),
      );
    });

    test(
        'with multiple non-recovery signers and uniform recovery weight, picks the one with a differing weight',
        () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final deviceKp = flutter_sdk.KeyPair.random();
      final otherKp = flutter_sdk.KeyPair.random();
      final newKp = flutter_sdk.KeyPair.random();
      final recoverySigner1Kp = flutter_sdk.KeyPair.random();
      final recoverySigner2Kp = flutter_sdk.KeyPair.random();

      final servers = <RecoveryServerKey, RecoveryServer>{
        RecoveryServerKey('first'): RecoveryServer(
            recoveryEndpoint, recoveryAuthEndpoint, recoveryHost),
        RecoveryServerKey('second'): RecoveryServer(
            recoveryEndpoint, recoveryAuthEndpoint, recoveryHost),
      };

      String? signedTxXdr;
      final client = MockClient((request) async {
        if (request.url.host == horizonHost) {
          // Two recovery signers both weight 5 (uniform). Two non-recovery
          // signers: otherKp at 5 (same as recovery weight), deviceKp at 10
          // (the only differing weight) -> deviceKp is the device key.
          return http.Response(
              horizonAccountBody(accountKp.accountId, [
                MapEntry(recoverySigner1Kp.accountId, 5),
                MapEntry(recoverySigner2Kp.accountId, 5),
                MapEntry(otherKp.accountId, 5),
                MapEntry(deviceKp.accountId, 10),
              ]),
              200);
        }
        signedTxXdr = json.decode(request.body)['transaction'];
        return http.Response(
            json.encode({
              'signature': fakeRecoverySignature(),
              'network_passphrase': 'Test SDF Network ; September 2015',
            }),
            200);
      });

      final recovery =
          walletWithClient(client).recovery(servers, httpClient: client);

      await recovery.replaceDeviceKey(
        PublicKeyPair(accountKp),
        PublicKeyPair(newKp),
        {
          RecoveryServerKey('first'):
              RecoveryServerSigning(recoverySigner1Kp.accountId, 'jwt1'),
          RecoveryServerKey('second'):
              RecoveryServerSigning(recoverySigner2Kp.accountId, 'jwt2'),
        },
      );

      final sentTx = flutter_sdk.AbstractTransaction.fromEnvelopeXdrString(
          signedTxXdr!) as flutter_sdk.Transaction;
      final removeOp = sentTx.operations[0] as flutter_sdk.SetOptionsOperation;
      final addOp = sentTx.operations[1] as flutter_sdk.SetOptionsOperation;
      expect(signerAccountId(removeOp), deviceKp.accountId);
      expect(addOp.signerWeight, 10);
    });

    test(
        'throws ValidationException when recovery signers have ambiguous (differing) weights',
        () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final deviceKp = flutter_sdk.KeyPair.random();
      final otherKp = flutter_sdk.KeyPair.random();
      final newKp = flutter_sdk.KeyPair.random();
      final recoverySigner1Kp = flutter_sdk.KeyPair.random();
      final recoverySigner2Kp = flutter_sdk.KeyPair.random();

      final servers = <RecoveryServerKey, RecoveryServer>{
        RecoveryServerKey('first'): RecoveryServer(
            recoveryEndpoint, recoveryAuthEndpoint, recoveryHost),
        RecoveryServerKey('second'): RecoveryServer(
            recoveryEndpoint, recoveryAuthEndpoint, recoveryHost),
      };

      final client = MockClient((request) async {
        if (request.url.host == horizonHost) {
          // Two non-recovery signers (>1) but the recovery signers have two
          // distinct weights (3 and 7), so the grouping is ambiguous.
          return http.Response(
              horizonAccountBody(accountKp.accountId, [
                MapEntry(recoverySigner1Kp.accountId, 3),
                MapEntry(recoverySigner2Kp.accountId, 7),
                MapEntry(otherKp.accountId, 5),
                MapEntry(deviceKp.accountId, 10),
              ]),
              200);
        }
        fail('recovery server must not be contacted when deduction is ambiguous');
      });

      final recovery =
          walletWithClient(client).recovery(servers, httpClient: client);

      expect(
        () => recovery.replaceDeviceKey(
          PublicKeyPair(accountKp),
          PublicKeyPair(newKp),
          {
            RecoveryServerKey('first'):
                RecoveryServerSigning(recoverySigner1Kp.accountId, 'jwt1'),
            RecoveryServerKey('second'):
                RecoveryServerSigning(recoverySigner2Kp.accountId, 'jwt2'),
          },
        ),
        throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            "Couldn't deduce lost key. Please provide lost key explicitly")),
      );
    });

    test(
        'throws ValidationException when more than one non-recovery signer differs from the recovery weight',
        () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final deviceKp = flutter_sdk.KeyPair.random();
      final otherKp = flutter_sdk.KeyPair.random();
      final newKp = flutter_sdk.KeyPair.random();
      final recoverySigner1Kp = flutter_sdk.KeyPair.random();
      final recoverySigner2Kp = flutter_sdk.KeyPair.random();

      final servers = <RecoveryServerKey, RecoveryServer>{
        RecoveryServerKey('first'): RecoveryServer(
            recoveryEndpoint, recoveryAuthEndpoint, recoveryHost),
        RecoveryServerKey('second'): RecoveryServer(
            recoveryEndpoint, recoveryAuthEndpoint, recoveryHost),
      };

      final client = MockClient((request) async {
        if (request.url.host == horizonHost) {
          // Uniform recovery weight 5, but two non-recovery signers both differ
          // from it (10 and 20) -> cannot disambiguate.
          return http.Response(
              horizonAccountBody(accountKp.accountId, [
                MapEntry(recoverySigner1Kp.accountId, 5),
                MapEntry(recoverySigner2Kp.accountId, 5),
                MapEntry(otherKp.accountId, 20),
                MapEntry(deviceKp.accountId, 10),
              ]),
              200);
        }
        fail('recovery server must not be contacted when deduction is ambiguous');
      });

      final recovery =
          walletWithClient(client).recovery(servers, httpClient: client);

      expect(
        () => recovery.replaceDeviceKey(
          PublicKeyPair(accountKp),
          PublicKeyPair(newKp),
          {
            RecoveryServerKey('first'):
                RecoveryServerSigning(recoverySigner1Kp.accountId, 'jwt1'),
            RecoveryServerKey('second'):
                RecoveryServerSigning(recoverySigner2Kp.accountId, 'jwt2'),
          },
        ),
        throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            "Couldn't deduce lost key. Please provide lost key explicitly")),
      );
    });
  });

  group('createRecoverableWallet pre-network guard', () {
    test('throws ValidationException when device address equals account address',
        () async {
      final client = MockClient((request) async {
        fail('no network call expected before the device/account guard');
      });

      final recovery = walletWithClient(client)
          .recovery(singleServer(), httpClient: client);

      final shared =
          PublicKeyPair(flutter_sdk.KeyPair.fromAccountId(
              flutter_sdk.KeyPair.random().accountId));

      final config = RecoverableWalletConfig(
        shared,
        shared,
        AccountThreshold(10, 10, 10),
        <RecoveryServerKey, List<RecoveryAccountIdentity>>{},
        SignerWeight(10, 5),
      );

      expect(
        () => recovery.createRecoverableWallet(config),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message',
            'Device key must be different from master (account) key')),
      );
    });
  });
}
