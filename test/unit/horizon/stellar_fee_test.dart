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
  // sourceSecret/sourceAccountId are a matching keypair so the source account
  // can both be loaded from Horizon and sign the transaction.
  const sourceSecret =
      "SCMWF7LKYOWF4PL6MNM244Z3DWQPUA74WYLXFN63G56SC2IVJ4SEXRVO";
  const sourceAccountId =
      "GDIMFJ7YTQ6IIJIIJUUXX7HNBJM5SD65HV3NSMCIMZ2XOBRNDIJXJGOG";
  const destinationAccountId =
      "GCIBUCGPOHWMMMFPFTDWBSVHQRT4DIBJ7AD6BZJYDITBK2LCVBYW7HUQ";

  // result_xdr decoding to txSUCCESS (a single successful payment op). Verified
  // via the stellar XDR codec: tx_success / op_inner / payment success.
  const successResultXdr = "AAAAAAAAAGQAAAAAAAAAAQAAAAAAAAABAAAAAAAAAAA=";
  // result_xdr decoding to txFAILED (a single payment op with no_destination).
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
        {'weight': 1, 'key': accountId, 'type': 'ed25519_public_key'}
      ],
      'data': {},
      'num_sponsoring': 0,
      'num_sponsored': 0,
      'paging_token': accountId
    };
    return json.encode(map);
  }

  // A successful 200 transaction submission body. success is derived from
  // result_xdr (txSUCCESS); the 'successful' flag is omitted so the response is
  // not forced through full TransactionResponse parsing.
  String submitSuccessBody() => json.encode({
        'hash':
            'b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020',
        'ledger': 826150,
        'envelope_xdr': 'AAAAAgAAAAA=',
        'result_xdr': successResultXdr,
        'result_meta_xdr': 'AAAAAwAAAAA=',
        'fee_meta_xdr': 'AAAAAgAAAAA=',
      });

  // A failed 400 transaction submission body with tx_failed / op_no_destination.
  String submitFailedBody() => json.encode({
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

  // A 504 timeout body that SubmitTransactionTimeoutResponseException.fromJson
  // can parse (type/title/status/detail are all required).
  String submitTimeoutBody() => json.encode({
        'type': 'https://stellar.org/horizon-errors/timeout',
        'title': 'Timeout',
        'status': 504,
        'detail':
            'Your request timed out before completing. Please try your request again.',
        'extras': {
          'hash':
              'b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020'
        }
      });

  // Builds a Wallet whose Horizon traffic is routed through [mock].
  Wallet walletWith(http.Client mock) {
    return Wallet(StellarConfiguration.testNet,
        applicationConfiguration:
            ApplicationConfiguration(defaultClient: mock));
  }

  // Decodes the 'tx' field of a submit POST body to a Transaction.
  flutter_sdk.Transaction decodeSubmittedTx(http.Request request) {
    final envelope = request.bodyFields['tx']!;
    return flutter_sdk.AbstractTransaction.fromEnvelopeXdrString(envelope)
        as flutter_sdk.Transaction;
  }

  group('Stellar submitWithFeeIncrease', () {
    test('builds, signs and submits; submitted tx reflects the base fee',
        () async {
      http.Request? submittedRequest;
      var mock = MockClient((request) async {
        if (request.method == "GET" &&
            request.url.path.contains("/accounts/")) {
          return http.Response(accountJson(sourceAccountId, "42"), 200);
        }
        if (request.method == "POST" &&
            request.url.path.contains("/transactions")) {
          submittedRequest = request;
          return http.Response(submitSuccessBody(), 200);
        }
        return http.Response("not found", 404);
      });

      var source = SigningKeyPair.fromSecret(sourceSecret);
      var result = await walletWith(mock).stellar().submitWithFeeIncrease(
            sourceAddress: source,
            timeout: const Duration(minutes: 5),
            baseFeeIncrease: 100,
            maxBaseFee: 2000,
            baseFee: 150,
            buildingFunction: (builder) =>
                builder.transfer(destinationAccountId, NativeAssetId(), "10"),
          );

      expect(result, isTrue);
      expect(submittedRequest, isNotNull);

      var tx = decodeSubmittedTx(submittedRequest!);
      // The building function added exactly one operation.
      expect(tx.operations.length, 1);
      var op = tx.operations.first as flutter_sdk.PaymentOperation;
      expect(op.destination.ed25519AccountId, destinationAccountId);
      expect(op.amount, "10");
      // The submitted tx reflects the requested base fee: 150 * 1 op = 150.
      expect(tx.fee, 150);
      // Sequence came from the mocked account (42) and was incremented to 43.
      expect(tx.sequenceNumber, BigInt.from(43));
      // It carries exactly one (valid) signature from the source key.
      expect(tx.signatures.length, 1);
      var hash = tx.hash(flutter_sdk.Network.TESTNET);
      expect(
          source.keyPair.verify(hash, tx.signatures.first.signature.signature),
          isTrue);
    });

    test('falls back to the configured default base fee when none is given',
        () async {
      http.Request? submittedRequest;
      var mock = MockClient((request) async {
        if (request.method == "GET" &&
            request.url.path.contains("/accounts/")) {
          return http.Response(accountJson(sourceAccountId, "7"), 200);
        }
        if (request.method == "POST" &&
            request.url.path.contains("/transactions")) {
          submittedRequest = request;
          return http.Response(submitSuccessBody(), 200);
        }
        return http.Response("not found", 404);
      });

      var source = SigningKeyPair.fromSecret(sourceSecret);
      var result = await walletWith(mock).stellar().submitWithFeeIncrease(
            sourceAddress: source,
            timeout: const Duration(minutes: 5),
            baseFeeIncrease: 100,
            maxBaseFee: 2000,
            buildingFunction: (builder) =>
                builder.transfer(destinationAccountId, NativeAssetId(), "1"),
          );

      expect(result, isTrue);
      var tx = decodeSubmittedTx(submittedRequest!);
      // testNet default base fee is MIN_BASE_FEE (100), 1 op => fee 100.
      expect(tx.fee, 100);
    });

    test('attaches the provided memo to the submitted transaction', () async {
      http.Request? submittedRequest;
      var mock = MockClient((request) async {
        if (request.method == "GET" &&
            request.url.path.contains("/accounts/")) {
          return http.Response(accountJson(sourceAccountId, "9"), 200);
        }
        if (request.method == "POST" &&
            request.url.path.contains("/transactions")) {
          submittedRequest = request;
          return http.Response(submitSuccessBody(), 200);
        }
        return http.Response("not found", 404);
      });

      var source = SigningKeyPair.fromSecret(sourceSecret);
      await walletWith(mock).stellar().submitWithFeeIncrease(
            sourceAddress: source,
            timeout: const Duration(minutes: 5),
            baseFeeIncrease: 100,
            maxBaseFee: 2000,
            memo: flutter_sdk.Memo.text("fee-bump"),
            buildingFunction: (builder) =>
                builder.transfer(destinationAccountId, NativeAssetId(), "1"),
          );

      var tx = decodeSubmittedTx(submittedRequest!);
      expect(tx.memo, isA<flutter_sdk.MemoText>());
      expect((tx.memo as flutter_sdk.MemoText).text, "fee-bump");
    });

    test('throws TransactionSubmitFailedException on a failed submission',
        () async {
      var mock = MockClient((request) async {
        if (request.method == "GET" &&
            request.url.path.contains("/accounts/")) {
          return http.Response(accountJson(sourceAccountId, "1"), 200);
        }
        if (request.method == "POST" &&
            request.url.path.contains("/transactions")) {
          return http.Response(submitFailedBody(), 400);
        }
        return http.Response("not found", 404);
      });

      var source = SigningKeyPair.fromSecret(sourceSecret);
      try {
        await walletWith(mock).stellar().submitWithFeeIncrease(
              sourceAddress: source,
              timeout: const Duration(minutes: 5),
              baseFeeIncrease: 100,
              maxBaseFee: 2000,
              buildingFunction: (builder) =>
                  builder.transfer(destinationAccountId, NativeAssetId(), "1"),
            );
        fail("expected TransactionSubmitFailedException");
      } on TransactionSubmitFailedException catch (e) {
        expect(e.transactionResultCode, "tx_failed");
        expect(e.operationsResultCodes, contains("op_no_destination"));
        expect(e.response.success, isFalse);
      }
    });
  });

  group('Stellar submitWithFeeIncreaseAndSignerFunction', () {
    test('invokes the custom signer function with the built transaction',
        () async {
      http.Request? submittedRequest;
      var mock = MockClient((request) async {
        if (request.method == "GET" &&
            request.url.path.contains("/accounts/")) {
          return http.Response(accountJson(sourceAccountId, "5"), 200);
        }
        if (request.method == "POST" &&
            request.url.path.contains("/transactions")) {
          submittedRequest = request;
          return http.Response(submitSuccessBody(), 200);
        }
        return http.Response("not found", 404);
      });

      var source = SigningKeyPair.fromSecret(sourceSecret);
      flutter_sdk.AbstractTransaction? signedTx;
      var signerCalls = 0;

      var result =
          await walletWith(mock).stellar().submitWithFeeIncreaseAndSignerFunction(
        sourceAddress: source,
        timeout: const Duration(minutes: 5),
        baseFeeIncrease: 100,
        maxBaseFee: 2000,
        baseFee: 200,
        buildingFunction: (builder) =>
            builder.transfer(destinationAccountId, NativeAssetId(), "3"),
        signerFunction: (transaction) {
          signerCalls++;
          signedTx = transaction;
          // Sign so the submitted envelope carries a valid signature.
          (transaction as flutter_sdk.Transaction)
              .sign(source.keyPair, flutter_sdk.Network.TESTNET);
        },
      );

      expect(result, isTrue);
      // The signer function ran exactly once for a single (non-timeout) submit.
      expect(signerCalls, 1);
      expect(signedTx, isA<flutter_sdk.Transaction>());

      // The transaction handed to the signer is the one that was submitted:
      // same fee (200 * 1 op) and same envelope.
      var built = signedTx as flutter_sdk.Transaction;
      expect(built.fee, 200);
      var submitted = decodeSubmittedTx(submittedRequest!);
      expect(submitted.fee, 200);
      expect(submitted.toEnvelopeXdrBase64(), built.toEnvelopeXdrBase64());
      expect(submitted.signatures.length, 1);
    });

    test(
        'on a single timeout it retries with an increased fee and then succeeds',
        () async {
      // The mock times out exactly once (the first submit), then succeeds, so
      // the unbounded retry loop in submitWithFeeIncreaseAndSignerFunction is
      // exercised in a bounded way. We capture the fee of each submitted tx to
      // prove the second attempt uses baseFee + baseFeeIncrease.
      var submitCount = 0;
      final submittedFees = <int>[];
      var mock = MockClient((request) async {
        if (request.method == "GET" &&
            request.url.path.contains("/accounts/")) {
          return http.Response(accountJson(sourceAccountId, "11"), 200);
        }
        if (request.method == "POST" &&
            request.url.path.contains("/transactions")) {
          submitCount++;
          submittedFees.add(decodeSubmittedTx(request).fee);
          if (submitCount == 1) {
            return http.Response(submitTimeoutBody(), 504);
          }
          return http.Response(submitSuccessBody(), 200);
        }
        return http.Response("not found", 404);
      });

      var source = SigningKeyPair.fromSecret(sourceSecret);
      var signerCalls = 0;

      var result =
          await walletWith(mock).stellar().submitWithFeeIncreaseAndSignerFunction(
        sourceAddress: source,
        timeout: const Duration(minutes: 5),
        baseFeeIncrease: 100,
        maxBaseFee: 2000,
        baseFee: 150,
        buildingFunction: (builder) =>
            builder.transfer(destinationAccountId, NativeAssetId(), "1"),
        signerFunction: (transaction) {
          signerCalls++;
          (transaction as flutter_sdk.Transaction)
              .sign(source.keyPair, flutter_sdk.Network.TESTNET);
        },
      );

      expect(result, isTrue);
      // Two submit attempts: the timeout, then the retry.
      expect(submitCount, 2);
      // Signer ran once per build (the retry rebuilds and re-signs).
      expect(signerCalls, 2);
      // First attempt used baseFee 150 (150 * 1 op).
      expect(submittedFees[0], 150);
      // Retry used baseFee + baseFeeIncrease = 150 + 100 = 250 (250 * 1 op).
      expect(submittedFees[1], 250);
    });

    test('caps the increased fee at maxBaseFee on retry after a timeout',
        () async {
      // baseFee (150) + increase (100) = 250 would exceed maxBaseFee (200), so
      // the retry fee must be clamped to maxBaseFee.
      var submitCount = 0;
      final submittedFees = <int>[];
      var mock = MockClient((request) async {
        if (request.method == "GET" &&
            request.url.path.contains("/accounts/")) {
          return http.Response(accountJson(sourceAccountId, "20"), 200);
        }
        if (request.method == "POST" &&
            request.url.path.contains("/transactions")) {
          submitCount++;
          submittedFees.add(decodeSubmittedTx(request).fee);
          if (submitCount == 1) {
            return http.Response(submitTimeoutBody(), 504);
          }
          return http.Response(submitSuccessBody(), 200);
        }
        return http.Response("not found", 404);
      });

      var source = SigningKeyPair.fromSecret(sourceSecret);
      var result =
          await walletWith(mock).stellar().submitWithFeeIncreaseAndSignerFunction(
        sourceAddress: source,
        timeout: const Duration(minutes: 5),
        baseFeeIncrease: 100,
        maxBaseFee: 200,
        baseFee: 150,
        buildingFunction: (builder) =>
            builder.transfer(destinationAccountId, NativeAssetId(), "1"),
        signerFunction: (transaction) => (transaction as flutter_sdk.Transaction)
            .sign(source.keyPair, flutter_sdk.Network.TESTNET),
      );

      expect(result, isTrue);
      expect(submitCount, 2);
      expect(submittedFees[0], 150);
      // Clamped to maxBaseFee (200), not 250.
      expect(submittedFees[1], 200);
    });
  });
}