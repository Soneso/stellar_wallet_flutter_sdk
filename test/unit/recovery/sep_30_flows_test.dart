// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

/// Flow-level tests for SEP-30 recovery (lib/src/recovery/sep_30.dart) that are
/// not covered by sep_30_network_test.dart (replaceDeviceKey / _deduceKey) or
/// sep_30_test.dart (pure value-object conversions).
///
/// All recovery objects are created through
/// `wallet.recovery(servers, httpClient: mock)`. The single MockClient serves
/// every endpoint the flows reach: the SEP-30 recovery servers, the
/// `.well-known/stellar.toml` of each server's home domain, the SEP-10 web auth
/// endpoint (GET challenge / POST token), and Horizon `/accounts/<id>`. Routing
/// is by `request.url.host` / path / method.
///
/// The recovery flow forwards the same client into the Horizon `StellarSDK` via
/// the `httpClient` setter (the seam on this branch), so Horizon lookups also go
/// through the mock without throwing.
const horizonHost = 'horizon-testnet.stellar.org';

const recoveryHost = 'recovery.example.com';
const recoveryEndpoint = 'https://recovery.example.com';

// The SEP-10 home domain for the recovery server. The recovery server's SEP-10
// home domain and its toml domain are the same value (`RecoveryServer.homeDomain`).
const homeDomain = 'recovery.example.com';

// The SEP-10 web auth endpoint. Its host is used as the `web_auth_domain` value
// in the challenge, and it must equal `RecoveryServer.authEndpoint`.
const authEndpoint = 'https://auth.example.com/auth';
const authHost = 'auth.example.com';

// Server signing key (the SEP-10 SIGNING_KEY advertised in the toml and used to
// pre-sign the challenge).
const serverSecretSeed =
    'SAWDHXQG6ROJSU4QGCW7NSTYFHPTPIVC2NC7QKVTO7PZCSO2WEBGM54W';
const serverAccountId =
    'GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP';

// A JWT whose `sub` is a Stellar address; the wallet SDK decodes it for the
// AuthToken, so it must be a well-formed JWT.
const successJWTToken =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJHQTZVSVhYUEVXWUZJTE5VSVdBQzM3WTRRUEVaTVFWREpIREtWV0ZaSjJLQ1dVQklVNUlYWk5EQSIsImp0aSI6IjE0NGQzNjdiY2IwZTcyY2FiZmRiZGU2MGVhZTBhZDczM2NjNjVkMmE2NTg3MDgzZGFiM2Q2MTZmODg1MTkwMjQiLCJpc3MiOiJodHRwczovL2ZsYXBweS1iaXJkLWRhcHAuZmlyZWJhc2VhcHAuY29tLyIsImlhdCI6MTUzNDI1Nzk5NCwiZXhwIjoxNTM0MzQ0Mzk0fQ.8nbB83Z6vGBgC1X9r3N6oQCFTBzDiITAfCJasRft0z0';

final serverKeyPair = flutter_sdk.KeyPair.fromSecretSeed(serverSecretSeed);
final Random _random = Random.secure();

/// A valid stellar.toml advertising the SEP-10 web auth endpoint and signing
/// key, served at the recovery server's home domain.
String validToml(
    {String webAuthEndpoint = authEndpoint, String? signingKey}) {
  final keyLine =
      signingKey == null ? '' : 'SIGNING_KEY="$signingKey"\n';
  return '''
VERSION="2.0.0"
NETWORK_PASSPHRASE="Test SDF Network ; September 2015"
WEB_AUTH_ENDPOINT="$webAuthEndpoint"
$keyLine''';
}

Uint8List generateNonce([int length = 48]) {
  final values = List<int>.generate(length, (i) => _random.nextInt(256));
  return Uint8List.fromList(base64Url.encode(values).codeUnits);
}

flutter_sdk.TransactionPreconditions validTimeBounds() {
  final result = flutter_sdk.TransactionPreconditions();
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  result.timeBounds = flutter_sdk.TimeBounds(now - 1, now + 300);
  return result;
}

/// Builds the SEP-10 challenge GET response body (a server-signed,
/// sequence-0 transaction with the two expected ManageData operations).
String challengeResponse(String userAccountId) {
  final muxed = flutter_sdk.MuxedAccount.fromAccountId(userAccountId)!;
  final firstOp = flutter_sdk.ManageDataOperationBuilder(
          '$homeDomain auth', generateNonce())
      .setMuxedSourceAccount(muxed)
      .build();
  final secondOp = flutter_sdk.ManageDataOperationBuilder(
          'web_auth_domain', Uint8List.fromList(authHost.codeUnits))
      .setSourceAccount(serverAccountId)
      .build();

  final transactionAccount =
      flutter_sdk.Account(serverAccountId, BigInt.from(-1));
  final tx = flutter_sdk.TransactionBuilder(transactionAccount)
      .addOperation(firstOp)
      .addOperation(secondOp)
      .addMemo(flutter_sdk.Memo.none())
      .addPreconditions(validTimeBounds())
      .build();
  tx.sign(serverKeyPair, flutter_sdk.Network.TESTNET);
  return json.encode({'transaction': tx.toEnvelopeXdrBase64()});
}

/// Verifies the POSTed challenge carries the user signature, returning the JWT
/// on success (mirrors a SEP-10 web auth token endpoint).
http.Response tokenResponse(String body, String userAccountId) {
  final envelopeXdr = flutter_sdk.XdrTransactionEnvelope.fromEnvelopeXdrString(
      json.decode(body)['transaction']);
  final signatures = envelopeXdr.v1!.signatures;
  if (signatures.length == 2) {
    final userSignature = signatures[1];
    final userKeyPair = flutter_sdk.KeyPair.fromAccountId(userAccountId);
    final transactionHash = flutter_sdk.AbstractTransaction.fromEnvelopeXdr(
            envelopeXdr)
        .hash(flutter_sdk.Network.TESTNET);
    final valid = userKeyPair.verify(
        transactionHash, userSignature.signature.signature);
    if (valid) {
      return http.Response(json.encode({'token': successJWTToken}), 200);
    }
  }
  return http.Response(json.encode({'error': 'Bad request'}), 400);
}

/// Builds a valid single-account Horizon JSON body with the supplied signers.
/// Each entry is a (publicKey, weight) pair rendered as an ed25519 signer,
/// matching the shape `AccountResponse.fromJson` expects.
String horizonAccountBody(
    String accountId, List<MapEntry<String, int>> signers) {
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
    'sequence': '123456789012345',
    'subentry_count': signers.length,
    'last_modified_ledger': 12345,
    'last_modified_time': '2024-01-01T00:00:00Z',
    'thresholds': {
      'low_threshold': 1,
      'med_threshold': 1,
      'high_threshold': 1,
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

/// Resolves the Stellar account id of the ed25519 signer carried by a
/// SetOptions operation.
String signerAccountId(flutter_sdk.SetOptionsOperation op) {
  final ed = op.signer!.ed25519!;
  return flutter_sdk.KeyPair.fromPublicKey(ed.uint256).accountId;
}

Wallet walletWithClient(http.Client client) {
  return Wallet(StellarConfiguration.testNet,
      applicationConfiguration:
          ApplicationConfiguration(defaultClient: client));
}

Map<RecoveryServerKey, RecoveryServer> singleServer() {
  return <RecoveryServerKey, RecoveryServer>{
    RecoveryServerKey('first'):
        RecoveryServer(recoveryEndpoint, authEndpoint, homeDomain),
  };
}

void main() {
  group('createRecoverableWallet pre-network guard', () {
    test(
        'throws ValidationException when device address equals account address',
        () async {
      final client = MockClient((request) async {
        fail('no network call expected before the device/account guard');
      });

      final recovery =
          walletWithClient(client).recovery(singleServer(), httpClient: client);

      final accountId = flutter_sdk.KeyPair.random().accountId;
      final account = PublicKeyPair(flutter_sdk.KeyPair.fromAccountId(accountId));
      // A distinct PublicKeyPair instance carrying the same address: the guard
      // must compare by address, not by object identity.
      final device = PublicKeyPair(flutter_sdk.KeyPair.fromAccountId(accountId));

      final config = RecoverableWalletConfig(
        account,
        device,
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

  group('createRecoverableWallet happy path', () {
    test(
        'enrolls with the recovery server, builds the registration transaction '
        'and returns the recovery signer', () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final accountSecret = accountKp.secretSeed;
      final deviceKp = flutter_sdk.KeyPair.random();
      final recoverySignerKp = flutter_sdk.KeyPair.random();

      String? registerPath;
      String? registerMethod;
      String? registerAuth;
      Map<String, dynamic>? registerBody;

      final client = MockClient((request) async {
        final url = request.url;
        // 1. stellar.toml lookup for the SEP-10 home domain.
        if (url.host == homeDomain && url.path.contains('stellar.toml')) {
          return http.Response(validToml(signingKey: serverAccountId), 200);
        }
        // 2. SEP-10 challenge (GET) and token (POST) endpoint.
        if (url.host == authHost) {
          if (request.method == 'GET') {
            return http.Response(challengeResponse(accountKp.accountId), 200);
          }
          if (request.method == 'POST') {
            return tokenResponse(request.body, accountKp.accountId);
          }
        }
        // 3. SEP-30 register account (POST accounts/<address>).
        if (url.host == recoveryHost && request.method == 'POST') {
          registerPath = url.path;
          registerMethod = request.method;
          registerAuth = request.headers['Authorization'];
          registerBody = json.decode(request.body) as Map<String, dynamic>;
          return http.Response(
              json.encode({
                'address': accountKp.accountId,
                'identities': [
                  {'role': 'owner', 'authenticated': false}
                ],
                'signers': [
                  {'key': recoverySignerKp.accountId}
                ],
              }),
              200);
        }
        // 4. Horizon account lookup for the registration transaction source.
        if (url.host == horizonHost) {
          return http.Response(
              horizonAccountBody(accountKp.accountId, [
                MapEntry(accountKp.accountId, 1),
              ]),
              200);
        }
        fail('unexpected request ${request.method} $url');
      });

      final recovery =
          walletWithClient(client).recovery(singleServer(), httpClient: client);

      final config = RecoverableWalletConfig(
        SigningKeyPair.fromSecret(accountSecret),
        PublicKeyPair(deviceKp),
        AccountThreshold(10, 10, 10),
        {
          RecoveryServerKey('first'): [
            RecoveryAccountIdentity(RecoveryRole.owner, [
              RecoveryAccountAuthMethod(
                  RecoveryType.email, 'owner@example.com'),
            ]),
          ],
        },
        SignerWeight(20, 7),
      );

      final wallet = await recovery.createRecoverableWallet(config);

      // The recovery signer returned by the server is surfaced verbatim.
      expect(wallet.signers, [recoverySignerKp.accountId]);

      // The register call hit the SEP-30 endpoint authenticated with the JWT.
      expect(registerMethod, 'POST');
      expect(registerPath, endsWith('/accounts/${accountKp.accountId}'));
      expect(registerAuth, 'Bearer $successJWTToken');

      // The register body carried the configured identity / auth method.
      expect(registerBody, isNotNull);
      final identities = registerBody!['identities'] as List;
      expect(identities.length, 1);
      expect(identities.first['role'], 'owner');
      final methods = identities.first['auth_methods'] as List;
      expect(methods.length, 1);
      expect(methods.first['type'], 'email');
      expect(methods.first['value'], 'owner@example.com');

      // The transaction sets the master key weight to 0, then adds the recovery
      // signer (weight 7), the device key (weight 20), and the thresholds.
      final tx = wallet.transaction;
      final ops = tx.operations.whereType<flutter_sdk.SetOptionsOperation>()
          .toList();
      // master-weight op + recovery signer + device signer + thresholds op.
      expect(ops.length, 4);

      final masterOp = ops.first;
      expect(masterOp.masterKeyWeight, 0);

      final signerOps = ops
          .where((o) => o.signer != null)
          .toList();
      expect(signerOps.length, 2);

      final recoverySignerOp = signerOps.firstWhere(
          (o) => signerAccountId(o) == recoverySignerKp.accountId);
      expect(recoverySignerOp.signerWeight, 7);

      final deviceSignerOp = signerOps
          .firstWhere((o) => signerAccountId(o) == deviceKp.accountId);
      expect(deviceSignerOp.signerWeight, 20);

      final thresholdOp = ops.firstWhere((o) => o.lowThreshold != null);
      expect(thresholdOp.lowThreshold, 10);
      expect(thresholdOp.mediumThreshold, 10);
      expect(thresholdOp.highThreshold, 10);
    });

    test(
        'throws ValidationException when no identity is configured for a server',
        () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final deviceKp = flutter_sdk.KeyPair.random();

      final client = MockClient((request) async {
        fail('no network call expected when an identity entry is missing');
      });

      final recovery =
          walletWithClient(client).recovery(singleServer(), httpClient: client);

      // No identity map entry for the 'first' server key.
      final config = RecoverableWalletConfig(
        SigningKeyPair.fromSecret(accountKp.secretSeed),
        PublicKeyPair(deviceKp),
        AccountThreshold(10, 10, 10),
        <RecoveryServerKey, List<RecoveryAccountIdentity>>{},
        SignerWeight(20, 7),
      );

      expect(
        () => recovery.createRecoverableWallet(config),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message',
            'Account identity for server first was not specified')),
      );
    });
  });

  group('getAccountInfo', () {
    test('maps each server response to RecoverableAccountInfo by server key',
        () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final signer1Kp = flutter_sdk.KeyPair.random();
      final signer2Kp = flutter_sdk.KeyPair.random();

      String? capturedPath;
      String? capturedMethod;
      String? capturedAuth;

      final client = MockClient((request) async {
        expect(request.url.host, recoveryHost);
        capturedPath = request.url.path;
        capturedMethod = request.method;
        capturedAuth = request.headers['Authorization'];
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

      final recovery =
          walletWithClient(client).recovery(singleServer(), httpClient: client);

      final result = await recovery.getAccountInfo(
        PublicKeyPair(accountKp),
        {RecoveryServerKey('first'): 'jwt-token-abc'},
      );

      expect(capturedMethod, 'GET');
      expect(capturedPath, endsWith('/accounts/${accountKp.accountId}'));
      expect(capturedAuth, 'Bearer jwt-token-abc');

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
      expect(info.signers[0].key.address, signer1Kp.accountId);
      expect(info.signers[1].key.address, signer2Kp.accountId);
      // The base SDK signer response carries no `added` timestamp.
      expect(info.signers[0].added, isNull);
      expect(info.signers[1].added, isNull);
    });

    test('throws ValidationException when an auth key is not in the servers map',
        () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final client = MockClient((request) async {
        fail('no network call expected for an unknown server key');
      });

      final recovery =
          walletWithClient(client).recovery(singleServer(), httpClient: client);

      expect(
        () => recovery.getAccountInfo(
          PublicKeyPair(accountKp),
          {RecoveryServerKey('unknown'): 'jwt'},
        ),
        throwsA(isA<ValidationException>().having(
            (e) => e.message, 'message', 'key not found in servers map')),
      );
    });
  });

  group('sep10Auth', () {
    test('returns a Sep10 configured from the server toml on success',
        () async {
      final client = MockClient((request) async {
        if (request.url.host == homeDomain &&
            request.url.path.contains('stellar.toml')) {
          return http.Response(validToml(signingKey: serverAccountId), 200);
        }
        fail('only the toml lookup is expected for sep10Auth success');
      });

      final recovery =
          walletWithClient(client).recovery(singleServer(), httpClient: client);

      final sep10 = await recovery.sep10Auth(RecoveryServerKey('first'));

      expect(sep10, isA<Sep10>());
      expect(sep10.serverHomeDomain, homeDomain);
      expect(sep10.serverAuthEndpoint, authEndpoint);
      expect(sep10.serverSigningKey, serverAccountId);
    });

    test('throws Sep10AuthNotSupported when the toml has no signing key',
        () async {
      final client = MockClient((request) async {
        if (request.url.host == homeDomain &&
            request.url.path.contains('stellar.toml')) {
          // No SIGNING_KEY line.
          return http.Response(validToml(), 200);
        }
        fail('only the toml lookup is expected');
      });

      final recovery =
          walletWithClient(client).recovery(singleServer(), httpClient: client);

      expect(
        () => recovery.sep10Auth(RecoveryServerKey('first')),
        throwsA(isA<Sep10AuthNotSupported>().having((e) => e.message, 'message',
            'Server signing key not found')),
      );
    });

    test('throws Sep10AuthNotSupported when the toml has no web auth endpoint',
        () async {
      final client = MockClient((request) async {
        if (request.url.host == homeDomain &&
            request.url.path.contains('stellar.toml')) {
          return http.Response('''
VERSION="2.0.0"
NETWORK_PASSPHRASE="Test SDF Network ; September 2015"
SIGNING_KEY="$serverAccountId"
''', 200);
        }
        fail('only the toml lookup is expected');
      });

      final recovery =
          walletWithClient(client).recovery(singleServer(), httpClient: client);

      expect(
        () => recovery.sep10Auth(RecoveryServerKey('first')),
        throwsA(isA<Sep10AuthNotSupported>().having((e) => e.message, 'message',
            'Server has no sep 10 web auth endpoint')),
      );
    });

    test(
        'throws Sep10AuthNotSupported when the toml web auth endpoint does not '
        'match the configured auth endpoint', () async {
      final client = MockClient((request) async {
        if (request.url.host == homeDomain &&
            request.url.path.contains('stellar.toml')) {
          // A different endpoint than the server's configured authEndpoint.
          return http.Response(
              validToml(
                  webAuthEndpoint: 'https://other.example.com/auth',
                  signingKey: serverAccountId),
              200);
        }
        fail('only the toml lookup is expected');
      });

      final recovery =
          walletWithClient(client).recovery(singleServer(), httpClient: client);

      expect(
        () => recovery.sep10Auth(RecoveryServerKey('first')),
        throwsA(isA<Sep10AuthNotSupported>().having((e) => e.message, 'message',
            'Invalid auth endpoint, not equal to sep 10 web auth endpoint')),
      );
    });

    test('throws ValidationException when the server key is not in the map',
        () async {
      final client = MockClient((request) async {
        fail('no toml lookup expected for an unknown server key');
      });

      final recovery =
          walletWithClient(client).recovery(singleServer(), httpClient: client);

      expect(
        () => recovery.sep10Auth(RecoveryServerKey('missing')),
        throwsA(isA<ValidationException>().having(
            (e) => e.message, 'message', 'key not found in servers map')),
      );
    });
  });

  group('signWithRecoveryServers', () {
    test('throws ValidationException when a server key is not in the map',
        () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final recoverySignerKp = flutter_sdk.KeyPair.random();
      final sourceKp = flutter_sdk.KeyPair.random();

      final client = MockClient((request) async {
        fail('no recovery server call expected for an unknown server key');
      });

      final recovery =
          walletWithClient(client).recovery(singleServer(), httpClient: client);

      // A minimal, locally built transaction; no signing of it is required
      // because the unknown-key guard fires before any network call.
      final source = flutter_sdk.Account(sourceKp.accountId, BigInt.from(10));
      final tx = flutter_sdk.TransactionBuilder(source)
          .addOperation(flutter_sdk.SetOptionsOperationBuilder()
              .setSourceAccount(accountKp.accountId)
              .build())
          .build();

      expect(
        () => recovery.signWithRecoveryServers(
          tx,
          PublicKeyPair(accountKp),
          {
            RecoveryServerKey('unknown'):
                RecoveryServerSigning(recoverySignerKp.accountId, 'jwt'),
          },
        ),
        throwsA(isA<ValidationException>().having(
            (e) => e.message, 'message', 'key not found in servers map')),
      );
    });

    test(
        'appends one recovery server signature per server entry to the '
        'transaction', () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final recoverySignerKp = flutter_sdk.KeyPair.random();
      final sourceKp = flutter_sdk.KeyPair.random();
      final signatureBytes = Uint8List(64);
      for (var i = 0; i < 64; i++) {
        signatureBytes[i] = (i * 5 + 3) % 256;
      }
      final signatureB64 = base64Encode(signatureBytes);

      String? signPath;
      String? signMethod;
      String? signAuth;
      String? signedTxXdr;

      final client = MockClient((request) async {
        expect(request.url.host, recoveryHost);
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
      });

      final recovery =
          walletWithClient(client).recovery(singleServer(), httpClient: client);

      final source = flutter_sdk.Account(sourceKp.accountId, BigInt.from(10));
      final tx = flutter_sdk.TransactionBuilder(source)
          .addOperation(flutter_sdk.SetOptionsOperationBuilder()
              .setSourceAccount(accountKp.accountId)
              .build())
          .build();
      final unsignedXdr = tx.toEnvelopeXdrBase64();

      final result = await recovery.signWithRecoveryServers(
        tx,
        PublicKeyPair(accountKp),
        {
          RecoveryServerKey('first'):
              RecoveryServerSigning(recoverySignerKp.accountId, 'jwt-sign'),
        },
      );

      // The recovery sign endpoint was hit with the account/signer path and JWT.
      expect(signMethod, 'POST');
      expect(
          signPath,
          endsWith(
              '/accounts/${accountKp.accountId}/sign/${recoverySignerKp.accountId}'));
      expect(signAuth, 'Bearer jwt-sign');

      // The unsigned transaction envelope was forwarded to the server.
      expect(signedTxXdr, unsignedXdr);

      // The returned transaction carries exactly the appended recovery
      // signature, hinted with the recovery signer's key.
      expect(result.signatures.length, 1);
      final appended = result.signatures.first;
      expect(appended.signature.signature, base64Decode(signatureB64));
      expect(appended.hint.signatureHint,
          recoverySignerKp.signatureHint.signatureHint);
    });

    test('wraps a SEP30 server error in RecoveryServerResponseError', () async {
      final accountKp = flutter_sdk.KeyPair.random();
      final recoverySignerKp = flutter_sdk.KeyPair.random();
      final sourceKp = flutter_sdk.KeyPair.random();

      final client = MockClient((request) async {
        return http.Response(
            json.encode({'error': 'identity not authenticated'}), 401);
      });

      final recovery =
          walletWithClient(client).recovery(singleServer(), httpClient: client);

      final source = flutter_sdk.Account(sourceKp.accountId, BigInt.from(10));
      final tx = flutter_sdk.TransactionBuilder(source)
          .addOperation(flutter_sdk.SetOptionsOperationBuilder()
              .setSourceAccount(accountKp.accountId)
              .build())
          .build();

      expect(
        () => recovery.signWithRecoveryServers(
          tx,
          PublicKeyPair(accountKp),
          {
            RecoveryServerKey('first'):
                RecoveryServerSigning(recoverySignerKp.accountId, 'jwt'),
          },
        ),
        throwsA(isA<RecoveryServerResponseError>()),
      );
    });
  });
}
