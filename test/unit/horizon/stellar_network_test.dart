// Copyright 2024 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

void main() {
  // Fixed, well-known account ids so assertions on source/destination are exact.
  const sourceAccountId =
      "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP";
  const destinationAccountId =
      "GCIBUCGPOHWMMMFPFTDWBSVHQRT4DIBJ7AD6BZJYDITBK2LCVBYW7HUQ";
  const feeAccountId =
      "GA6UIXXPEWYFILNUIWAC37Y4QPEZMQVDJHDKVWFZJ2KCWUBIU5IXZNDA";
  const issuerAccountId =
      "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM";
  const intermediateIssuerId =
      "GAOO3LWBC4XF6VWRP5ESJ6IBHAISVJMSBTALHOQM2EZG7Q477UWA6L7U";

  // The result_xdr below decodes to txSUCCESS (a single successful payment op).
  // Verified via the stellar XDR codec: tx_success / op_inner / payment success.
  const successResultXdr = "AAAAAAAAAGQAAAAAAAAAAQAAAAAAAAABAAAAAAAAAAA=";
  // The result_xdr below decodes to txFAILED (a single payment op with
  // no_destination). Verified via the stellar XDR codec.
  const failedResultXdr = "AAAAAAAAAGT/////AAAAAQAAAAAAAAAB////+wAAAAA=";

  // Builds an AccountResponse JSON for the given account id and string sequence.
  String accountJson(String accountId, String sequence) {
    final map = {
      '_links': {
        'self': {
          'href': 'https://horizon-testnet.stellar.org/accounts/$accountId'
        },
        'transactions': {
          'href':
              'https://horizon-testnet.stellar.org/accounts/$accountId/transactions{?cursor,limit,order}',
          'templated': true
        },
        'operations': {
          'href':
              'https://horizon-testnet.stellar.org/accounts/$accountId/operations{?cursor,limit,order}',
          'templated': true
        },
        'payments': {
          'href':
              'https://horizon-testnet.stellar.org/accounts/$accountId/payments{?cursor,limit,order}',
          'templated': true
        },
        'effects': {
          'href':
              'https://horizon-testnet.stellar.org/accounts/$accountId/effects{?cursor,limit,order}',
          'templated': true
        },
        'offers': {
          'href':
              'https://horizon-testnet.stellar.org/accounts/$accountId/offers{?cursor,limit,order}',
          'templated': true
        },
        'trades': {
          'href':
              'https://horizon-testnet.stellar.org/accounts/$accountId/trades{?cursor,limit,order}',
          'templated': true
        },
        'data': {
          'href':
              'https://horizon-testnet.stellar.org/accounts/$accountId/data/{key}',
          'templated': true
        }
      },
      'id': accountId,
      'account_id': accountId,
      'sequence': sequence,
      'subentry_count': 0,
      'last_modified_ledger': 12345,
      'last_modified_time': '2024-01-01T00:00:00Z',
      'thresholds': {
        'low_threshold': 0,
        'med_threshold': 0,
        'high_threshold': 0
      },
      'flags': {
        'auth_required': false,
        'auth_revocable': false,
        'auth_immutable': false,
        'auth_clawback_enabled': false
      },
      'balances': [
        {
          'balance': '1000.0000000',
          'buying_liabilities': '0.0000000',
          'selling_liabilities': '0.0000000',
          'asset_type': 'native'
        }
      ],
      'signers': [
        {
          'weight': 1,
          'key': accountId,
          'type': 'ed25519_public_key'
        }
      ],
      'data': {},
      'num_sponsoring': 0,
      'num_sponsored': 0,
      'paging_token': accountId
    };
    return json.encode(map);
  }

  // Builds a /paths page JSON with a single path record.
  String pathsPageJson(Map<String, dynamic> record) {
    final map = {
      '_links': {
        'self': {'href': 'https://horizon-testnet.stellar.org/paths'}
      },
      '_embedded': {
        'records': [record]
      }
    };
    return json.encode(map);
  }

  // Builds a Wallet whose Horizon traffic is routed through [mock].
  Wallet walletWith(http.Client mock) {
    return Wallet(StellarConfiguration.testNet,
        applicationConfiguration:
            ApplicationConfiguration(defaultClient: mock));
  }

  // A mock that fails every request; used to prove path-finding swallows errors.
  http.Client failingClient() =>
      MockClient((request) async => http.Response("server error", 500));

  group('Stellar decodeTransaction', () {
    test('round-trips a payment transaction through XDR', () {
      var account = flutter_sdk.Account(sourceAccountId, BigInt.from(10));
      var built = TxBuilder(account)
          .transfer(destinationAccountId, NativeAssetId(), "12.5")
          .build();
      var base64 = built.toEnvelopeXdrBase64();

      var stellar = Wallet.testNet.stellar();
      var decoded = stellar.decodeTransaction(base64);

      expect(decoded, isA<flutter_sdk.Transaction>());
      var tx = decoded as flutter_sdk.Transaction;
      expect(tx.sourceAccount.ed25519AccountId, sourceAccountId);
      // build increments the sequence (10 -> 11).
      expect(tx.sequenceNumber, BigInt.from(11));
      expect(tx.operations.length, 1);
      var op = tx.operations.first as flutter_sdk.PaymentOperation;
      expect(op.destination.ed25519AccountId, destinationAccountId);
      expect(op.amount, "12.5");
    });

    test('preserves a large amount across the round-trip', () {
      const maxAmount = "922337203685.4775807";
      var account = flutter_sdk.Account(sourceAccountId, BigInt.from(1));
      var usd = IssuedAssetId(code: "USD", issuer: issuerAccountId);
      var built =
          TxBuilder(account).transfer(destinationAccountId, usd, maxAmount).build();

      var decoded = Wallet.testNet
          .stellar()
          .decodeTransaction(built.toEnvelopeXdrBase64()) as flutter_sdk.Transaction;
      var op = decoded.operations.first as flutter_sdk.PaymentOperation;
      expect(op.amount, maxAmount);
    });
  });

  group('Stellar sign', () {
    test('appends a signature valid for the keypair on the testnet hash', () {
      var signer = SigningKeyPair.random();
      var account =
          flutter_sdk.Account(signer.address, BigInt.from(5));
      var tx = TxBuilder(account)
          .transfer(destinationAccountId, NativeAssetId(), "1")
          .build();
      expect(tx.signatures, isEmpty);

      Wallet.testNet.stellar().sign(tx, signer);

      expect(tx.signatures.length, 1);
      var hash = tx.hash(flutter_sdk.Network.TESTNET);
      var sig = tx.signatures.first.signature.signature;
      expect(signer.keyPair.verify(hash, sig), isTrue);
    });

    test('signs over cfg.stellar.network, not a different network', () {
      // Custom network passphrase to prove the configured network is used.
      var customNetwork = flutter_sdk.Network("Custom Wallet SDK Network");
      var stellarConfig = StellarConfiguration(
          customNetwork, "https://horizon-testnet.stellar.org");
      var wallet = Wallet(stellarConfig);

      var signer = SigningKeyPair.random();
      var account = flutter_sdk.Account(signer.address, BigInt.from(7));
      var tx = TxBuilder(account)
          .transfer(destinationAccountId, NativeAssetId(), "1")
          .build();

      wallet.stellar().sign(tx, signer);

      var sig = tx.signatures.first.signature.signature;
      // Valid against the configured custom network hash.
      expect(signer.keyPair.verify(tx.hash(customNetwork), sig), isTrue);
      // And NOT against the testnet hash, confirming the network was honored.
      expect(
          signer.keyPair.verify(tx.hash(flutter_sdk.Network.TESTNET), sig),
          isFalse);
    });

    test('adds a second signature when signing twice', () {
      var first = SigningKeyPair.random();
      var second = SigningKeyPair.random();
      var account = flutter_sdk.Account(first.address, BigInt.from(3));
      var tx = TxBuilder(account)
          .transfer(destinationAccountId, NativeAssetId(), "1")
          .build();

      var stellar = Wallet.testNet.stellar();
      stellar.sign(tx, first);
      stellar.sign(tx, second);

      expect(tx.signatures.length, 2);
      var hash = tx.hash(flutter_sdk.Network.TESTNET);
      expect(first.keyPair.verify(hash, tx.signatures[0].signature.signature),
          isTrue);
      expect(second.keyPair.verify(hash, tx.signatures[1].signature.signature),
          isTrue);
    });
  });

  group('Stellar makeFeeBump', () {
    flutter_sdk.Transaction innerTx() {
      var account = flutter_sdk.Account(sourceAccountId, BigInt.from(20));
      return TxBuilder(account)
          .transfer(destinationAccountId, NativeAssetId(), "5")
          .build();
    }

    test('sets the fee account to feeAddress.address', () {
      var feeAddress = PublicKeyPair.fromAccountId(feeAccountId);
      var feeBump = Wallet.testNet.stellar().makeFeeBump(feeAddress, innerTx());

      expect(feeBump.feeAccount.ed25519AccountId, feeAccountId);
    });

    test('default base fee falls back to cfg.stellar.baseFee', () {
      // testNet config uses MIN_BASE_FEE (100). Inner tx has 1 op, so the
      // fee bump fee = baseFee * (numOps + 1) = 100 * 2 = 200.
      var feeAddress = PublicKeyPair.fromAccountId(feeAccountId);
      var feeBump = Wallet.testNet.stellar().makeFeeBump(feeAddress, innerTx());

      expect(feeBump.fee, 200);
    });

    test('honors an explicit base fee', () {
      var feeAddress = PublicKeyPair.fromAccountId(feeAccountId);
      var feeBump = Wallet.testNet
          .stellar()
          .makeFeeBump(feeAddress, innerTx(), baseFee: 250);

      // 250 * (1 op + 1) = 500.
      expect(feeBump.fee, 500);
    });

    test('uses the configured default base fee when raised in config', () {
      var stellarConfig = StellarConfiguration(
          flutter_sdk.Network.TESTNET, "https://horizon-testnet.stellar.org",
          baseFee: 300);
      var feeAddress = PublicKeyPair.fromAccountId(feeAccountId);

      var feeBump =
          Wallet(stellarConfig).stellar().makeFeeBump(feeAddress, innerTx());
      // 300 * 2 = 600.
      expect(feeBump.fee, 600);
    });
  });

  group('Stellar transaction builder factory', () {
    test('fetches the source account from Horizon and increments sequence',
        () async {
      String? requestedPath;
      var mock = MockClient((request) async {
        if (request.method == "GET" &&
            request.url.path.contains("/accounts/")) {
          requestedPath = request.url.path;
          return http.Response(accountJson(sourceAccountId, "42"), 200);
        }
        return http.Response("not found", 404);
      });

      var source = PublicKeyPair.fromAccountId(sourceAccountId);
      var builder = await walletWith(mock).stellar().transaction(source);
      var tx = builder
          .transfer(destinationAccountId, NativeAssetId(), "1")
          .build();

      // The mocked account was loaded from the correct Horizon endpoint.
      expect(requestedPath, contains("/accounts/$sourceAccountId"));
      // Sequence comes from the mocked account (42) and is incremented to 43.
      expect(tx.sequenceNumber, BigInt.from(43));
      expect(tx.sourceAccount.ed25519AccountId, sourceAccountId);
    });

    test('applies the default base fee from config', () async {
      var mock = MockClient((request) async =>
          http.Response(accountJson(sourceAccountId, "100"), 200));

      var source = PublicKeyPair.fromAccountId(sourceAccountId);
      var builder = await walletWith(mock).stellar().transaction(source);
      var tx = builder
          .transfer(destinationAccountId, NativeAssetId(), "1")
          .build();

      // testNet default base fee is MIN_BASE_FEE (100), 1 op => fee 100.
      expect(tx.fee, 100);
    });

    test('honors an explicit base fee and memo', () async {
      var mock = MockClient((request) async =>
          http.Response(accountJson(sourceAccountId, "9"), 200));

      var source = PublicKeyPair.fromAccountId(sourceAccountId);
      var builder = await walletWith(mock).stellar().transaction(source,
          baseFee: 200, memo: flutter_sdk.Memo.text("hello"));
      var tx = builder
          .transfer(destinationAccountId, NativeAssetId(), "1")
          .build();

      expect(tx.fee, 200);
      expect(tx.memo, isA<flutter_sdk.MemoText>());
      expect((tx.memo as flutter_sdk.MemoText).text, "hello");
    });

    test('sets time bounds derived from the timeout', () async {
      var mock = MockClient((request) async =>
          http.Response(accountJson(sourceAccountId, "9"), 200));

      var source = PublicKeyPair.fromAccountId(sourceAccountId);
      var builder = await walletWith(mock)
          .stellar()
          .transaction(source, timeout: const Duration(minutes: 5));
      var tx = builder
          .transfer(destinationAccountId, NativeAssetId(), "1")
          .build();

      expect(tx.preconditions, isNotNull);
      expect(tx.preconditions!.timeBounds, isNotNull);
      expect(tx.preconditions!.timeBounds!.minTime, 0);
      // maxTime is now + timeout; it must be in the future relative to now.
      var nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(tx.preconditions!.timeBounds!.maxTime, greaterThan(nowSeconds));
    });

    test('throws ValidationException when the account does not exist', () async {
      var mock = MockClient((request) async {
        var body = json.encode({
          'type': 'https://stellar.org/horizon-errors/not_found',
          'title': 'Resource Missing',
          'status': 404,
          'detail': 'The resource at the url requested was not found.'
        });
        return http.Response(body, 404);
      });

      var source = PublicKeyPair.fromAccountId(sourceAccountId);
      expect(
          () => walletWith(mock).stellar().transaction(source),
          throwsA(isA<ValidationException>()));
    });
  });

  group('Stellar submitTransaction', () {
    flutter_sdk.AbstractTransaction signedTx() {
      var signer = SigningKeyPair.random();
      var account = flutter_sdk.Account(signer.address, BigInt.from(1));
      var tx = TxBuilder(account)
          .transfer(destinationAccountId, NativeAssetId(), "1")
          .build();
      tx.sign(signer.keyPair, flutter_sdk.Network.TESTNET);
      return tx;
    }

    test('returns true on a successful submission', () async {
      String? capturedTx;
      var mock = MockClient((request) async {
        expect(request.method, "POST");
        expect(request.url.path, contains("/transactions"));
        capturedTx = request.bodyFields['tx'];
        // success is derived from result_xdr (which decodes to txSUCCESS); the
        // 'successful' flag is intentionally omitted so the response is not
        // forced through full TransactionResponse parsing.
        var body = json.encode({
          'hash':
              'b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020',
          'ledger': 826150,
          'envelope_xdr': 'AAAAAgAAAAA=',
          'result_xdr': successResultXdr,
          'result_meta_xdr': 'AAAAAwAAAAA=',
          'fee_meta_xdr': 'AAAAAgAAAAA=',
        });
        return http.Response(body, 200);
      });

      var tx = signedTx();
      var result = await walletWith(mock).stellar().submitTransaction(tx);

      expect(result, isTrue);
      // The submitted envelope matches the signed transaction.
      expect(capturedTx, tx.toEnvelopeXdrBase64());
    });

    test('throws TransactionSubmitFailedException on a failed submission',
        () async {
      var mock = MockClient((request) async {
        var body = json.encode({
          'type': 'https://stellar.org/horizon-errors/transaction_failed',
          'title': 'Transaction Failed',
          'status': 400,
          'extras': {
            'envelope_xdr': 'AAAAAgAAAABFAILED',
            'result_xdr': failedResultXdr,
            'result_codes': {
              'transaction': 'tx_failed',
              'operations': ['op_no_destination']
            }
          }
        });
        return http.Response(body, 400);
      });

      var tx = signedTx();
      try {
        await walletWith(mock).stellar().submitTransaction(tx);
        fail("expected TransactionSubmitFailedException");
      } on TransactionSubmitFailedException catch (e) {
        expect(e.transactionResultCode, "tx_failed");
        expect(e.operationsResultCodes, contains("op_no_destination"));
        expect(e.response.success, isFalse);
      }
    });
  });

  group('Stellar findStrictSendPathForDestinationAddress', () {
    test('maps a path response and captures request parameters', () async {
      Map<String, String> capturedParams = {};
      var mock = MockClient((request) async {
        expect(request.url.path, contains("/paths/strict-send"));
        capturedParams = request.url.queryParameters;
        var record = {
          'source_asset_type': 'native',
          'source_amount': '10.0000000',
          'destination_asset_type': 'credit_alphanum4',
          'destination_asset_code': 'USD',
          'destination_asset_issuer': issuerAccountId,
          'destination_amount': '38.0671000',
          'path': [
            {
              'asset_type': 'credit_alphanum4',
              'asset_code': 'EUR',
              'asset_issuer': intermediateIssuerId
            }
          ]
        };
        return http.Response(pathsPageJson(record), 200);
      });

      var paths = await walletWith(mock)
          .stellar()
          .findStrictSendPathForDestinationAddress(
              NativeAssetId(), "10", destinationAccountId);

      // outbound request parameters were forwarded.
      expect(capturedParams['source_asset_type'], 'native');
      expect(capturedParams['source_amount'], '10');
      expect(capturedParams['destination_account'], destinationAccountId);

      expect(paths.length, 1);
      var path = paths.first;
      expect(path.sourceAsset, isA<NativeAssetId>());
      expect(path.sourceAmount, '10.0000000');
      var dest = path.destinationAsset as IssuedAssetId;
      expect(dest.code, 'USD');
      expect(dest.issuer, issuerAccountId);
      expect(path.destinationAmount, '38.0671000');
      expect(path.path.length, 1);
      var hop = path.path.first as IssuedAssetId;
      expect(hop.code, 'EUR');
      expect(hop.issuer, intermediateIssuerId);
    });

    test('preserves the order and amounts of multiple paths', () async {
      var mock = MockClient((request) async {
        var page = {
          '_links': {
            'self': {'href': 'https://horizon-testnet.stellar.org/paths'}
          },
          '_embedded': {
            'records': [
              {
                'source_asset_type': 'native',
                'source_amount': '922337203685.4775807',
                'destination_asset_type': 'credit_alphanum4',
                'destination_asset_code': 'USD',
                'destination_asset_issuer': issuerAccountId,
                'destination_amount': '1.0000000',
                'path': []
              },
              {
                'source_asset_type': 'native',
                'source_amount': '0.0000001',
                'destination_asset_type': 'credit_alphanum4',
                'destination_asset_code': 'USD',
                'destination_asset_issuer': issuerAccountId,
                'destination_amount': '2.0000000',
                'path': []
              }
            ]
          }
        };
        return http.Response(json.encode(page), 200);
      });

      var paths = await walletWith(mock)
          .stellar()
          .findStrictSendPathForDestinationAddress(
              NativeAssetId(), "1", destinationAccountId);

      expect(paths.length, 2);
      // Large amount preserved exactly (int64 max in stroops).
      expect(paths[0].sourceAmount, '922337203685.4775807');
      // Smallest representable amount preserved exactly.
      expect(paths[1].sourceAmount, '0.0000001');
    });

    test('rethrows a Horizon error as HorizonRequestFailedException',
        () async {
      // Path-finding surfaces request failures instead of returning [], so a
      // caller can distinguish "no paths" from "request failed".
      expect(
        () => walletWith(failingClient())
            .stellar()
            .findStrictSendPathForDestinationAddress(
                NativeAssetId(), "10", destinationAccountId),
        throwsA(isA<HorizonRequestFailedException>()),
      );
    });
  });

  group('Stellar findStrictSendPathForDestinationAssets', () {
    test('maps a path response and forwards destination assets', () async {
      Map<String, String> capturedParams = {};
      var mock = MockClient((request) async {
        expect(request.url.path, contains("/paths/strict-send"));
        capturedParams = request.url.queryParameters;
        var record = {
          'source_asset_type': 'credit_alphanum4',
          'source_asset_code': 'USD',
          'source_asset_issuer': issuerAccountId,
          'source_amount': '5.0000000',
          'destination_asset_type': 'native',
          'destination_amount': '7.5000000',
          'path': []
        };
        return http.Response(pathsPageJson(record), 200);
      });

      var usd = IssuedAssetId(code: "USD", issuer: issuerAccountId);
      var paths = await walletWith(mock)
          .stellar()
          .findStrictSendPathForDestinationAssets(usd, "5", [NativeAssetId()]);

      expect(capturedParams['source_asset_code'], 'USD');
      expect(capturedParams['source_asset_issuer'], issuerAccountId);
      expect(capturedParams['source_amount'], '5');
      expect(capturedParams['destination_assets'], 'native');

      expect(paths.length, 1);
      var path = paths.first;
      var src = path.sourceAsset as IssuedAssetId;
      expect(src.code, 'USD');
      expect(path.destinationAsset, isA<NativeAssetId>());
      expect(path.destinationAmount, '7.5000000');
      expect(path.path, isEmpty);
    });

    test('rethrows a Horizon error as HorizonRequestFailedException',
        () async {
      var usd = IssuedAssetId(code: "USD", issuer: issuerAccountId);
      expect(
        () => walletWith(failingClient())
            .stellar()
            .findStrictSendPathForDestinationAssets(usd, "5", [NativeAssetId()]),
        throwsA(isA<HorizonRequestFailedException>()),
      );
    });
  });

  group('Stellar findStrictReceivePathForSourceAssets', () {
    test('maps a path response and forwards source assets', () async {
      Map<String, String> capturedParams = {};
      var mock = MockClient((request) async {
        expect(request.url.path, contains("/paths/strict-receive"));
        capturedParams = request.url.queryParameters;
        var record = {
          'source_asset_type': 'native',
          'source_amount': '12.0000000',
          'destination_asset_type': 'credit_alphanum4',
          'destination_asset_code': 'USD',
          'destination_asset_issuer': issuerAccountId,
          'destination_amount': '4.0000000',
          'path': []
        };
        return http.Response(pathsPageJson(record), 200);
      });

      var usd = IssuedAssetId(code: "USD", issuer: issuerAccountId);
      var paths = await walletWith(mock)
          .stellar()
          .findStrictReceivePathForSourceAssets(usd, "4", [NativeAssetId()]);

      expect(capturedParams['destination_asset_code'], 'USD');
      expect(capturedParams['destination_asset_issuer'], issuerAccountId);
      expect(capturedParams['destination_amount'], '4');
      expect(capturedParams['source_assets'], 'native');

      expect(paths.length, 1);
      var path = paths.first;
      expect(path.sourceAsset, isA<NativeAssetId>());
      expect(path.sourceAmount, '12.0000000');
      var dest = path.destinationAsset as IssuedAssetId;
      expect(dest.code, 'USD');
      expect(path.destinationAmount, '4.0000000');
    });

    test('rethrows a Horizon error as HorizonRequestFailedException',
        () async {
      var usd = IssuedAssetId(code: "USD", issuer: issuerAccountId);
      expect(
        () => walletWith(failingClient())
            .stellar()
            .findStrictReceivePathForSourceAssets(usd, "4", [NativeAssetId()]),
        throwsA(isA<HorizonRequestFailedException>()),
      );
    });
  });

  group('Stellar findStrictReceivePathForSourceAddress', () {
    test('maps a path response and forwards the source account', () async {
      Map<String, String> capturedParams = {};
      var mock = MockClient((request) async {
        expect(request.url.path, contains("/paths/strict-receive"));
        capturedParams = request.url.queryParameters;
        var record = {
          'source_asset_type': 'credit_alphanum4',
          'source_asset_code': 'EUR',
          'source_asset_issuer': intermediateIssuerId,
          'source_amount': '3.0000000',
          'destination_asset_type': 'credit_alphanum4',
          'destination_asset_code': 'USD',
          'destination_asset_issuer': issuerAccountId,
          'destination_amount': '2.5000000',
          'path': [
            {'asset_type': 'native'}
          ]
        };
        return http.Response(pathsPageJson(record), 200);
      });

      var usd = IssuedAssetId(code: "USD", issuer: issuerAccountId);
      var paths = await walletWith(mock)
          .stellar()
          .findStrictReceivePathForSourceAddress(usd, "2.5", sourceAccountId);

      expect(capturedParams['destination_asset_code'], 'USD');
      expect(capturedParams['destination_amount'], '2.5');
      expect(capturedParams['source_account'], sourceAccountId);

      expect(paths.length, 1);
      var path = paths.first;
      var src = path.sourceAsset as IssuedAssetId;
      expect(src.code, 'EUR');
      expect(path.sourceAmount, '3.0000000');
      expect(path.destinationAmount, '2.5000000');
      // intermediate native hop preserved.
      expect(path.path.length, 1);
      expect(path.path.first, isA<NativeAssetId>());
    });

    test('rethrows a Horizon error as HorizonRequestFailedException',
        () async {
      var usd = IssuedAssetId(code: "USD", issuer: issuerAccountId);
      expect(
        () => walletWith(failingClient())
            .stellar()
            .findStrictReceivePathForSourceAddress(usd, "2.5", sourceAccountId),
        throwsA(isA<HorizonRequestFailedException>()),
      );
    });
  });
}
